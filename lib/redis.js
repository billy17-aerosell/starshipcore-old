// Redis client using ioredis with TLS support for Redis Labs
import Redis from 'ioredis';

// Get Redis URL from environment variables
const REDIS_URL = process.env.REDIS_URL || 
                  process.env.KV_URL;

if (!REDIS_URL) {
  console.error('❌ REDIS_URL not found in environment variables!');
  throw new Error('REDIS_URL environment variable is required');
}

// Parse Redis URL
// Format: redis://username:password@host:port
const url = new URL(REDIS_URL);

// Initialize Redis client with TLS (Redis Labs requires this!)
const redis = new Redis({
  host: url.hostname,
  port: parseInt(url.port),
  username: url.username || 'default',
  password: url.password,
  tls: {
    // Redis Labs requires TLS
    rejectUnauthorized: false // Accept self-signed certificates
  },
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  connectTimeout: 10000,
  retryStrategy(times) {
    if (times > 3) {
      console.error('❌ Redis connection failed after 3 retries');
      return null; // Stop retrying
    }
    const delay = Math.min(times * 200, 2000);
    return delay;
  }
});

// Handle connection events
redis.on('connect', () => {
  console.log('✅ Redis connecting...');
});

redis.on('ready', () => {
  console.log('✅ Redis connected and ready!');
});

redis.on('error', (err) => {
  console.error('❌ Redis error:', err.message);
});

redis.on('close', () => {
  console.log('⚠️ Redis connection closed');
});

export default redis;
