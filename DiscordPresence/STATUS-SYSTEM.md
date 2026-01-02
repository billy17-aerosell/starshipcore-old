# StarshipCore Status System

Sistem untuk menampilkan status operasional StarshipCore di:

1. **Website** - Badge status di halaman utama
2. **Discord Channel** - Embed status yang auto-update

## 🚀 Setup

### 1. Buat Discord Webhook

1. Buka Discord Server Settings
2. Pilih **Integrations** > **Webhooks**
3. Klik **New Webhook**
4. Beri nama "StarshipCore Status"
5. Pilih channel untuk status (misal: `#status`)
6. Copy Webhook URL

### 2. Tambahkan ke Environment Variables

Di Vercel atau `.env`:

```env
DISCORD_STATUS_WEBHOOK_URL=https://discord.com/api/webhooks/xxx/yyy
```

### 3. Update Status

#### Menggunakan CLI:

```bash
cd DiscordPresence
node set-status.js online
node set-status.js maintenance "Scheduled maintenance until 10:00 AM"
node set-status.js updating "Deploying v2.5.0"
```

Buat `config.json` di folder DiscordPresence berdasarkan `config.example.json`:

```json
{
  "apiUrl": "https://starship-core.my.id/api/status",
  "adminSecret": "YOUR_ADMIN_SECRET"
}
```

#### Menggunakan API langsung:

```bash
curl -X POST https://starship-core.my.id/api/status \
  -H "Content-Type: application/json" \
  -H "x-admin-secret: YOUR_SECRET" \
  -d '{"status": "maintenance", "message": "Server sedang maintenance"}'
```

## 📊 Status Types

| Status        | Emoji | Description               |
| ------------- | ----- | ------------------------- |
| `online`      | 🟢    | All systems operational   |
| `maintenance` | 🟠    | System under maintenance  |
| `offline`     | 🔴    | System is offline         |
| `degraded`    | 🟡    | Some features unavailable |
| `updating`    | 🔵    | New update being deployed |

## 🎨 Tampilan

### Website

- Status badge muncul di bawah logo
- Jika `maintenance` atau `offline`, banner warning akan muncul di atas halaman

### Discord Channel

- Embed dengan warna sesuai status
- Timestamp kapan terakhir diupdate
- Logo StarshipCore sebagai thumbnail

## 📡 API Endpoints

### GET /api/status

Mendapatkan status saat ini (public).

Response:

```json
{
  "success": true,
  "status": "online",
  "label": "Online",
  "emoji": "🟢",
  "color": 58230,
  "message": "All systems operational",
  "description": "All systems operational",
  "lastUpdated": "2026-01-02T10:00:00.000Z"
}
```

### POST /api/status

Mengubah status (requires admin secret).

Headers:

- `x-admin-secret`: Your admin secret

Body:

```json
{
  "status": "maintenance",
  "message": "Optional custom message"
}
```

Response:

```json
{
  "success": true,
  "status": "maintenance",
  "label": "Maintenance",
  "emoji": "🟠",
  "message": "Optional custom message",
  "lastUpdated": "2026-01-02T10:00:00.000Z",
  "discordUpdated": true
}
```

## 🔧 Troubleshooting

### Discord tidak update

1. Pastikan `DISCORD_STATUS_WEBHOOK_URL` sudah diset di environment
2. Cek apakah webhook URL valid
3. Pastikan bot punya permission di channel

### Website tidak menampilkan status

1. Cek console browser untuk error
2. Pastikan `/api/status` bisa diakses
3. Cek CORS jika domain berbeda

## 📝 Notes

- Status disimpan di Redis jika tersedia, jika tidak di memory
- Jika menggunakan memory, status akan reset saat cold start
- Discord webhook dipanggil setiap kali status berubah
