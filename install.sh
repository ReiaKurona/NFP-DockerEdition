#!/bin/bash
# =========================================================
# AeroNode (NFP) 面板一键安装管理脚本
# 支持系统: Debian / Ubuntu / CentOS / Arch Linux
# 功能: 全自动环境配置、网络容灾切换、一键部署、更新、卸载
# =========================================================

# ================= 🚀 用户配置区 (在此处修改) 🚀 =================
# 项目 GitHub 仓库地址 (用于本地构建模式)
GITHUB_REPO="ReiaKurona/NFP"
# Docker 镜像地址 (用于预构建镜像模式)
DOCKER_IMAGE="ghcr.io/reiakurona/aero-panel:latest"

# 备用源 1 (如 GitHub 代理加速)
MIRROR_1_PREFIX="https://mirror.ghproxy.com/https://github.com/"
# 备用源 2 (另一家 Git 克隆加速)
MIRROR_2_PREFIX="https://hub.gitmirror.com/https://github.com/"

# 安装目录
INSTALL_DIR="/opt/aero-panel"
# 本脚本在本地保存的绝对路径 (用于快捷命令)
SCRIPT_PATH="/usr/local/bin/aero-cli"
# ===============================================================

# --- 颜色与样式定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 必须为 root 运行 ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 请使用 root 用户运行此脚本！${NC}"
        exit 1
    fi
}

# --- 带有炫酷倒计时的命令执行函数 (网络容灾核心) ---
# 用法: run_with_countdown "命令" "超时秒数" "描述"
run_with_countdown() {
    local cmd="$1"
    local timeout="$2"
    local desc="$3"

    echo -e "${CYAN}>>> 正在尝试: ${desc}${NC}"
    # 在后台执行命令并将输出重定向，避免干扰倒计时
    eval "$cmd" > /tmp/aero_cmd.log 2>&1 &
    local pid=$!

    for (( i=$timeout; i>0; i-- )); do
        if ! kill -0 $pid 2>/dev/null; then
            wait $pid
            local status=$?
            echo -ne "\r\033[K" # 清除当前行
            if[ $status -eq 0 ]; then
                echo -e "${GREEN}✅ ${desc} 成功!${NC}"
                return 0
            else
                echo -e "${RED}❌ ${desc} 失败! (退出码: $status)${NC}"
                cat /tmp/aero_cmd.log
                return $status
            fi
        fi
        echo -ne "\r${YELLOW}⌛ 等待响应中... 剩余超时时间: ${i} 秒${NC} \033[K"
        sleep 1
    done

    echo -ne "\r\033[K"
    echo -e "${RED}⚠️ ${desc} 超时 ($timeout 秒)!${NC}"
    kill -9 $pid 2>/dev/null
    return 124
}

# --- 基础工具检查与安装 ---
install_base_tools() {
    echo -e "${BLUE}=== 正在检查并安装必要的基础工具 ===${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo -e "${RED}无法检测操作系统类型，尝试默认使用 apt...${NC}"
        OS="debian"
    fi

    local tools_needed=""
    for tool in curl wget git; do
        if ! command -v $tool &> /dev/null; then
            tools_needed="$tools_needed $tool"
        fi
    done

    if [ -n "$tools_needed" ]; then
        echo -e "${YELLOW}正在安装缺失的工具:${tools_needed}${NC}"
        case $OS in
            ubuntu|debian)
                apt-get update -y && apt-get install -y $tools_needed
                ;;
            centos|rhel|almalinux|rocky)
                yum install -y $tools_needed
                ;;
            arch|manjaro)
                pacman -Sy --noconfirm $tools_needed
                ;;
            *)
                echo -e "${RED}不支持的操作系统: $OS，请手动安装: $tools_needed${NC}"
                exit 1
                ;;
        esac
    fi
    echo -e "${GREEN}基础工具检查完毕。${NC}\n"
}

# --- Docker 安装与检查 ---
install_docker() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo -e "${GREEN}✅ Docker 及 Docker Compose 已安装，跳过。${NC}\n"
        return
    fi

    echo -e "${BLUE}=== 正在安装 Docker 环境 ===${NC}"
    if [[ "$OS" == "arch" || "$OS" == "manjaro" ]]; then
        pacman -Sy --noconfirm docker docker-compose
        systemctl enable --now docker
    else
        # 尝试使用官方脚本
        if ! run_with_countdown "curl -fsSL https://get.docker.com -o get-docker.sh" 15 "下载 Docker 官方安装脚本"; then
            echo -e "${YELLOW}官方源超时，切换到 Aliyun 备用源下载...${NC}"
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh --mirror Aliyun
        else
            sh get-docker.sh
        fi
        systemctl enable --now docker
    fi
    echo -e "${GREEN}Docker 安装完成。${NC}\n"
}

# --- 从 GitHub 拉取项目的容灾逻辑 ---
clone_project_with_fallback() {
    local target_dir=$1
    rm -rf "$target_dir"
    
    local url_main="https://github.com/${GITHUB_REPO}.git"
    local url_m1="${MIRROR_1_PREFIX}${GITHUB_REPO}.git"
    local url_m2="${MIRROR_2_PREFIX}${GITHUB_REPO}.git"

    if run_with_countdown "git clone $url_main $target_dir" 15 "通过 GitHub 官方源克隆代码"; then
        return 0
    fi
    
    echo -e "${YELLOW}官方源超时，切换备用源 1...${NC}"
    if run_with_countdown "git clone $url_m1 $target_dir" 15 "通过备用源1 (GHProxy) 克隆代码"; then
        return 0
    fi
    
    echo -e "${YELLOW}备用源 1 超时，切换备用源 2...${NC}"
    if run_with_countdown "git clone $url_m2 $target_dir" 15 "通过备用源2 (GitMirror) 克隆代码"; then
        return 0
    fi

    # 全部失败
    echo -e "${RED}所有镜像源均连接超时！${NC}"
    read -p "是否重试? [Y/n]: " retry
    if [[ "$retry" != "n" && "$retry" != "N" ]]; then
        clone_project_with_fallback "$target_dir"
    else
        echo -e "${RED}已取消安装。${NC}"
        exit 1
    fi
}

# --- 创建快捷命令方案 ---
create_shortcuts() {
    # 将自身保存为系统命令
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"

    local aliases=("nfp" "NFP" "aero" "AERO" "areo" "AREO")
    for a in "${aliases[@]}"; do
        ln -sf "$SCRIPT_PATH" "/usr/local/bin/$a"
    done
    echo -e "${GREEN}✅ 已生成快捷启动命令！随时在终端输入 ${YELLOW}nfp${GREEN} 或 ${YELLOW}aero${GREEN} 唤出本菜单。${NC}"
}

# --- 安装: 模式 A (本地构建) ---
install_local_build() {
    echo -e "${BLUE}=== 开始本地构建部署 ===${NC}"
    clone_project_with_fallback "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit

    echo -e "${CYAN}正在通过 Docker Compose 构建并启动... 这可能需要几分钟。${NC}"
    docker compose up -d --build
    
    echo -e "${GREEN}\n🎉 安装完成！面板正在后台运行。${NC}"
    echo -e "访问地址: ${YELLOW}http://你的服务器IP:3000${NC}"
    echo -e "默认管理密码: ${YELLOW}admin123${NC} (请登录后强制修改)"
}

# --- 安装: 模式 B (拉取官方镜像) ---
install_prebuilt_image() {
    echo -e "${BLUE}=== 开始拉取预构建镜像部署 ===${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit

    cat > docker-compose.yml <<EOF
version: '3.8'
services:
  aero-panel:
    image: ${DOCKER_IMAGE}
    container_name: aero-panel
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis

  redis:
    image: redis:alpine
    container_name: aero-redis
    restart: unless-stopped
    volumes:
      - aero-redis-data:/data
    command: redis-server --appendonly yes

volumes:
  aero-redis-data:
EOF

    echo -e "${CYAN}正在拉取镜像并启动容器...${NC}"
    if ! docker compose pull; then
        echo -e "${RED}拉取镜像失败！可能是国内网络原因。${NC}"
        echo -e "建议尝试配置 Docker 国内镜像加速源，或选择【1】本地构建模式。"
        exit 1
    fi
    docker compose up -d

    echo -e "${GREEN}\n🎉 安装完成！面板正在后台运行。${NC}"
    echo -e "访问地址: ${YELLOW}http://你的服务器IP:3000${NC}"
    echo -e "默认管理密码: ${YELLOW}admin123${NC} (请登录后强制修改)"
}

# --- 更新项目 ---
update_project() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${RED}未检测到安装目录 ($INSTALL_DIR)，请先执行安装！${NC}"
        exit 1
    fi
    cd "$INSTALL_DIR" || exit
    
    echo -e "${BLUE}=== 正在更新项目 ===${NC}"
    # 判断是代码构建还是纯镜像
    if [ -d ".git" ]; then
        echo -e "${CYAN}检测到本地构建模式，正在拉取最新代码...${NC}"
        git reset --hard
        git pull
        docker compose up -d --build
    else
        echo -e "${CYAN}检测到镜像运行模式，正在拉取最新镜像...${NC}"
        docker compose pull
        docker compose up -d
    fi
    echo -e "${GREEN}✅ 更新完成！${NC}"
}

# --- 重置 (销毁数据库恢复默认) ---
reinstall_project() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${RED}未检测到安装目录！${NC}"
        exit 1
    fi
    
    echo -e "${RED}⚠️ 警告：这将会彻底删除面板内的所有节点和转发规则！${NC}"
    read -p "确定要重装/恢复出厂设置吗? [y/N]: " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        cd "$INSTALL_DIR" || exit
        echo -e "${CYAN}正在停止并清理数据卷...${NC}"
        docker compose down -v
        echo -e "${CYAN}重新启动服务...${NC}"
        docker compose up -d
        echo -e "${GREEN}✅ 重置成功！当前为出厂默认状态。${NC}"
    else
        echo -e "已取消重置。"
    fi
}

# --- 彻底卸载 ---
uninstall_project() {
    echo -e "${RED}⚠️ 警告：这将会彻底卸载本面板，并删除所有相关文件及数据！${NC}"
    read -p "确定要卸载吗? [y/N]: " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        if [ -d "$INSTALL_DIR" ]; then
            cd "$INSTALL_DIR" || exit
            docker compose down -v
            cd /
            rm -rf "$INSTALL_DIR"
        fi
        
        # 删除所有生成的快捷命令
        rm -f "/usr/local/bin/nfp" "/usr/local/bin/NFP" "/usr/local/bin/aero" "/usr/local/bin/AERO" "/usr/local/bin/areo" "/usr/local/bin/AREO"
        rm -f "$SCRIPT_PATH"
        
        echo -e "${GREEN}✅ 卸载完成。后会有期！${NC}"
        exit 0
    else
        echo -e "已取消卸载。"
    fi
}

# --- 主菜单 ---
show_menu() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}       AeroNode / NFP 面板 一键管理脚本       ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${CYAN}  1.${NC} 🚀 安装项目 (下载源码本地构建 - 推荐)"
    echo -e "${CYAN}  2.${NC} 📦 安装项目 (拉取官方预构建镜像)"
    echo -e "${CYAN}  3.${NC} 🔄 更新项目 (保持数据更新至最新版本)"
    echo -e "${CYAN}  4.${NC} 🗑️ 重置面板 (清空数据库恢复初始密码)"
    echo -e "${CYAN}  5.${NC} ❌ 彻底卸载 (清除所有数据与容器)"
    echo -e "${CYAN}  0.${NC} 退出脚本"
    echo -e "${BLUE}================================================${NC}"
    echo -e "提示: 安装后可通过输入 ${YELLOW}nfp${NC} 随时唤出本菜单。"
    echo ""
    read -p "请输入对应数字 [0-5]: " choice

    case "$choice" in
        1)
            install_base_tools
            install_docker
            install_local_build
            create_shortcuts
            ;;
        2)
            install_base_tools
            install_docker
            install_prebuilt_image
            create_shortcuts
            ;;
        3)
            update_project
            ;;
        4)
            reinstall_project
            ;;
        5)
            uninstall_project
            ;;
        0)
            echo -e "${GREEN}已退出。${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}请输入正确的数字！${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

# 脚本入口
check_root

# 如果带有参数执行 (方便以后扩展)，暂不处理
if [ -n "$1" ]; then
    echo "使用菜单管理请直接运行 nfp"
    exit 0
fi

show_menu