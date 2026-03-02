import Redis from 'ioredis';

// 默认连接到同一 Docker 网络下的 redis 容器，也可以通过环境变量覆盖
const redis = new Redis(process.env.REDIS_URL || 'redis://redis:6379');

export const kv = {
  get: async <T>(key: string): Promise<T | null> => {
    const val = await redis.get(key);
    return val ? JSON.parse(val) : null;
  },
  set: async (key: string, value: any) => {
    await redis.set(key, JSON.stringify(value));
  },
  hget: async <T>(key: string, field: string): Promise<T | null> => {
    const val = await redis.hget(key, field);
    return val ? JSON.parse(val) : null;
  },
  hset: async (key: string, obj: Record<string, any>) => {
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
      result[k] = JSON.parse(v);
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
    return vals.map(v => JSON.parse(v));
  }
};