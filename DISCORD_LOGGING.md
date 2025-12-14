# 🎯 Discord Webhook Logging Setup Guide

## 📋 **Overview**

Discord webhook integration allows you to receive **real-time notifications** whenever someone accesses your loader script. You'll get beautiful embed messages with all the important details!

---

## 🚀 **Quick Setup (3 Steps)**

### **Step 1: Create Discord Webhook**

1. Open your **Discord Server**
2. Create a channel for logs (recommended: `#access-logs` or `#starship-logs`)
3. **Right-click** the channel → `Edit Channel`
4. Go to **Integrations** → **Webhooks**
5. Click **"New Webhook"** or **"Create Webhook"**
6. Give it a name: `StarshipCore Logger` (or any name you like)
7. **Copy the Webhook URL** (it looks like: `https://discord.com/api/webhooks/123456...`)

### **Step 2: Add Webhook to Vercel**

1. Go to **Vercel Dashboard**: https://vercel.com/dashboard
2. Select your **StarshipCore project**
3. Go to **Settings** → **Environment Variables**
4. Click **"Add New"**
5. Enter:
   - **Name**: `DISCORD_WEBHOOK_URL`
   - **Value**: Paste your webhook URL
   - **Environment**: Select `Production` (and `Preview` if you want)
6. Click **"Save"**

### **Step 3: Redeploy**

```powershell
# From your project directory
git add .
git commit -m "Add Discord webhook logging"
git push origin main
```

Vercel will auto-deploy! 🎉

---

## 📊 **What You'll See in Discord**

### **🟢 Successful Access**

```
🟢 Access Granted
━━━━━━━━━━━━━━━
👤 Key Owner: John Doe
🔑 Key: demo-premium-2024
🌐 IP Address: 123.45.67.89
📱 Device Count: 2/5
⏰ Timestamp: 2025-12-14T17:49:12.000Z
✅ Status: Authorized

✅ Loader script successfully delivered to John Doe
```

### **🔴 Invalid Key Attempt**

```
🟠 Invalid Key Attempt
━━━━━━━━━━━━━━━
👤 Key Owner: Unknown
🔑 Key: fake-key-12345
🌐 IP Address: 98.76.54.32
📱 Device Count: N/A
⏰ Timestamp: 2025-12-14T17:50:00.000Z
✅ Status: ❌ Invalid Key

⚠️ Someone tried to use an invalid authentication key!
```

### **🔴 Blocked Access (Expired/Inactive)**

```
🔴 Expired Key Used
━━━━━━━━━━━━━━━
👤 Key Owner: Jane Smith
🔑 Key: old-key-2023
🌐 IP Address: 111.222.333.444
📱 Device Count: N/A
⏰ Timestamp: 2025-12-14T17:51:00.000Z
✅ Status: 🚫 Key Expired

⚠️ Key expired on Dec 1, 2024
```

---

## 🎨 **Embed Color Legend**

- 🟢 **Green** = Successful access (authorized)
- 🔴 **Red** = Blocked (expired, exceeded devices, etc.)
- 🟠 **Orange** = Invalid key attempt
- 🟡 **Yellow** = Warning (future use)

---

## 🔧 **Testing the Setup**

### **Test 1: Valid Key**

```lua
-- In Roblox executor
loadstring(game:HttpGet("https://www.starship-core.my.id/api/get-loader?key=demo-premium-2024"))()
```

✅ Should see green "Access Granted" message in Discord

### **Test 2: Invalid Key**

```lua
loadstring(game:HttpGet("https://www.starship-core.my.id/api/get-loader?key=fake-key-test"))()
```

🟠 Should see orange "Invalid Key Attempt" message

---

## 🛡️ **Security Best Practices**

1. **Keep Webhook URL Secret**

   - Never share it publicly
   - Don't commit it to Git
   - Only store in Vercel environment variables

2. **Set Channel Permissions**

   - Make the log channel **private**
   - Only give access to admins/moderators

3. **Monitor Regularly**
   - Check for repeated invalid key attempts
   - Watch for suspicious IP patterns
   - Track unusual access times

---

## 📱 **Mobile Monitoring**

Because logs go to Discord, you can:

- ✅ Monitor from your phone (Discord mobile app)
- ✅ Get push notifications for access attempts
- ✅ Search logs easily
- ✅ Share with team members

---

## 🔍 **Troubleshooting**

### **Not Receiving Notifications?**

1. **Check Webhook URL**

   ```powershell
   # Verify environment variable is set
   npx vercel env ls
   ```

2. **Check Vercel Logs**

   ```powershell
   npx vercel logs https://your-deployment-url
   ```

   Look for: `[Discord] ✅ Log sent successfully`

3. **Test Webhook Manually**
   ```powershell
   # Test if webhook works
   curl -H "Content-Type: application/json" -d "{\"content\":\"Test message\"}" YOUR_WEBHOOK_URL
   ```

### **Webhook Gets Rate Limited?**

Discord limits:

- **30 requests per minute** per webhook
- **50 requests per second** across all webhooks

If you hit limits:

- Reduce notification frequency
- Batch multiple events
- Use different webhooks for different types

---

## 🆕 **Future Enhancements**

You can customize the code to:

- Send only important events (blocked access only)
- Add more detailed device fingerprinting
- Track access patterns (graph in embed)
- Send daily/weekly summaries
- Integrate with other Discord bots

---

## 📚 **Additional Resources**

- [Discord Webhook Guide](https://discord.com/developers/docs/resources/webhook)
- [Vercel Environment Variables](https://vercel.com/docs/projects/environment-variables)
- [StarshipCore Documentation](./README.md)

---

## 💡 **Need Help?**

Check your Discord logs channel and Vercel deployment logs for any errors!

**Enjoy real-time monitoring!** 🎉
