import Redis from 'ioredis';

// 默認連接到同一 Docker 網絡下的 redis 容器，也可以通過環境變量覆蓋
const redis = new Redis(process.env.REDIS_URL || 'redis://redis:6379');

export const kv = {
  get: async <T>(key: string): Promise<T | null> => {
    const val = await redis.get(key);
    try {
      return val ? JSON.parse(val) : null;
    } catch (e) {
      return val as unknown as T; // 防止非 JSON 字符串報錯
    }
  },

  // 修改：增加了 options 參數支持 { ex: seconds }
  set: async (key: string, value: any, options?: { ex?: number }) => {
    const strVal = JSON.stringify(value);
    if (options?.ex) {
      // ioredis 支持 set(key, value, 'EX', seconds)
      await redis.set(key, strVal, 'EX', options.ex);
    } else {
      await redis.set(key, strVal);
    }
  },

  // 新增：支持 expire 方法
  expire: async (key: string, seconds: number) => {
    await redis.expire(key, seconds);
  },

  hget: async <T>(key: string, field: string): Promise<T | null> => {
    const val = await redis.hget(key, field);
    try {
      return val ? JSON.parse(val) : null;
    } catch (e) {
      return null;
    }
  },

  hset: async (key: string, obj: Record<string, any>) => {
    // 轉換所有值為 JSON 字符串，防止 [object Object]
    const stringifiedObj: Record<string, string> = {};
    for (const [k, v] of Object.entries(obj)) {
      stringifiedObj[k] = JSON.stringify(v);
    }
    if (Object.keys(stringifiedObj).length > 0) {
      await redis.hset(key, stringifiedObj);
    }
  },

  hgetall: async (key: string) => {
    const val = await redis.hgetall(key);
    if (!val || Object.keys(val).length === 0) return null;
    const result: Record<string, any> = {};
    for (const [k, v] of Object.entries(val)) {
      try {
        result[k] = JSON.parse(v);
      } catch (e) {
        result[k] = v;
      }
    }
    return result;
  },

  del: async (key: string) => {
    await redis.del(key);
  },

  rpush: async (key: string, ...values: any[]) => {
    if (values.length === 0) return;
    const strings = values.map(v => JSON.stringify(v));
    await redis.rpush(key, ...strings);
  },

  lrange: async (key: string, start: number, stop: number) => {
    const vals = await redis.lrange(key, start, stop);
    return vals.map(v => {
      try {
        return JSON.parse(v);
      } catch (e) {
        return v;
      }
    });
  }
};
