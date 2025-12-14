// Redis/KV Storage Helper using Upstash
import { Redis } from '@upstash/redis';

// Initialize Redis client
// Environment variables will be auto-injected by Vercel after connecting database
const redis = new Redis({
  url: process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN,
});

export default redis;
