import Redis from 'ioredis';

// 默認連接到同一 Docker 網絡下的 redis 容器，也可以通過環境變量覆蓋
// 支持 redis://:password@host:port/db 格式
const redis = new Redis(process.env.REDIS_URL || 'redis://redis:6379');

/**
 * 通用 KV 適配器
 * 封裝了 ioredis，自動處理 JSON 序列化/反序列化
 * 旨在兼容 Vercel KV 和標準 Redis 操作習慣
 */
export const kv = {
  /**
   * 獲取原始 Redis 實例 (如果需要執行更複雜的原生指令)
   */
  original: redis,

  // ==========================================
  // 基礎 Key-Value 操作
  // ==========================================

  get: async <T>(key: string): Promise<T | null> => {
    const val = await redis.get(key);
    try {
      return val ? JSON.parse(val) : null;
    } catch (e) {
      // 如果不是 JSON，返回原始字符串（兼容舊數據或計數器）
      return val as unknown as T;
    }
  },

  /**
   * 設置值
   * @param options.ex 過期時間（秒）
   * @param options.px 過期時間（毫秒）
   * @param options.nx 若為 true，僅當鍵不存在時設置 (SETNX)
   * @param options.xx 若為 true，僅當鍵存在時設置 (SETXX)
   */
  set: async (key: string, value: any, options?: { ex?: number; px?: number; nx?: boolean; xx?: boolean }) => {
    const strVal = JSON.stringify(value);
    
    // 構建參數數組
    const args: (string | number)[] = [key, strVal];
    
    if (options) {
      if (options.ex) { args.push('EX', options.ex); }
      if (options.px) { args.push('PX', options.px); }
      if (options.nx) { args.push('NX'); }
      if (options.xx) { args.push('XX'); }
    }

    // 使用 apply 調用 redis.set 以支持動態參數
    // @ts-ignore: ioredis 類型定義在動態參數上可能報錯，但運行時是支持的
    await redis.set(...args);
  },

  mget: async <T>(...keys: string[]): Promise<(T | null)[]> => {
    if (keys.length === 0) return [];
    const vals = await redis.mget(...keys);
    return vals.map(v => {
      try { return v ? JSON.parse(v) : null; } catch { return v as unknown as T; }
    });
  },

  del: async (...keys: string[]) => {
    if (keys.length > 0) await redis.del(...keys);
  },

  exists: async (...keys: string[]): Promise<number> => {
    if (keys.length === 0) return 0;
    return await redis.exists(...keys);
  },

  expire: async (key: string, seconds: number) => {
    await redis.expire(key, seconds);
  },

  ttl: async (key: string): Promise<number> => {
    return await redis.ttl(key);
  },

  // ==========================================
  // 計數器操作 (適用於 ID 生成、限流等)
  // ==========================================

  incr: async (key: string): Promise<number> => {
    return await redis.incr(key);
  },

  incrby: async (key: string, value: number): Promise<number> => {
    return await redis.incrby(key, value);
  },

  decr: async (key: string): Promise<number> => {
    return await redis.decr(key);
  },

  // ==========================================
  // Hash 操作 (適用於存儲對象、節點信息等)
  // ==========================================

  hget: async <T>(key: string, field: string): Promise<T | null> => {
    const val = await redis.hget(key, field);
    try {
      return val ? JSON.parse(val) : null;
    } catch (e) {
      return val as unknown as T;
    }
  },

  hset: async (key: string, obj: Record<string, any>) => {
    const stringifiedObj: Record<string, string> = {};
    for (const [k, v] of Object.entries(obj)) {
      stringifiedObj[k] = (typeof v === 'string') ? v : JSON.stringify(v);
    }
    if (Object.keys(stringifiedObj).length > 0) {
      await redis.hset(key, stringifiedObj);
    }
  },

  hgetall: async <T = Record<string, any>>(key: string): Promise<T | null> => {
    const val = await redis.hgetall(key);
    if (!val || Object.keys(val).length === 0) return null;
    
    const result: Record<string, any> = {};
    for (const [k, v] of Object.entries(val)) {
      try {
        result[k] = JSON.parse(v);
      } catch (e) {
        result[k] = v; // 如果解析失敗，保留原值
      }
    }
    return result as T;
  },

  hdel: async (key: string, ...fields: string[]) => {
    if (fields.length > 0) await redis.hdel(key, ...fields);
  },

  hexists: async (key: string, field: string): Promise<boolean> => {
    const result = await redis.hexists(key, field);
    return result === 1;
  },

  // ==========================================
  // List 操作 (適用於隊列、日誌、規則列表)
  // ==========================================

  lpush: async (key: string, ...values: any[]) => {
    if (values.length === 0) return;
    const strings = values.map(v => (typeof v === 'string' ? v : JSON.stringify(v)));
    await redis.lpush(key, ...strings);
  },

  rpush: async (key: string, ...values: any[]) => {
    if (values.length === 0) return;
    const strings = values.map(v => (typeof v === 'string' ? v : JSON.stringify(v)));
    await redis.rpush(key, ...strings);
  },

  lrange: async <T>(key: string, start: number, stop: number): Promise<T[]> => {
    const vals = await redis.lrange(key, start, stop);
    return vals.map(v => {
      try { return JSON.parse(v); } catch { return v as unknown as T; }
    });
  },

  lpop: async <T>(key: string): Promise<T | null> => {
    const val = await redis.lpop(key);
    try { return val ? JSON.parse(val) : null; } catch { return val as unknown as T; }
  },

  rpop: async <T>(key: string): Promise<T | null> => {
    const val = await redis.rpop(key);
    try { return val ? JSON.parse(val) : null; } catch { return val as unknown as T; }
  },

  llen: async (key: string): Promise<number> => {
    return await redis.llen(key);
  },

  // ==========================================
  // Set 操作 (適用於標籤、黑名單、唯一集合)
  // ==========================================

  sadd: async (key: string, ...values: any[]) => {
    if (values.length === 0) return;
    const strings = values.map(v => (typeof v === 'string' ? v : JSON.stringify(v)));
    await redis.sadd(key, ...strings);
  },

  srem: async (key: string, ...values: any[]) => {
    if (values.length === 0) return;
    const strings = values.map(v => (typeof v === 'string' ? v : JSON.stringify(v)));
    await redis.srem(key, ...strings);
  },

  smembers: async <T>(key: string): Promise<T[]> => {
    const vals = await redis.smembers(key);
    return vals.map(v => {
      try { return JSON.parse(v); } catch { return v as unknown as T; }
    });
  },

  sismember: async (key: string, value: any): Promise<boolean> => {
    const strVal = (typeof value === 'string') ? value : JSON.stringify(value);
    const result = await redis.sismember(key, strVal);
    return result === 1;
  },

  // ==========================================
  // 管理與測試
  // ==========================================

  keys: async (pattern: string): Promise<string[]> => {
    return await redis.keys(pattern);
  },

  flushall: async () => {
    await redis.flushall();
  }
};
