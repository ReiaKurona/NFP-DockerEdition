*本項目含有AI創作的內容*

# 🛡️ AeroNode (AeroPanel) - A Nftables Forward Panel (Docker Edition)

> 💡 **Note:** This is the Docker / Self-Hosted version. Looking for the original Vercel (Serverless) version? [Click here](https://github.com/ReiaKurona/NFP/)
>
> 💡 **提示：** 本分支為 Docker 私有化部署版本。尋找原來的 Vercel (Serverless) 版本？[請點擊這裡](https://github.com/ReiaKurona/NFP/)

[![Docker](https://img.shields.io/badge/Deploy_with-Docker-blue?logo=docker)](#)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Next.js](https://img.shields.io/badge/Next.js-14-black)](https://nextjs.org/)
[![nftables](https://img.shields.io/badge/Powered_by-nftables-orange)](#)

[English Version](#english) | [中文說明](#chinese) | [F.A.Q & Reverse Proxy Fix](#faq)

---

<a name="english"></a>
## 🇬🇧 English

AeroNode is a modern, high-performance, and self-hosted port-forwarding management panel based on Linux `nftables`. Designed with Google's Material You (MD3) aesthetics, it allows you to manage port forwarding across multiple Linux servers effortlessly via Docker.

### ✨ Key Features

*   ⚡ **Kernel-Level Performance:** Utilizes `nftables` directly in the Linux kernel. No userspace overhead, making it extremely fast and lightweight.
*   🐳 **Dockerized & Self-Hosted:** The control panel is built with Next.js Standalone mode and fully hosted via Docker + Redis. **100% control over your data with an easy 1-click install.**
*   🔒 **Passive Agent Architecture:** The agent on your VPS runs in "Pull Mode" (Polling). It actively fetches configurations from the panel via standard HTTPS/HTTP GET requests. **No open ports required on your VPS.**
*   🎨 **Material You UI:** Fluid animations (Framer Motion), automatic Dark/Light mode switching, and dynamic theme colors.
*   📊 **Real-time Monitoring:** Live tracking of Node CPU, RAM, RX/TX network speeds, and total traffic.
*   🚀 **Reverse Proxy Friendly:** Optimized configuration templates for Cloudflare/Nginx/aaPanel (Baota) to prevent "Mixed Content" or styling issues.

### 🚀 Deployment Guide

#### Step 1: Deploy the Panel (Docker)
Run the automated installation script on your master server (Requires root privileges):

```bash
curl -sSL https://raw.githubusercontent.com/ReiaKurona/NFP-DockerEdition/refs/heads/main/install.sh | bash
```
*(Follow the interactive menu to install the panel. It will automatically setup Docker, Redis, and the Next.js container.)*

#### Step 2: Login
*   Visit `http://<your-server-ip>:3000` in your browser.
*   Default Password: `admin123` *(You will be forced to change this upon first login).*

#### Step 3: Install the Agent on your VPS
1. Go to the **Nodes** tab in the panel and click **+ Add Node**.
2. Enter a Name and the Public IP of your VPS. Click Save.
3. Copy the generated **One-click Installation Command** (e.g., `curl -sSL http://<your-ip>:3000/api/install | bash...`).
4. Log in to your target Linux VPS as `root` and paste the command.

---

<a name="chinese"></a>
## 🇨🇳 中文說明

AeroNode 是一款基於 Linux `nftables` 的現代化、高性能、私有化部署（Self-Hosted）端口轉發管理面板。採用 Google Material You (MD3) 設計語言，讓你通過 Docker 輕鬆管理多台 Linux 伺服器的流量轉發規則。

### ✨ 核心亮點

*   ⚡ **內核級極致性能**：底層直接操作 `nftables`，內存與 CPU 開銷極低，轉發延遲幾乎為零。
*   🐳 **Docker 容器化架構**：主控面板基於 Next.js Standalone 構建，完美託管於本地 Docker 與 Redis。**配備強大的容災一鍵腳本極速部署。**
*   🔒 **被動式 Agent (高穿透)**：伺服器節點端採用純客戶端輪詢模式。Agent 主動向面板拉取配置，**VPS 無需開放任何公網 API 端口。**
*   🎨 **Material You 視覺美學**：引入 Framer Motion 物理彈動動畫，支援系統級深色/淺色模式無縫切換。
*   📊 **實時儀表盤**：精準監控節點 CPU、內存佔用，以及上下行實時網速與總流量消耗。
*   🛠️ **完美適配反代**：針對 Cloudflare 靈活模式 (Flexible SSL) 及寶塔面板 Nginx 提供了專用配置，解決樣式丟失問題。

### 🚀 部署指南

#### 第一步：部署主控面板 (Docker 一鍵安裝)
在準備作為主控的服務器上（需 `root` 權限），執行以下一鍵安裝腳本：

```bash
curl -sSL https://raw.githubusercontent.com/ReiaKurona/NFP-DockerEdition/refs/heads/main/install.sh | bash
```
*(如果國內機器無法訪問 GitHub，腳本內置了多備用源超時自動切換機制。按照彈出的中文菜單選擇安裝即可。)*

#### 第二步：登錄面板
*   訪問 `http://<你的服務器IP>:3000`。
*   預設管理員密碼：`admin123` *(首次登錄會強制要求修改為強密碼)*。

#### 第三步：在 VPS 安裝 Agent 代理
1. 在面板的 **節點** 頁面，點擊 **+ 添加新節點**。
2. 填寫節點名稱與公網 IP，點擊保存。
3. 複製卡片下方生成的 **一鍵安裝指令** (以 `curl -sSL http://...` 開頭)。
4. SSH 登入你需要進行轉發的 Linux VPS (需 `root` 權限)，粘貼並執行該指令。

---

<a name="faq"></a>
## 🔧 F.A.Q & Reverse Proxy Setup (常見問題與反向代理設置)

### ❓ Issue: Using Cloudflare/Nginx/aaPanel (Baota) causes broken layout (CSS/JS 404) or "Too Many Redirects".
### ❓ 問題：使用 Cloudflare/Nginx/寶塔反代後，頁面樣式丟失 (變成白板/404) 或提示“重定向過多”。

**Reason / 原因:**
1.  **aaPanel/Nginx Caching:** Default Nginx configurations often intercept `.js` and `.css` files, serving them from the local disk instead of forwarding the request to the Docker container.
2.  **Mixed Content (Cloudflare Flexible Mode):** If you use Cloudflare's "Flexible" SSL, the connection to your server is HTTP. Next.js generates HTTP links, but the browser blocks them on an HTTPS page (Mixed Content).
3.  **寶塔/Nginx 緩存攔截：** 默認配置會攔截靜態資源請求，導致無法轉發給 Docker。
4.  **混合內容錯誤：** CF 靈活模式下，Next.js 認為是 HTTP 訪問，生成的資源鏈接被瀏覽器安全策略攔截。

**✅ Solution / 解決方案:**

Please replace your Nginx configuration (In aaPanel: Website -> Reverse Proxy -> Configuration File) with the following code.
請將您的 Nginx 反向代理配置（寶塔面板：網站 -> 反向代理 -> 配置文件）**清空並替換**為以下代碼：

```nginx
# AeroNode Nginx Config 
# AeroNode 反代配置 
# =========================================================
location /
{
    proxy_pass http://127.0.0.1:3000;    
    # Force browser to upgrade HTTP requests to HTTPS
    # 強制瀏覽器將所有 HTTP 資源請求升級為 HTTPS (解決混合內容攔截)
    add_header Content-Security-Policy "upgrade-insecure-requests";
    # Tell Next.js we are using HTTPS
    # 欺騙 Next.js 告知當前為 HTTPS 環境
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Port 443;
    proxy_set_header X-Forwarded-Ssl on;
    # Standard Headers / 標準轉發頭
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  
    # WebSocket Support / WebSocket 支持 (保持實時數據連接)
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    # Disable Cache / 禁用緩存
    proxy_buffering off;
    proxy_cache off;
}

# Fix for Next.js static files (Prevent Nginx form intercepting them)
# 處理 Next.js 靜態資源，防止被 Nginx/寶塔默認規則攔截
location /_next/
{
    proxy_pass http://127.0.0.1:3000;
    add_header Content-Security-Policy "upgrade-insecure-requests";
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}

```

**Additional Step for Cloudflare Users / Cloudflare 用戶額外步驟:**
1.  Go to **Speed** -> **Optimization**. Turn **OFF "Rocket Loader"**. (Crucial for Mobile devices) / 進入 **速度** -> **優化**，**關閉 "Rocket Loader"**（對手機端訪問至關重要）。
2.  Purge Cloudflare Cache. / 清空 CF 緩存。

---

### ⚠️ Disclaimer / 免責聲明

This project is for educational and learning purposes only. Users must comply with local laws and regulations. The developer is not responsible for any misuse of this tool. / 本項目僅供學習與交流網絡技術使用，使用者請務必遵守當地法律法規。開發者對使用本工具產生的任何濫用行為不承擔任何責任。
