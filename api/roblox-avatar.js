// Roblox Avatar Proxy - Bypasses CORS restrictions
// Returns avatar URLs for given user IDs

export default async function handler(req, res) {
  // Allow CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  const { userIds } = req.query;
  
  if (!userIds) {
    return res.status(400).json({ error: 'userIds parameter required' });
  }
  
  try {
    const response = await fetch(
      `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userIds}&size=48x48&format=Png&isCircular=false`
    );
    
    if (!response.ok) {
      throw new Error(`Roblox API returned ${response.status}`);
    }
    
    const data = await response.json();
    
    // Transform the response to a simpler format
    const avatars = {};
    if (data.data) {
      data.data.forEach(item => {
        if (item.state === 'Completed' && item.imageUrl) {
          avatars[item.targetId] = item.imageUrl;
        }
      });
    }
    
    return res.status(200).json({ success: true, avatars });
    
  } catch (error) {
    console.error('Roblox avatar fetch error:', error);
    return res.status(500).json({ error: error.message });
  }
}
