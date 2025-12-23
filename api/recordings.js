// api/recordings.js - Cloud Recording Storage via GitHub Gist (FREE!)
// No Redis needed for recordings - uses GitHub Gist as free storage

// DEV: Hardcode token for local testing (Remove before deploy!)
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || "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";
const GIST_API = "https://api.github.com/gists";
const ADMIN_SECRET = process.env.ADMIN_SECRET;

// Simple in-memory cache for user's gist list (resets on cold start, but that's OK)
// For persistent index, we use a small Redis key or a dedicated index gist
let recordingIndex = {};

// Helper: Check if request is from Roblox executor (not browser)
function isRobloxExecutor(req) {
  const userAgent = req.headers["user-agent"] || "";
  const browserPatterns = [
    "Mozilla",
    "Chrome",
    "Safari",
    "Firefox",
    "Edge",
    "Opera",
  ];
  return !browserPatterns.some((p) => userAgent.includes(p));
}

// Helper: Compress recording data (simple - just remove unnecessary whitespace)
function compressData(data) {
  // For now, just stringify without pretty print
  // Future: could add actual compression
  return JSON.stringify(data);
}

// Helper: Generate short share code from gist ID
function generateShareCode(gistId) {
  // Take first 8 chars of gist ID
  return gistId.substring(0, 8).toUpperCase();
}

// Helper: Create or update user's recording index gist
async function updateUserIndex(userId, recordings) {
  // Store index in memory for now
  // In production, you could use one Redis key per user for the index
  recordingIndex[userId] = recordings;
}

// Helper: Get user's recording index
async function getUserIndex(userId) {
  return recordingIndex[userId] || [];
}

// Helper: Get gist file content (handles large files via raw_url)
async function getGistContent(gistFile) {
  // If file is truncated, fetch from raw_url
  if (gistFile.truncated && gistFile.raw_url) {
    const rawResponse = await fetch(gistFile.raw_url, {
      headers: {
        Authorization: `token ${GITHUB_TOKEN}`,
        "User-Agent": "StarshipCore-Recording-API",
      },
    });
    if (rawResponse.ok) {
      return await rawResponse.text();
    }
    throw new Error("Failed to fetch raw content");
  }
  // Otherwise use content directly
  return gistFile.content;
}

export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-User-Id");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  // Check GitHub token exists
  if (!GITHUB_TOKEN) {
    return res.status(500).json({
      error: "Server configuration error",
      message: "GITHUB_TOKEN not configured",
    });
  }

  const { method } = req;
  const userId = req.query.userId || req.body?.userId;

  // ============================================
  // POST - Save new recording to GitHub Gist
  // ============================================
  if (method === "POST") {
    try {
      const { name, data, gameId, gameName } = req.body;

      if (!userId || !name || !data) {
        return res.status(400).json({
          error: "Missing required fields",
          required: ["userId", "name", "data"],
        });
      }

      // Validate data has frames
      if (!data.Frames || data.Frames.length === 0) {
        return res.status(400).json({
          error: "Invalid recording data",
          message: "Recording must have frames",
        });
      }

      const timestamp = new Date().toISOString();
      const frameCount = data.Frames.length;
      const duration = data.Frames[data.Frames.length - 1]?.t || 0;
      const mode = data.Mode || "Standard";

      // Create gist payload - save name and recording data
      const gistPayload = {
        description: `[StarshipCore] ${name} - User ${userId} - ${frameCount} frames`,
        public: false, // Private gist
        files: {
          [`recording.json`]: {
            content: compressData({
              name: name, // Only store the recording name as metadata
              data: data, // Full recording data with Frames
            }),
          },
        },
      };

      // Create gist via GitHub API
      const response = await fetch(GIST_API, {
        method: "POST",
        headers: {
          Authorization: `token ${GITHUB_TOKEN}`,
          "Content-Type": "application/json",
          "User-Agent": "StarshipCore-Recording-API",
        },
        body: JSON.stringify(gistPayload),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("GitHub API error:", errorText);
        return res.status(500).json({
          error: "Failed to save to cloud",
          details: response.status,
        });
      }

      const gist = await response.json();
      const shareCode = generateShareCode(gist.id);

      // Update user's recording index (in memory for now)
      const userRecordings = await getUserIndex(userId);
      userRecordings.push({
        gistId: gist.id,
        shareCode: shareCode,
        name: name,
        gameId: gameId,
        gameName: gameName,
        frameCount: frameCount,
        duration: duration,
        mode: mode,
        createdAt: timestamp,
      });
      await updateUserIndex(userId, userRecordings);

      return res.status(200).json({
        success: true,
        message: "Recording saved to cloud!",
        gistId: gist.id,
        shareCode: shareCode,
        url: gist.html_url,
      });
    } catch (error) {
      console.error("Save recording error:", error);
      return res.status(500).json({
        error: "Failed to save recording",
        message: error.message,
      });
    }
  }

  // ============================================
  // GET - Load recording by share code or gist ID
  // ============================================
  if (method === "GET") {
    const { shareCode, gistId, list } = req.query;

    // LIST user's recordings
    if (list === "true" && userId) {
      const userRecordings = await getUserIndex(userId);
      return res.status(200).json({
        success: true,
        recordings: userRecordings,
        count: userRecordings.length,
      });
    }

    // LIST ALL public recordings (for mobile dropdown)
    if (list === "all") {
      try {
        // Fetch all StarshipCore gists (public recordings)
        const response = await fetch(`${GIST_API}?per_page=100`, {
          headers: {
            Authorization: `token ${GITHUB_TOKEN}`,
            "User-Agent": "StarshipCore-Recording-API",
          },
        });

        if (!response.ok) {
          const errorText = await response.text();
          console.error("GitHub API error:", response.status, errorText);
          return res.status(500).json({
            error: "Failed to fetch recordings list",
            status: response.status,
            details: errorText.substring(0, 200)
          });
        }

        const gists = await response.json();
        
        // Filter only StarshipCore recordings
        const recordings = [];
        for (const gist of gists) {
          if (gist.description && gist.description.includes("[StarshipCore]")) {
            // Extract name from description: "[StarshipCore] RecordingName"
            const nameMatch = gist.description.match(/\[StarshipCore\]\s*(.+)/);
            const name = nameMatch ? nameMatch[1].trim() : "Unknown";
            
            recordings.push({
              shareCode: gist.id.substring(0, 8).toUpperCase(),
              gistId: gist.id,
              name: name,
              createdAt: gist.created_at,
              updatedAt: gist.updated_at,
            });
          }
        }

        // Sort by most recent first
        recordings.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));

        return res.status(200).json({
          success: true,
          recordings: recordings,
          count: recordings.length,
        });
      } catch (error) {
        console.error("List all recordings error:", error);
        return res.status(500).json({
          error: "Failed to list recordings",
          message: error.message,
        });
      }
    }

    // GET specific recording
    const targetGistId = gistId || shareCode; // shareCode is partial gistId

    if (!targetGistId) {
      return res.status(400).json({
        error: "Missing gistId or shareCode",
        usage: "/api/recordings?gistId=xxx or ?shareCode=xxx",
      });
    }

    try {
      // If shareCode (8 chars), we need to search
      // For now, assume full gistId is provided or try partial match
      let fullGistId = targetGistId;

      // Try to get the gist
      const response = await fetch(`${GIST_API}/${fullGistId}`, {
        headers: {
          Authorization: `token ${GITHUB_TOKEN}`,
          "User-Agent": "StarshipCore-Recording-API",
        },
      });

      if (!response.ok) {
        // If not found, try searching user's gists
        if (targetGistId.length === 8) {
          // It's a share code, search for matching gist
          const listResponse = await fetch(`${GIST_API}?per_page=100`, {
            headers: {
              Authorization: `token ${GITHUB_TOKEN}`,
              "User-Agent": "StarshipCore-Recording-API",
            },
          });

          if (listResponse.ok) {
            const gists = await listResponse.json();
            const matchingGist = gists.find(
              (g) =>
                g.id.toUpperCase().startsWith(targetGistId.toUpperCase()) &&
                g.description.includes("[StarshipCore]"),
            );

            if (matchingGist) {
              fullGistId = matchingGist.id;

              // Fetch the full gist
              const fullResponse = await fetch(`${GIST_API}/${fullGistId}`, {
                headers: {
                  Authorization: `token ${GITHUB_TOKEN}`,
                  "User-Agent": "StarshipCore-Recording-API",
                },
              });

              if (fullResponse.ok) {
                const gist = await fullResponse.json();
                const fileName = Object.keys(gist.files)[0];
                const rawContent = await getGistContent(gist.files[fileName]);
                const content = JSON.parse(rawContent);

                return res.status(200).json({
                  success: true,
                  recording: content.data,
                  name: content.name,
                  shareCode: generateShareCode(gist.id),
                });
              }
            }
          }
        }

        return res.status(404).json({
          error: "Recording not found",
          shareCode: targetGistId,
        });
      }

      const gist = await response.json();

      // Verify it's a StarshipCore recording
      if (!gist.description.includes("[StarshipCore]")) {
        return res.status(404).json({
          error: "Not a StarshipCore recording",
        });
      }

      const fileName = Object.keys(gist.files)[0];
      const rawContent = await getGistContent(gist.files[fileName]);
      const content = JSON.parse(rawContent);

      return res.status(200).json({
        success: true,
        recording: content.data,
        name: content.name,
        shareCode: generateShareCode(gist.id),
      });
    } catch (error) {
      console.error("Load recording error:", error);
      return res.status(500).json({
        error: "Failed to load recording",
        message: error.message,
      });
    }
  }

  // ============================================
  // DELETE - Delete recording by gist ID
  // ============================================
  if (method === "DELETE") {
    const { gistId } = req.query;

    if (!gistId) {
      return res.status(400).json({
        error: "Missing gistId",
      });
    }

    try {
      const response = await fetch(`${GIST_API}/${gistId}`, {
        method: "DELETE",
        headers: {
          Authorization: `token ${GITHUB_TOKEN}`,
          "User-Agent": "StarshipCore-Recording-API",
        },
      });

      if (!response.ok && response.status !== 204) {
        return res.status(500).json({
          error: "Failed to delete recording",
        });
      }

      // Remove from user index if userId provided
      if (userId) {
        let userRecordings = await getUserIndex(userId);
        userRecordings = userRecordings.filter((r) => r.gistId !== gistId);
        await updateUserIndex(userId, userRecordings);
      }

      return res.status(200).json({
        success: true,
        message: "Recording deleted",
      });   
    } catch (error) {
      console.error("Delete recording error:", error);
      return res.status(500).json({
        error: "Failed to delete recording",
        message: error.message,
      });
    }
  }

  return res.status(405).json({
    error: "Method not allowed",
    allowed: ["GET", "POST", "DELETE"],
  });
}
