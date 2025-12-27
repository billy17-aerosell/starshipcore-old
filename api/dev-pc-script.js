// Development endpoint to serve StarshipCore.lua for local testing
// Usage: loadstring(game:HttpGet("http://localhost:3000/api/dev-pc-script?t=" .. os.time()))()
// The ?t=timestamp parameter helps bypass executor caching

import fs from "fs";
import path from "path";

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const timestamp = new Date().toISOString();

  // Check if we're in development mode
  const isDev =
    process.env.NODE_ENV === "development" ||
    process.env.VERCEL_ENV === "development" ||
    req.headers.host?.includes("localhost");

  // In production, require authentication
  if (!isDev) {
    const { userId } = req.query;

    if (!userId) {
      console.log(
        `[${timestamp}] ❌ DEV-PC-SCRIPT - Production access without userId`,
      );
      return res
        .status(403)
        .send('error("This endpoint is for development only")');
    }

    // In production, redirect to proper authenticated endpoint
    console.log(
      `[${timestamp}] ⚠️ DEV-PC-SCRIPT - Redirecting to proper endpoint`,
    );
    return res.status(403).send('error("Use /api/bootstrap for production")');
  }

  console.log(
    `[${timestamp}] 🛠️ DEV-PC-SCRIPT - Serving StarshipCore.lua for development`,
  );

  try {
    // Read StarshipCore.lua from data folder
    const scriptPath = path.join(process.cwd(), "data", "StarshipCore.lua");

    if (!fs.existsSync(scriptPath)) {
      console.error(
        `[${timestamp}] ❌ DEV-PC-SCRIPT - File not found: ${scriptPath}`,
      );
      return res.status(404).send('error("StarshipCore.lua not found")');
    }

    let scriptContent = fs.readFileSync(scriptPath, "utf8");

    // Remove BOM if present
    if (scriptContent.charCodeAt(0) === 0xfeff) {
      scriptContent = scriptContent.slice(1);
    }

    // Inject server mode configuration for HTTP module loading
    // This ensures modules are loaded from the dev server, not local files
    const serverModeConfig = `
-- AUTO-INJECTED BY DEV SERVER --
_G.StarshipServerMode = true
_G.StarshipServerURL = "http://localhost:3000"
_G.StarshipBaseURL = "http://localhost:3000"

-- Set session for dev mode (enables cloud features)
if not getgenv then getgenv = function() return _G end end
getgenv().StarshipSession = {
    Role = "OWNER",
    UserId = "DEV_USER",
    DevMode = true
}
-- END AUTO-INJECTION --

`;

    // Insert at the beginning of the script (after the header comment)
    // This ensures _G.StarshipServerURL is set before anything else runs
    scriptContent = serverModeConfig + scriptContent;

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.setHeader("X-Mode", "development");
    res.setHeader("X-Platform", "pc");

    console.log(
      `[${timestamp}] ✅ DEV-PC-SCRIPT - Served successfully (${scriptContent.length} bytes)`,
    );

    return res.status(200).send(scriptContent);
  } catch (error) {
    console.error(`[${timestamp}] ❌ DEV-PC-SCRIPT - Error:`, error);
    return res.status(500).send('error("Failed to load StarshipCore.lua")');
  }
}
