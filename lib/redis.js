// Redis client using ioredis for traditional Redis
import Redis from 'ioredis';

// Get Redis URL from environment variables
// Format: redis://username:password@host:port
const REDIS_URL = process.env.REDIS_URL || 
                  process.env.KV_URL ||
                  'redis://default:jBY8li1RCC3piHGccA6ROjTP3gf9LtJE@redis-14973.c252.ap-southeast-1-1.ec2.cloud.redislabs.com:14973';

// Initialize Redis client
const redis = new Redis(REDIS_URL, {
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  lazyConnect: false, // Connect immediately
  retryStrategy(times) {
    const delay = Math.min(times * 50, 2000);
    return delay;
  }
});

// Handle connection events
redis.on('connect', () => {
  console.log('✅ Redis connected successfully');
});

redis.on('error', (err) => {
  console.error('❌ Redis connection error:', err.message);
});

export default redis;
