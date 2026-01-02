# FarmCash Email Verification Service

A simple web service to handle email verification for the FarmCash mobile app using Supabase authentication.

## What This Does

FarmCash users can verify their email addresses from any device/browser. When users request email changes in the mobile app, they receive an email with a verification link that opens this web service, completes verification, and shows a success message.

## V1 - Current Implementation (Development)

**Tech Stack:**
- Static HTML/CSS/JavaScript
- Hosted on GitHub Pages
- Direct client-side Supabase API calls

**Files:**
- `index.html` - Single-page email verification handler
- Exposes Supabase anon key in client code
- Suitable for development/testing

**Setup:**
1. User gets verification email from Supabase
2. Link opens: `https://username.github.io/farmcash-verify?token=xxx&type=email_change`
3. JavaScript calls Supabase API to verify token
4. Shows success/error message

## V2 - Production Migration (Recommended)

**Security Improvements:**
- Move to **Netlify Functions** or **Vercel Edge Functions**
- Server-side token verification (no exposed API keys)
- Environment variables for secrets
- Better error handling and logging

**Migration Path:**
```bash
# Deploy to Netlify instead of GitHub Pages
# Add serverless function: netlify/functions/verify.js
# Use SUPABASE_URL and SUPABASE_ANON_KEY env vars
# Update Supabase redirect URLs to new domain
```

**Why Migrate:**
- 🔐 **Security**: API keys hidden server-side
- 📊 **Analytics**: Better verification tracking  
- 🚀 **Performance**: Server-side processing
- 🛠️ **Debugging**: Server logs for failed verifications

## Environment Variables Needed

```env
SUPABASE_URL=https://soljnhiswixveasbjur.supabase.co
SUPABASE_ANON_KEY=eyJ...your_anon_key
```

## Supabase Configuration

**Authentication → URL Configuration:**
```
Site URL: https://username.github.io/farmcash-verify
Redirect URLs: https://username.github.io/farmcash-verify
```

## Installation & Setup

### V1 Quick Setup
1. Fork/clone this repository
2. Replace `YOUR_SUPABASE_ANON_KEY` in `index.html` with your actual key
3. Enable GitHub Pages in repository settings
4. Update Supabase redirect URLs to your GitHub Pages URL

### V2 Production Setup
1. Deploy repository to Netlify
2. Add environment variables in Netlify dashboard
3. Create `netlify/functions/verify.js` serverless function
4. Update Supabase redirect URLs to Netlify domain

## Contributing

This is a simple utility service for FarmCash development. Improvements welcome:
- Better error handling
- Styling improvements  
- Analytics integration
- Multi-language support

## License

Part of the FarmCash project ecosystem.

---

**Status:** ✅ V1 Working | 🟡 V2 Migration Planned  
**Part of:** FarmCash mobile rewards app development