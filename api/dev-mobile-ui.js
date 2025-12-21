// Development endpoint to serve MobileUI.lua for local testing
// Usage: loadstring(game:HttpGet("http://localhost:3000/api/dev-mobile-ui"))()

import fs from "fs";
import path from "path";

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const timestamp = new Date().toISOString();

  // Check if we're in development mode
  const isDev = process.env.NODE_ENV === "development" ||
                process.env.VERCEL_ENV === "development" ||
                req.headers.host?.includes("localhost");

  // In production, require authentication
  if (!isDev) {
    const { userId } = req.query;

    if (!userId) {
      console.log(`[${timestamp}] ❌ DEV-MOBILE-UI - Production access without userId`);
      return res.status(403).send('error("This endpoint is for development only")');
    }

    // In production, redirect to proper authenticated endpoint
    console.log(`[${timestamp}] ⚠️ DEV-MOBILE-UI - Redirecting to proper endpoint`);
    return res.status(403).send('error("Use /api/mobile-bootstrap for production")');
  }

  console.log(`[${timestamp}] 🛠️ DEV-MOBILE-UI - Serving MobileUI.lua for development`);

  try {
    // Read MobileUI.lua from data folder
    const uiPath = path.join(process.cwd(), "data", "MobileUI.lua");

    if (!fs.existsSync(uiPath)) {
      console.error(`[${timestamp}] ❌ DEV-MOBILE-UI - File not found: ${uiPath}`);
      return res.status(404).send('error("MobileUI.lua not found")');
    }

    const uiScript = fs.readFileSync(uiPath, "utf8");

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.setHeader("X-Mode", "development");
    res.setHeader("X-Platform", "mobile");

    console.log(`[${timestamp}] ✅ DEV-MOBILE-UI - Served successfully (${uiScript.length} bytes)`);

    return res.status(200).send(uiScript);
  } catch (error) {
    console.error(`[${timestamp}] ❌ DEV-MOBILE-UI - Error:`, error);
    return res.status(500).send('error("Failed to load MobileUI.lua")');
  }
}
