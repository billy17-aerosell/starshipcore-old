import fs from "fs";
import path from "path";

/**
 * Bundle endpoint for PC bundle.
 * - If Cloudflare CDN is configured, block direct access to reduce public scraping.
 * - If CDN is NOT configured, serve the local public bundle as a fallback.
 *
 * This route is reached via vercel.json rewrite: /b/pc.json -> /api/bundle-pc
 */
export default function handler(req, res) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).send("Method not allowed");
  }

  const cdnEnabled = !!(process.env.CDN_SECRET_KEY && process.env.CDN_PC_URL);

  // If CDN enabled, block direct public access to the bundle on Vercel.
  if (cdnEnabled) {
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.setHeader("Cache-Control", "no-store");
    return res.status(404).json({ error: "NOT_FOUND" });
  }

  const bundlePath = path.join(process.cwd(), "public", "b", "pc.json");
  if (!fs.existsSync(bundlePath)) {
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.setHeader("Cache-Control", "no-store");
    return res.status(404).json({ error: "NOT_FOUND" });
  }

  const content = fs.readFileSync(bundlePath, "utf8");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  return res.status(200).send(content);
}


