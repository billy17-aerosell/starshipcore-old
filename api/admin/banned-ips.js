// Admin endpoint to manage banned IPs
// GET: List all banned IPs
// DELETE: Unban specific IP or clear all

const ADMIN_KEY = process.env.ADMIN_SECRET || "starship-admin-2024";
const BANNED_IPS_KEY = "starship:banned_ips";

// Redis client
let redis = null;

async function getRedis() {
  if (!redis) {
    try {
      const redisModule = await import("../../lib/redis.js");
      redis = redisModule.default;
    } catch (error) {
      console.error("Failed to load Redis:", error.message);
    }
  }
  return redis;
}

export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  // Check admin key
  const { key, ip, action } = req.query;
  
  if (key !== ADMIN_KEY) {
    return res.status(403).json({ 
      error: "Unauthorized",
      message: "Invalid admin key" 
    });
  }

  const redisClient = await getRedis();
  
  if (!redisClient) {
    return res.status(500).json({ 
      error: "Redis not available",
      message: "Could not connect to Redis" 
    });
  }

  try {
    // GET: List all banned IPs
    if (req.method === "GET") {
      const bannedIPs = await redisClient.smembers(BANNED_IPS_KEY);
      
      return res.status(200).json({
        success: true,
        count: bannedIPs.length,
        bannedIPs: bannedIPs,
        timestamp: new Date().toISOString()
      });
    }

    // DELETE: Unban IP or clear all
    if (req.method === "DELETE") {
      // Clear all bans
      if (action === "clear-all") {
        await redisClient.del(BANNED_IPS_KEY);
        return res.status(200).json({
          success: true,
          message: "All bans cleared",
          timestamp: new Date().toISOString()
        });
      }
      
      // Unban specific IP
      if (ip) {
        const removed = await redisClient.srem(BANNED_IPS_KEY, ip);
        return res.status(200).json({
          success: true,
          unbanned: ip,
          wasInList: removed === 1,
          timestamp: new Date().toISOString()
        });
      }
      
      return res.status(400).json({
        error: "Missing parameter",
        message: "Provide 'ip' to unban specific IP or 'action=clear-all' to clear all"
      });
    }

    return res.status(405).json({ error: "Method not allowed" });
    
  } catch (error) {
    console.error("[Admin] Error:", error.message);
    return res.status(500).json({ 
      error: "Server error",
      message: error.message 
    });
  }
}
