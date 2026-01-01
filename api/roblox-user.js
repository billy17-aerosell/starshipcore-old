// Proxy API for Roblox User validation (bypasses CORS)

export default async function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const { userId, username } = req.query;

    try {
        let userData = null;

        // If userId is provided, fetch by ID
        if (userId) {
            const response = await fetch(`https://users.roblox.com/v1/users/${userId}`);
            
            if (!response.ok) {
                return res.status(404).json({ error: 'User not found' });
            }
            
            userData = await response.json();
        }
        // If username is provided, search by username
        else if (username) {
            // First try exact match
            const searchResponse = await fetch(
                `https://users.roblox.com/v1/usernames/users`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        usernames: [username],
                        excludeBannedUsers: true
                    })
                }
            );

            if (searchResponse.ok) {
                const searchData = await searchResponse.json();
                if (searchData.data && searchData.data.length > 0) {
                    const foundUser = searchData.data[0];
                    // Fetch full user data
                    const userResponse = await fetch(`https://users.roblox.com/v1/users/${foundUser.id}`);
                    if (userResponse.ok) {
                        userData = await userResponse.json();
                    }
                }
            }

            if (!userData) {
                return res.status(404).json({ error: 'User not found' });
            }
        }
        else {
            return res.status(400).json({ error: 'userId or username required' });
        }

        // Fetch avatar thumbnail URL from Roblox Thumbnails API
        let avatarUrl = null;
        try {
            const thumbnailResponse = await fetch(
                `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userData.id}&size=150x150&format=Png&isCircular=false`
            );
            
            if (thumbnailResponse.ok) {
                const thumbnailData = await thumbnailResponse.json();
                if (thumbnailData.data && thumbnailData.data.length > 0) {
                    avatarUrl = thumbnailData.data[0].imageUrl;
                }
            }
        } catch (e) {
            console.error('Failed to fetch avatar:', e);
        }

        // Fallback avatar if thumbnails API fails
        if (!avatarUrl) {
            avatarUrl = `https://tr.rbxcdn.com/30DAY-AvatarHeadshot-${userData.id}-150x150.png`;
        }

        // Return user data with avatar URL
        return res.status(200).json({
            id: userData.id,
            name: userData.name,
            displayName: userData.displayName,
            avatar: avatarUrl
        });

    } catch (error) {
        console.error('Roblox API error:', error);
        return res.status(500).json({ error: 'Failed to fetch user data' });
    }
}
