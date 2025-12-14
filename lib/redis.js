// Redis client using ioredis with TLS support for Redis Labs
// With safe error handling and fallback

let redis = null;

try {
  // Try to import ioredis
  const Redis = (await import('ioredis')).default;
  
  // Get Redis URL from environment variables
  const REDIS_URL = process.env.REDIS_URL || process.env.KV_URL;
  
  if (!REDIS_URL) {
    console.warn('⚠️ REDIS_URL not found in environment variables!');
  } else {
    // Parse Redis URL
    // Format: redis://username:password@host:port
    const url = new URL(REDIS_URL);
    
    console.log('🔧 Initializing Redis with:', {
      host: url.hostname,
      port: url.port,
      username: url.username || 'default',
      hasTLS: true
    });
    
    // Initialize Redis client with TLS (Redis Labs requires this!)
    redis = new Redis({
      host: url.hostname,
      port: parseInt(url.port),
      username: url.username || 'default',
      password: url.password,
      tls: {
        // Redis Labs requires TLS
        rejectUnauthorized: false // Accept self-signed certificates
      },
      maxRetriesPerRequest: 3,
      enableReadyCheck: false, // Disable ready check for faster init
      connectTimeout: 10000,
      lazyConnect: true, // Don't connect immediately
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
    
    // Connect now
    await redis.connect();
    console.log('✅ Redis client initialized successfully');
  }
} catch (error) {
  console.error('❌ Failed to initialize Redis:', error.message);
  redis = null;
}

export default redis;
