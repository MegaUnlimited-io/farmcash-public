# FarmCash Public Web Application - Technical Documentation

**Repository:** `farmcash-public`  
**Version:** 1.0.0  
**Last Updated:** February 2026  
**Status:** Production (Waitlist Phase)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Database Schema](#database-schema)
4. [SQL Functions Reference](#sql-functions-reference)
5. [Authentication & User Flow](#authentication--user-flow)
6. [Referral System](#referral-system)
7. [Fraud Prevention](#fraud-prevention)
8. [Seed Economy](#seed-economy)
9. [Frontend Structure](#frontend-structure)
10. [Security](#security)
11. [Email Templates](#email-templates)
12. [Known Issues](#known-issues)
13. [Testing Checklist](#testing-checklist)
14. [Future Improvements](#future-improvements)
15. [Developer Guide](#developer-guide)

---

## Project Overview

### What Is This?

The FarmCash Public Web Application is a **waitlist signup and referral system** for the FarmCash mobile app. It serves as:

1. **Landing page** - Marketing site introducing FarmCash
2. **Waitlist signup** - Collects early users with gamified signup bonuses
3. **Referral system** - Viral growth mechanism with tiered rewards
4. **User dashboard** - Simple interface showing seed balance and referral link

### Why Does It Exist?

**Primary Goals:**
- **Pre-launch user acquisition** - Build audience before mobile app launch
- **Viral growth** - Referral system drives organic signups
- **Fraud detection** - Test anti-fraud systems before app release
- **Market validation** - Gauge interest and collect user preferences

**Secondary Goals:**
- **Email list building** - Verified emails for launch announcements
- **User segmentation** - Gaming preferences, device types, competitor usage
- **Brand awareness** - Establish FarmCash brand and positioning

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend** | Vanilla HTML/CSS/JS | Simple, fast, no build step |
| **Hosting** | GitHub Pages | Free, CDN, HTTPS |
| **Backend** | Supabase (PostgreSQL) | Auth, database, serverless functions |
| **Auth** | Supabase Auth + Magic Links | Passwordless, secure, low friction |
| **Bot Protection** | Cloudflare Turnstile | Invisible CAPTCHA, free tier |
| **Analytics** | Google Analytics 4 | User behavior tracking |

---

## Architecture

### System Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER JOURNEY                             │
└─────────────────────────────────────────────────────────────┘

1. DISCOVERY
   User lands on farmcash.app
   ↓
2. SIGNUP
   Fills form → Cloudflare Turnstile → Supabase Auth
   ↓
3. EMAIL VERIFICATION
   Clicks link → /verify/ → Awards seeds (100 + 50)
   ↓
4. DASHBOARD
   /referral/ → Shows balance + referral link
   ↓
5. REFERRAL (Optional)
   Shares link → Friend signs up → Referrer gets bonus

┌─────────────────────────────────────────────────────────────┐
│                   DATA FLOW                                 │
└─────────────────────────────────────────────────────────────┘

Client (Browser)
    ↓
[farmcash-auth.js]
    ↓ API Calls
Supabase (PostgreSQL)
    ├── auth.users (Supabase Auth)
    ├── public.users (User profiles)
    ├── waitlist_signups (Survey data)
    └── seed_transactions (Audit log)
    ↓ Database Functions
SQL Functions (SECURITY DEFINER)
    ├── process_email_verification()
    ├── award_signup_bonus()
    ├── award_verification_bonus()
    └── award_referral_bonus()
```

### Component Responsibilities

**Frontend (`/js/farmcash-auth.js`):**
- User authentication (signup, login, session management)
- Form validation and submission
- Fingerprint collection (IP, timezone, browser, OS)
- Referral code storage (localStorage)
- API calls to Supabase

**Backend (Supabase):**
- User authentication (magic links, email verification)
- Database operations (CRUD on users, waitlist, transactions)
- Business logic (seed awards, referral tracking, fraud checks)
- Row Level Security (RLS) enforcement

**Database Functions (PostgreSQL):**
- `process_email_verification()` - Orchestrates all verification bonuses
- `award_signup_bonus()` - Awards 100 seeds on signup
- `award_verification_bonus()` - Awards 50 seeds on email verify
- `award_referral_bonus()` - Awards 200/100/50 seeds to referrer
- `record_seed_transaction()` - Atomic balance update + audit log

---

## Database Schema

### Core Tables

#### **1. `auth.users` (Supabase Auth)**

**Purpose:** Managed by Supabase Auth, stores authentication credentials.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `email` | TEXT | User email (unique) |
| `email_confirmed_at` | TIMESTAMP | When email was verified |
| `created_at` | TIMESTAMP | Account creation time |

**Not directly modified** - Supabase handles this table.

---

#### **2. `public.users`**

**Purpose:** User profiles, balances, referral tracking.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | UUID | `auth.uid()` | Primary key, links to auth.users |
| `email` | TEXT | - | User email (denormalized for convenience) |
| `seeds_balance` | INTEGER | `0` | Current seed balance |
| `cash_balance` | DECIMAL(10,2) | `0.00` | Real cash balance (future) |
| `referral_code` | TEXT | - | User's unique 6-char referral code |
| `referred_by` | UUID | `NULL` | ID of user who referred them |
| `referral_count` | INTEGER | `0` | Number of successful referrals |
| `waitlist_bonus_claimed` | BOOLEAN | `false` | Prevents double-crediting signup bonus |
| `email_verified_bonus_claimed` | BOOLEAN | `false` | Prevents double-crediting verification bonus |
| `is_waitlist_user` | BOOLEAN | `false` | Distinguishes web vs app signups |
| `user_level` | INTEGER | `1` | User level (future gamification) |
| `total_harvests` | INTEGER | `0` | Lifetime harvests (app feature) |
| `experience_points` | INTEGER | `0` | XP for progression (future) |
| `water_balance` | INTEGER | `100` | Water resource (app feature) |
| `created_at` | TIMESTAMP | `now()` | Account creation time |

**Indexes:**
- Primary: `id`
- Unique: `referral_code`, `email`
- Index: `referred_by` (for referral lookups)

**RLS:** Currently **DISABLED** ⚠️ (see Known Issues)

---

#### **3. `waitlist_signups`**

**Purpose:** Survey data, fraud detection, waitlist management.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | FK to auth.users |
| `email` | TEXT | User email (denormalized) |
| `game_type` | TEXT | Favorite game type (puzzle, strategy, etc.) |
| `rewarded_apps` | TEXT[] | Previously used reward apps |
| `devices` | TEXT[] | Device types (android, ios) |
| `ip_address` | TEXT | IP at signup (fraud detection) |
| `timezone` | TEXT | Browser timezone |
| `browser` | TEXT | Browser name |
| `os` | TEXT | Operating system |
| `device_type` | TEXT | mobile/tablet/desktop |
| `fingerprint_hash` | TEXT | Hash of device fingerprint |
| `fraud_status` | TEXT | `pending`, `approved`, `suspicious`, `flagged`, `rejected` |
| `email_verified` | BOOLEAN | Email verification status |
| `email_verified_at` | TIMESTAMP | When email was verified |
| `referrer` | TEXT | HTTP referrer (where they came from) |
| `created_at` | TIMESTAMP | Signup timestamp |

**Indexes:**
- Primary: `id`
- Unique: `user_id`
- Index: `email`, `fraud_status`, `fingerprint_hash`

**RLS:** Currently **DISABLED** ⚠️

---

#### **4. `seed_transactions`**

**Purpose:** Immutable audit log of all seed balance changes.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | FK to public.users |
| `amount` | INTEGER | Seed amount (+/- integer) |
| `source` | TEXT | Transaction type (see below) |
| `reference` | TEXT | Specific transaction reference |
| `balance_after` | INTEGER | User's balance after this transaction |
| `metadata` | JSONB | Additional context (referee_id, etc.) |
| `xp_granted` | INTEGER | XP awarded (future) |
| `sequence` | SERIAL | Auto-incrementing sequence number |
| `created_at` | TIMESTAMP | Transaction timestamp |

**Transaction Sources:**

| Source | Reference | Amount | Description |
|--------|-----------|--------|-------------|
| `signup_bonus` | `waitlist_signup` | +100 | Waitlist signup reward |
| `email_verification` | `email_confirmed` | +50 | Email verification reward |
| `referral_reward` | `referral_1` | +200 | First referral bonus |
| `referral_reward` | `referral_2` | +100 | Second referral bonus |
| `referral_reward` | `referral_3` | +50 | Third referral bonus |
| `referral_reward` | `referral_4_unpaid` | 0 | 4+ referrals tracked but not paid |

**Indexes:**
- Primary: `id`
- Index: `user_id`, `source`, `created_at`

**RLS:** Currently **DISABLED** ⚠️

---

#### **5. `app_config`**

**Purpose:** Configurable game economics without code deployments.

| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `config_key` | TEXT | Setting name |
| `config_value` | TEXT | Setting value (stored as string) |
| `value_type` | TEXT | `integer`, `decimal`, `boolean` |
| `description` | TEXT | Human-readable description |
| `updated_by` | UUID | Who made the change |
| `updated_at` | TIMESTAMP | When updated |

**Current Configuration:**

| Key | Value | Description |
|-----|-------|-------------|
| `demo_seeds` | 0 | Starting seeds for FTUE (disabled for waitlist) |
| `email_bonus_seeds` | 50 | Email verification bonus |
| `waitlist_bonus_seeds` | 100 | Waitlist signup bonus |
| `referral_reward_1st` | 200 | 1st referral reward |
| `referral_reward_2nd` | 100 | 2nd referral reward |
| `referral_reward_3rd` | 50 | 3rd referral reward |
| `min_withdrawal_amount` | 10.00 | Minimum cashout |
| `seeds_to_dollar_rate` | 0.01 | Conversion rate (100 seeds = $1) |

---

### Database Relationships

```
auth.users (1) ──────────── (1) public.users
                                    │
                                    ├── (1) waitlist_signups
                                    │
                                    ├── (many) seed_transactions
                                    │
                                    └── (many) public.users [referred_by]
                                              (self-referential for referrals)
```

---

## SQL Functions Reference

All functions use `SECURITY DEFINER` to bypass Row Level Security and execute with elevated privileges.

### **1. `process_email_verification(p_user_id, p_referred_by)`**

**Purpose:** Orchestrates all email verification bonuses in one atomic transaction.

**Parameters:**
- `p_user_id` UUID - User being verified
- `p_referred_by` UUID (optional) - Referrer's user ID (not used, fetched from DB)

**Returns:** TABLE
- `success` BOOLEAN
- `total_seeds_awarded` INTEGER
- `breakdown` JSONB
- `message` TEXT

**Logic:**
1. Check flags (`waitlist_bonus_claimed`, `email_verified_bonus_claimed`)
2. If both claimed → return "welcome back" (login scenario)
3. Mark email as verified in `waitlist_signups`
4. Call `award_signup_bonus()` if not claimed
5. Call `award_verification_bonus()` if not claimed
6. Call `award_referral_bonus()` if user has referrer
7. Set both bonus flags to `true`
8. Return summary

**Idempotency:** Safe to call multiple times, won't double-credit.

---

### **2. `award_signup_bonus(p_user_id)`**

**Purpose:** Awards 100 seeds for waitlist signup.

**Parameters:**
- `p_user_id` UUID

**Returns:** TABLE
- `success` BOOLEAN
- `seeds_awarded` INTEGER
- `balance_after` INTEGER
- `message` TEXT

**Logic:**
1. Get bonus amount from `app_config` (default 100)
2. Check `seed_transactions` for existing `signup_bonus` record
3. If exists → return 0 seeds (already claimed)
4. Call `record_seed_transaction()` to award seeds
5. Return success

**Idempotency:** Checks transaction log, safe to retry.

---

### **3. `award_verification_bonus(p_user_id)`**

**Purpose:** Awards 50 seeds for email verification.

**Parameters:**
- `p_user_id` UUID

**Returns:** TABLE
- `success` BOOLEAN
- `seeds_awarded` INTEGER
- `balance_after` INTEGER
- `message` TEXT

**Logic:**
1. Get bonus amount from `app_config` (default 50)
2. Check `seed_transactions` for existing `email_verification` record
3. If exists → return 0 seeds
4. Call `record_seed_transaction()` to award seeds
5. Update `fraud_status` to `approved` if still `pending`
6. Return success

**Idempotency:** Checks transaction log.

**Note:** Removed `email_verified_at` check (was causing bugs).

---

### **4. `award_referral_bonus(p_referrer_id, p_referee_id)`**

**Purpose:** Awards tiered bonus to referrer when their referee verifies email.

**Parameters:**
- `p_referrer_id` UUID - User who referred
- `p_referee_id` UUID - User who was referred

**Returns:** TABLE
- `success` BOOLEAN
- `seeds_awarded` INTEGER
- `balance_after` INTEGER
- `referral_count` INTEGER
- `message` TEXT

**Logic:**
1. Increment referrer's `referral_count`
2. Check if bonus already awarded for this referee (idempotency)
3. Determine bonus: 1st=200, 2nd=100, 3rd=50, 4+=0
4. Call `record_seed_transaction()` with appropriate amount
5. Return success with bonus amount

**Referral Tiers:**

| Referral # | Seeds Awarded | Tracked? | Paid? |
|------------|---------------|----------|-------|
| 1 | 200 | ✅ | ✅ |
| 2 | 100 | ✅ | ✅ |
| 3 | 50 | ✅ | ✅ |
| 4+ | 0 | ✅ | ❌ |

**Metadata Stored:**
```json
{
  "awarded_at": "2026-02-15T10:30:00Z",
  "referee_id": "uuid-of-referee",
  "referral_number": 1,
  "bonus_amount": 200
}
```

---

### **5. `record_seed_transaction(p_user_id, p_amount, p_source, p_reference, p_metadata, p_xp_granted)`**

**Purpose:** Atomically updates user balance and creates audit log entry.

**Parameters:**
- `p_user_id` UUID
- `p_amount` INTEGER (can be negative)
- `p_source` TEXT (transaction type)
- `p_reference` TEXT (specific instance)
- `p_metadata` JSONB (optional, default `{}`)
- `p_xp_granted` INTEGER (optional, default `0`)

**Returns:** INTEGER (new balance)

**Logic:**
1. UPDATE `public.users` SET `seeds_balance = seeds_balance + p_amount`
2. INSERT into `seed_transactions` with all details
3. RETURN new balance

**Atomic:** Both operations succeed or both fail (transaction).

---

### **6. `update_user_seeds(p_user_id, p_amount, p_source, p_reference, p_metadata)`**

**Purpose:** Legacy function, use `record_seed_transaction()` instead.

**Status:** Deprecated but still exists for backwards compatibility.

---

## Authentication & User Flow

### Signup Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER LANDS ON HOMEPAGE (index.html)                     │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ┌─────────────────────────────────┐
         │ Referred?                       │
         └─────────────────────────────────┘
                    ↙                ↘
            YES (?ref=ABC123)       NO (direct)
                    ↓                    ↓
        Store ref code in       Continue to form
        localStorage
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. USER FILLS SIGNUP FORM                                   │
│    - Game type (dropdown)                                   │
│    - Rewarded apps used (checkboxes)                        │
│    - Devices (checkboxes)                                   │
│    - Email                                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. CLOUDFLARE TURNSTILE VERIFICATION                        │
│    - Invisible challenge (most users see nothing)           │
│    - Token generated and validated                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. CLIENT-SIDE VALIDATION                                   │
│    - Email format                                           │
│    - Disposable email check                                 │
│    - At least 1 rewarded app selected                       │
│    - At least 1 device selected                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. FINGERPRINT COLLECTION                                   │
│    - IP address (via ipify.org)                             │
│    - Timezone (Intl.DateTimeFormat)                         │
│    - Browser (User-Agent parsing)                           │
│    - OS (User-Agent parsing)                                │
│    - Device type (mobile/tablet/desktop)                    │
│    - Hash (simple hash for deduplication)                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. CREATE SUPABASE AUTH USER                                │
│    supabase.auth.signUp({ email, password: random })        │
│    - Creates entry in auth.users                            │
│    - Sends verification email                               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. CREATE USER PROFILE                                      │
│    createWaitlistUser(userId, email, survey, fingerprint)   │
│    - Generates unique 6-char referral code                  │
│    - Creates public.users record (seeds_balance = 0)        │
│    - Creates waitlist_signups record                        │
│    - Links referred_by if referral code present             │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ✅ "Check your email to verify your account!"
                    Coin rain animation 🪙
```

---

### Email Verification Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER CLICKS EMAIL LINK                                   │
│    https://farmcash.app/verify/?type=signup&access_token=...│
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. VERIFY PAGE LOADS (verify/index.html)                    │
│    - Extracts tokens from URL hash                          │
│    - Checks ?type parameter (signup vs login)               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. SET SESSION                                              │
│    supabase.auth.setSession({ access_token, refresh_token })│
│    - User is now logged in                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ┌─────────────────────────────────┐
         │ Check: type=signup or type=login? │
         └─────────────────────────────────┘
                    ↙                ↘
            SIGNUP                  LOGIN
                ↓                      ↓
┌─────────────────────────┐   ┌──────────────────┐
│ Check bonus flags       │   │ Just redirect    │
│ in public.users         │   │ to dashboard     │
└─────────────────────────┘   └──────────────────┘
         ↓                              ↓
  Both claimed?                  /referral/
         ↙    ↘
     YES      NO
      ↓        ↓
  Login   First-time
    ↓          ↓
/referral/  Award seeds
            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. AWARD SEEDS                                              │
│    processEmailVerification(userId, referrerId)             │
│    - Awards 100 (signup) + 50 (verification) = 150 seeds    │
│    - Awards referrer 200/100/50 based on count             │
│    - Creates 2-3 seed_transaction records                   │
│    - Sets waitlist_bonus_claimed = true                     │
│    - Sets email_verified_bonus_claimed = true               │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ✅ "Email Verified! You received 150 seeds!"
                    Coin rain animation 🪙
                           ↓
         Redirect to /referral/ (dashboard) after 3s
```

---

### Magic Link Login Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER CLICKS "LOG IN TO DASHBOARD"                        │
│    - Opens modal on index.html                              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. ENTER EMAIL & SUBMIT                                     │
│    sendMagicLink(email)                                     │
│    - supabase.auth.signInWithOtp({ email })                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ✅ "Magic link sent! Check your email."
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. USER CLICKS EMAIL LINK                                   │
│    https://farmcash.app/verify/?type=login&access_token=... │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. VERIFY PAGE DETECTS type=login                           │
│    - Sets session                                           │
│    - Shows "Welcome back!" (no seed award)                  │
│    - Redirects to /referral/ after 1.5s                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Referral System

### How It Works

**1. User Gets Referral Link:**
- After email verification, user lands on `/referral/` dashboard
- Dashboard displays: `https://farmcash.app/?ref=ABC123`
- Referral code is unique 6-character alphanumeric (A-Z, 2-9, no ambiguous chars)

**2. Referral Link Clicked:**
- New user clicks `https://farmcash.app/?ref=ABC123`
- JavaScript extracts `ref` parameter
- Stores in `localStorage` (persists across browser sessions)

**3. New User Signs Up:**
- Fills signup form
- JavaScript retrieves stored referral code
- Looks up referrer's user ID from `public.users.referral_code`
- Creates account with `referred_by` set to referrer's ID

**4. New User Verifies Email:**
- `process_email_verification()` function called
- Reads `referred_by` from user's record
- Awards new user: 100 + 50 = 150 seeds
- Awards referrer: 200/100/50 seeds (based on count)

**5. Referral Tracked:**
- Referrer's `referral_count` incremented
- Transaction logged in `seed_transactions` for both users
- Referral code cleared from localStorage

---

### Referral Code Generation

**Algorithm:**
```javascript
async function generateUniqueReferralCode(maxAttempts = 5) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No 0, O, 1, I, L
    
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        let code = '';
        for (let i = 0; i < 6; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        
        // Check database for collision
        const exists = await checkCodeExists(code);
        if (!exists) return code;
        
        console.warn(`Collision: ${code}, retrying...`);
    }
    
    throw new Error('Failed to generate unique code');
}
```

**Collision Probability:**
- Character set: 32 characters (26 letters + 6 numbers, minus ambiguous)
- Code length: 6 characters
- Total combinations: 32^6 = **1,073,741,824** (~1 billion)
- Expected collisions: Very rare (< 0.0001% for first 10,000 users)

---

### Reward Tiers

| Referral # | Seeds to Referrer | Referee Gets | Tracked in DB? |
|------------|-------------------|--------------|----------------|
| 1st | 200 | 150 (always) | Yes |
| 2nd | 100 | 150 (always) | Yes |
| 3rd | 50 | 150 (always) | Yes |
| 4th+ | 0 (tracked only) | 150 (always) | Yes (amount=0) |

**Why cap at 3?**
- Prevents abuse (fake accounts for unlimited seeds)
- Encourages genuine referrals (first 3 matter most)
- Still tracks 4+ for analytics (shows engaged users)
- Allows future rewards (e.g., badges, leaderboards)

---

### Referral Metadata

**In `seed_transactions.metadata`:**
```json
{
  "awarded_at": "2026-02-15T10:30:00Z",
  "referee_id": "9148ca00-783e-48d4-ab2d-c8a4fdf64d4b",
  "referral_number": 1,
  "bonus_amount": 200
}
```

**Allows:**
- Track who referred whom
- Audit referral bonuses
- Detect fraud patterns (multiple referrals from same IP)
- Build referral graphs

---

## Fraud Prevention

### Current Barriers (Implemented)

#### **Layer 1: Cloudflare Turnstile (Bot Protection)**

**What:** Invisible CAPTCHA that challenges bots.

**How It Works:**
1. JavaScript initializes Turnstile widget on page load
2. Widget runs invisible browser challenges (timing, mouse movement, etc.)
3. On form submit, JavaScript calls `turnstile.execute()`
4. Token generated and validated by Cloudflare servers
5. Form submission blocked if challenge fails

**Effectiveness:**
- Blocks: Simple bots, scripted signups, automated tools
- Bypassed by: Advanced bots, human fraud farms, residential proxies

**Configuration:**
- Mode: Invisible (no user interaction for legitimate users)
- Site Key: `0x4AAAAAACdO5PPgE1nOO6Xa`
- Rate Limit: Pre-clearance enabled (15 min cookie)

**Known Issue:** Console warnings visible but functionality works correctly.

---

#### **Layer 2: Email Verification**

**What:** Users must click link in email to activate account.

**Effectiveness:**
- Blocks: Fake emails, typos, bot signups without email access
- Requires: Real email address, inbox access

**Disposable Email Blocking:**
```javascript
const disposableDomains = [
    'tempmail.com', 'guerrillamail.com', '10minutemail.com',
    'throwaway.email', 'mailinator.com', 'maildrop.cc',
    'trashmail.com', 'temp-mail.org'
];
```

**Limitation:** List is not exhaustive, new disposable services appear constantly.

---

#### **Layer 3: Device Fingerprinting**

**What:** Collect browser/device characteristics for deduplication.

**Data Collected:**
- IP address (via ipify.org API)
- Timezone (browser setting)
- Browser name (User-Agent parsing)
- Operating system (User-Agent parsing)
- Device type (mobile/tablet/desktop)
- Fingerprint hash (simple hash of above)

**Purpose:**
- Detect duplicate signups from same device
- Identify IP address patterns (VPN, datacenter, etc.)
- Geographic validation (timezone vs IP location)

**Stored In:** `waitlist_signups` table

**Limitation:** 
- Basic fingerprinting only (5 fields)
- No canvas, WebGL, audio fingerprinting
- Easily spoofed by changing IP/browser

---

#### **Layer 4: Idempotency Checks**

**What:** Database-level duplicate prevention.

**Implementation:**
1. Check `seed_transactions` for existing records before awarding
2. Check flags (`waitlist_bonus_claimed`, `email_verified_bonus_claimed`)
3. Safe to retry operations without double-crediting

**Example:**
```sql
-- In award_signup_bonus()
SELECT EXISTS(
    SELECT 1 FROM seed_transactions
    WHERE user_id = p_user_id AND source = 'signup_bonus'
) INTO v_already_awarded;

IF v_already_awarded THEN
    RETURN 0; -- Already claimed
END IF;
```

---

#### **Layer 5: Referral Tracking**

**What:** Metadata in transactions tracks referee relationships.

**Fraud Detection Potential:**
- Multiple referrals from same IP
- Same fingerprint across referee accounts
- Temporal patterns (all referrals within 5 minutes)
- Geographic anomalies (referrals from different countries)

**Current:** Metadata logged but **not actively monitored**.

---

### Future Fraud Options (Not Implemented)

#### **Priority 1: IPQS Integration**

**Service:** IPQualityScore (ipqualityscore.com)

**What It Does:**
- Real-time IP reputation scoring
- VPN/proxy/datacenter detection
- Email reputation (spam traps, disposables, leaked credentials)
- Phone number validation (future)
- Abuse velocity (multiple signups from same IP)

**Cost:** $0.001 - $0.005 per check (~$1-5 per 1000 signups)

**Implementation:**
```javascript
async function checkIPQS(email, ip) {
    const response = await fetch(
        `https://ipqualityscore.com/api/json/email/${API_KEY}/${email}?ip=${ip}`
    );
    const data = await response.json();
    
    return {
        fraud_score: data.fraud_score, // 0-100
        disposable: data.disposable,
        vpn: data.vpn_detected,
        proxy: data.proxy_detected
    };
}
```

**When to Add:**
- After 100+ signups to validate baseline fraud rate
- If fraud rate exceeds 10%
- Before mobile app launch

---

#### **Priority 2: Enhanced Fingerprinting**

**Library:** FingerprintJS (fingerprintjs.com)

**What It Does:**
- Advanced browser fingerprinting (canvas, WebGL, audio)
- 99.5% accuracy for device identification
- Detects incognito mode, VM usage, spoofing attempts

**Cost:** Free tier (1000 requests/month), then $200/month

**When to Add:**
- If duplicate account fraud is >5%
- Before implementing KYC at cashout

---

#### **Priority 3: KYC Verification**

**Service:** Veriff or Persona

**What It Does:**
- Government ID verification
- Selfie + liveness check
- Address verification
- AML/sanctions screening

**Cost:** $1-2 per verification

**When to Add:**
- At first cashout (not signup)
- Prevents fraud while minimizing friction for honest users
- Standard in rewards/GPT apps

---

#### **Priority 4: Behavioral Analysis**

**What:** Machine learning on user behavior patterns.

**Signals:**
- Time to complete signup form (bots are faster)
- Mouse movement patterns (bots move linearly)
- Keystroke dynamics (human typing patterns)
- Session duration before signup
- Pages viewed, scroll depth

**Implementation:** Custom ML model or third-party (Sift, Castle)

**When to Add:** After 1000+ signups for training data

---

#### **Priority 5: Manual Review Queue**

**What:** Humans review suspicious signups.

**Triggers:**
- Fraud score >70
- Multiple signups from same IP within 1 hour
- VPN/proxy detected
- Disposable email variants
- Geographic anomalies (timezone mismatch)

**Process:**
1. Flag suspicious accounts
2. Hold seed credits in "pending" status
3. Human reviews (approve/reject)
4. Release seeds or ban account

**When to Add:** When fraud volume exceeds manual capacity (>10/day)

---

### Fraud Detection Queries

**Monitor fraud indicators:**

```sql
-- Duplicate IPs
SELECT 
    ip_address,
    COUNT(*) as signup_count,
    array_agg(email) as emails
FROM waitlist_signups
GROUP BY ip_address
HAVING COUNT(*) > 1
ORDER BY signup_count DESC;

-- Duplicate fingerprints
SELECT 
    fingerprint_hash,
    COUNT(*) as signup_count,
    array_agg(email) as emails
FROM waitlist_signups
GROUP BY fingerprint_hash
HAVING COUNT(*) > 1
ORDER BY signup_count DESC;

-- Unverified emails (potential abandonment or fraud)
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN email_verified THEN 1 END) as verified,
    ROUND(100.0 * COUNT(CASE WHEN email_verified THEN 1 END) / COUNT(*), 2) as verify_rate
FROM waitlist_signups;

-- Referral patterns
SELECT 
    u.email as referrer_email,
    u.referral_count,
    array_agg(wu.email) as referee_emails,
    array_agg(wu.ip_address) as referee_ips
FROM public.users u
JOIN public.users referee ON referee.referred_by = u.id
JOIN waitlist_signups wu ON wu.user_id = referee.id
WHERE u.referral_count > 0
GROUP BY u.id, u.email, u.referral_count
ORDER BY u.referral_count DESC;
```

---

## Seed Economy

### How Seeds Are Credited

**Seeds** are the virtual currency in FarmCash. Users earn seeds through:
1. Waitlist signup (100 seeds)
2. Email verification (50 seeds)
3. Referring friends (200/100/50 seeds)

**Future:** Seeds will be used to plant crops in the mobile app.

---

### Transaction Flow

```
User Action
    ↓
JavaScript (client)
    ↓ RPC Call
process_email_verification(user_id)
    ↓ Calls
award_signup_bonus(user_id)
    ↓ Calls
record_seed_transaction(user_id, +100, 'signup_bonus', ...)
    ↓ Atomic Transaction
UPDATE public.users SET seeds_balance = seeds_balance + 100
INSERT INTO seed_transactions (...)
    ↓
Return new balance
```

---

### Balance Integrity

**Guaranteed by:**
1. **Atomic transactions** - Balance update + audit log insert happen together or not at all
2. **Idempotency checks** - Duplicate awards blocked at function level
3. **Flag tracking** - `waitlist_bonus_claimed` and `email_verified_bonus_claimed` prevent re-entry
4. **Audit log** - Every balance change recorded in `seed_transactions`

**Verify balance integrity:**
```sql
-- Check if balance matches transaction sum
SELECT 
    u.id,
    u.email,
    u.seeds_balance as current_balance,
    COALESCE(SUM(st.amount), 0) as transaction_sum,
    u.seeds_balance - COALESCE(SUM(st.amount), 0) as discrepancy
FROM public.users u
LEFT JOIN seed_transactions st ON st.user_id = u.id
GROUP BY u.id, u.email, u.seeds_balance
HAVING u.seeds_balance != COALESCE(SUM(st.amount), 0);

-- Should return 0 rows if balances are correct
```

---

### Conversion Rate

**Seeds to USD:**
- 100 seeds = $1.00 USD
- Configurable in `app_config.seeds_to_dollar_rate`

**Not Yet Implemented:**
- Cashout functionality (planned for mobile app)
- Minimum withdrawal: $10 (1000 seeds)
- Payment methods: PayPal, gift cards

---

## Frontend Structure

### File Organization

```
/farmcash-public/
├── /assets/                     # Images, videos, fonts
│   ├── FarmCash_Logo_v1.png
│   ├── lp_background_2.png
│   ├── 3d-coin.webm            # Coin rain animation
│   └── [app store badges]
│
├── /includes/                   # Reusable HTML components
│   └── footer.html             # Shared footer
│
├── /js/                         # JavaScript modules
│   └── farmcash-auth.js        # Main auth + database utilities
│
├── /referral/                   # Dashboard page
│   └── index.html              # User dashboard (shows balance, referral link)
│
├── /verify/                     # Email verification page
│   └── index.html              # Handles email verification + seed awards
│
├── index.html                   # Landing page + signup form
├── 404.html                     # Custom 404 page
├── privacy.html                 # Privacy policy
├── terms.html                   # Terms of service
├── site.webmanifest            # PWA manifest
└── [favicon files]             # Favicon in multiple formats
```

---

### Key Frontend Files

#### **1. `index.html` (Landing Page)**

**Purpose:** Marketing landing page + waitlist signup.

**Sections:**
- Hero (logo, tagline, signup CTA)
- Signup form (game type, rewarded apps, devices, email)
- Referral progress visual (seed rewards breakdown)
- How it works (3-step explanation)
- Why FarmCash (gamified, transparent, early access)
- Login modal (magic link request)

**JavaScript Features:**
- Cloudflare Turnstile initialization
- Form validation (client-side)
- Fingerprint collection
- Referral code storage (localStorage)
- Supabase auth signup
- User profile creation
- Coin rain animation on success

**Auto-redirect:**
- If user is already logged in → `/referral/`

---

#### **2. `verify/index.html` (Email Verification)**

**Purpose:** Handle email verification links and award seeds.

**URL Parameters:**
- `?type=signup` - New user verification (awards seeds)
- `?type=login` - Returning user magic link (no seeds)

**Flow:**
1. Extract tokens from URL hash (`access_token`, `refresh_token`)
2. Set Supabase session
3. Check `?type` parameter
4. If `type=signup`:
   - Check bonus flags in database
   - Call `process_email_verification()` RPC
   - Show "Email Verified! 150 seeds" + coin rain
   - Redirect to `/referral/`
5. If `type=login`:
   - Show "Welcome back!"
   - Redirect to `/referral/` immediately

**Error Handling:**
- Invalid tokens → "Verification failed"
- Expired links → "Link expired, request new one"
- Network errors → Show error message + retry option

---

#### **3. `referral/index.html` (Dashboard)**

**Purpose:** User dashboard showing balance and referral link.

**Protected:** Requires authentication (redirects to `/?login=true` if not logged in)

**Displays:**
- User email
- Seed balance
- Referral code
- Referral link (copyable)
- Referral count
- Account creation date

**Features:**
- Copy referral link button
- Logout button
- Future: Transaction history, leaderboard, account settings

**Data Source:** `getUserDashboardData()` function in `farmcash-auth.js`

---

#### **4. `js/farmcash-auth.js` (Core Utilities)**

**Purpose:** Shared authentication and database functions.

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `getQuickFingerprint()` | Collect IP, timezone, browser, OS, device type |
| `checkAuth()` | Check if user is logged in |
| `signUpUser(email)` | Create Supabase auth user |
| `sendMagicLink(email)` | Send OTP login link |
| `signOut()` | Log out user |
| `createWaitlistUser()` | Create user profile + waitlist record |
| `generateUniqueReferralCode()` | Generate 6-char code with DB uniqueness check |
| `processEmailVerification()` | Call RPC to award seeds |
| `getUserDashboardData()` | Fetch user balance + referral info |
| `getReferralCode()` | Extract `?ref=` from URL |
| `getUserIdFromReferralCode()` | Database lookup |
| `storeReferralCode()` | Save to localStorage |
| `getStoredReferralCode()` | Retrieve from localStorage |
| `clearStoredReferralCode()` | Remove from localStorage |

**Global Scope:** Loaded as regular `<script>`, functions available everywhere.

---

## Security

### Current Security Posture

⚠️ **CRITICAL: Row Level Security (RLS) is DISABLED** ⚠️

**Tables Without RLS:**
- `public.users`
- `waitlist_signups`
- `seed_transactions`

**Risk:** Any authenticated user can theoretically query other users' data.

**Mitigation:** 
- Client-side code only queries own data
- JavaScript functions use `auth.uid()` to filter queries
- Database functions use `SECURITY DEFINER` to bypass RLS

**Before Public Launch:** RLS MUST be enabled (see Known Issues).

---

### Authentication Security

**Email Verification:**
- Required for account activation
- 24-hour token expiry
- One-time use tokens

**Magic Links:**
- 1-hour token expiry
- One-time use
- Email-based (no password storage)

**Sessions:**
- 30-day default (Supabase)
- Refresh token stored in localStorage
- Auto-refresh on page load

---

### API Security

**Supabase Anon Key:**
- Public key (safe to expose in client-side code)
- RLS enforces access control (when enabled)
- No server secrets in client code

**Database Functions:**
- `SECURITY DEFINER` - Execute with elevated privileges
- Bypass RLS (safe because internal logic controls access)
- Idempotency checks prevent abuse

---

### Input Validation

**Client-Side:**
- Email format regex
- Disposable email blacklist
- Form field requirements (at least 1 checkbox)
- Length limits (email max 254 chars)

**Server-Side:**
- Supabase validates email format
- PostgreSQL enforces data types
- Unique constraints on `referral_code`, `email`

**Not Yet Implemented:**
- SQL injection protection (Supabase handles via parameterized queries)
- XSS protection (minimal user input, no innerHTML rendering)

---

### Cloudflare Turnstile

**Configuration:**
- Mode: Invisible (no user interaction)
- Pre-clearance: Yes (15-minute cookie)
- Rate limiting: Cloudflare-managed

**Security Benefits:**
- Blocks automated bots
- Detects headless browsers
- Challenge-response for suspicious traffic

**Limitations:**
- Bypassed by advanced bots
- Console warnings (cosmetic, not functional issue)

---

## Email Templates

### Confirm Signup (New User Verification)

**Subject:** 🎉 Claim your 150 seeds! Verify your FarmCash account

**Template:**
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to FarmCash</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
    
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" style="max-width: 500px; width: 100%; border-collapse: collapse; background-color: #ffffff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                    
                    <!-- Header -->
                    <tr>
                        <td style="padding: 40px 40px 20px 40px; text-align: center;">
                            <h1 style="margin: 0 0 10px 0; color: #2E7D32; font-size: 28px; font-weight: 700;">
                                🌱 FarmCash
                            </h1>
                            <p style="margin: 0; color: #666666; font-size: 16px;">
                                Start earning rewards for playing games
                            </p>
                        </td>
                    </tr>
                    
                    <tr>
                        <td style="padding: 0 40px;">
                            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 0;">
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 30px 40px 20px 40px;">
                            <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 20px; font-weight: 600;">
                                Welcome to FarmCash! 🎉
                            </h2>
                            <p style="margin: 0 0 20px 0; color: #555555; font-size: 16px; line-height: 1.6;">
                                Thanks for signing up! Click the button below to verify your email and start earning seeds for every game you play.
                            </p>
                            
                            <!-- CTA Button -->
                            <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                <tr>
                                    <td align="center" style="padding: 10px 0 30px 0;">
                                        <a href="{{ .ConfirmationURL }}?type=signup" style="display: inline-block; padding: 16px 40px; background-color: #4CAF50; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: 600; border-radius: 8px;">
                                            Verify Email ✉️
                                        </a>
                                    </td>
                                </tr>
                            </table>
                            
                            <!-- Fallback Link -->
                            <p style="margin: 0 0 10px 0; color: #888888; font-size: 14px;">
                                Button not working? Copy and paste this link:
                            </p>
                            <p style="margin: 0; color: #4CAF50; font-size: 13px; word-break: break-all;">
                                {{ .ConfirmationURL }}?type=signup
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Expiration Notice -->
                    <tr>
                        <td style="padding: 0 40px 20px 40px;">
                            <p style="margin: 0; color: #999999; font-size: 13px; text-align: center;">
                                ⏰ This link expires in 24 hours
                            </p>
                        </td>
                    </tr>
                    
                    <tr>
                        <td style="padding: 0 40px;">
                            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 0;">
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 30px 40px; text-align: center;">
                            <p style="margin: 0 0 10px 0; color: #999999; font-size: 13px;">
                                Didn't sign up for FarmCash?
                            </p>
                            <p style="margin: 0; color: #999999; font-size: 13px;">
                                You can safely ignore this email.
                            </p>
                        </td>
                    </tr>
                    
                </table>
                
                <table role="presentation" style="max-width: 500px; width: 100%; border-collapse: collapse; margin-top: 20px;">
                    <tr>
                        <td style="padding: 0; text-align: center;">
                            <p style="margin: 0; color: #999999; font-size: 12px;">
                                © 2025 FarmCash. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
                
            </td>
        </tr>
    </table>
    
</body>
</html>
```

**Key Element:** `{{ .ConfirmationURL }}?type=signup`

---

### Magic Link (Returning User Login)

**Subject:** 🔒 Your secure login link for FarmCash

**Template:**
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log in to FarmCash</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
    
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" style="max-width: 500px; width: 100%; border-collapse: collapse; background-color: #ffffff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                    
                    <!-- Header -->
                    <tr>
                        <td style="padding: 40px 40px 20px 40px; text-align: center;">
                            <h1 style="margin: 0 0 10px 0; color: #2E7D32; font-size: 28px; font-weight: 700;">
                                🌱 FarmCash
                            </h1>
                            <p style="margin: 0; color: #666666; font-size: 16px;">
                                Your gateway to earning rewards
                            </p>
                        </td>
                    </tr>
                    
                    <tr>
                        <td style="padding: 0 40px;">
                            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 0;">
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 30px 40px 20px 40px;">
                            <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 20px; font-weight: 600;">
                                Log in to FarmCash 🔐
                            </h2>
                            <p style="margin: 0 0 20px 0; color: #555555; font-size: 16px; line-height: 1.6;">
                                We received a request to log in to your account. Click the button below to access your dashboard.
                            </p>
                            
                            <!-- CTA Button -->
                            <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                <tr>
                                    <td align="center" style="padding: 10px 0 30px 0;">
                                        <a href="{{ .ConfirmationURL }}?type=login" style="display: inline-block; padding: 16px 40px; background-color: #4CAF50; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: 600; border-radius: 8px;">
                                            Log In 🚀
                                        </a>
                                    </td>
                                </tr>
                            </table>
                            
                            <!-- Fallback Link -->
                            <p style="margin: 0 0 10px 0; color: #888888; font-size: 14px;">
                                Button not working? Copy and paste this link:
                            </p>
                            <p style="margin: 0; color: #4CAF50; font-size: 13px; word-break: break-all;">
                                {{ .ConfirmationURL }}?type=login
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Expiration Notice -->
                    <tr>
                        <td style="padding: 0 40px 20px 40px;">
                            <p style="margin: 0; color: #999999; font-size: 13px; text-align: center;">
                                ⏰ This link expires in 1 hour
                            </p>
                        </td>
                    </tr>
                    
                    <tr>
                        <td style="padding: 0 40px;">
                            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 0;">
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 30px 40px; text-align: center;">
                            <p style="margin: 0 0 10px 0; color: #999999; font-size: 13px;">
                                Didn't request this magic link?
                            </p>
                            <p style="margin: 0; color: #999999; font-size: 13px;">
                                You can safely ignore this email. Your account is secure.
                            </p>
                        </td>
                    </tr>
                    
                </table>
                
                <table role="presentation" style="max-width: 500px; width: 100%; border-collapse: collapse; margin-top: 20px;">
                    <tr>
                        <td style="padding: 0; text-align: center;">
                            <p style="margin: 0; color: #999999; font-size: 12px;">
                                © 2025 FarmCash. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
                
            </td>
        </tr>
    </table>
    
</body>
</html>
```

**Key Element:** `{{ .ConfirmationURL }}?type=login`

---

## Known Issues

### 1. Cross-App User Confusion (HIGH PRIORITY)

**Problem:** Users who sign up in the mobile app cannot log into the web dashboard.

**Symptoms:**
- User verifies email via mobile app
- Tries to log into web dashboard with magic link
- `/referral/` page loads but shows error: `"Cannot coerce the result to a single JSON object"`
- Dashboard fails to load user data

**Root Cause:**
- Mobile app creates user without `is_waitlist_user` flag
- Dashboard query expects `waitlist_signups` record
- Query uses `.single()` which fails if record doesn't exist

**Workaround:** None for users (they're stuck)

**Proposed Fix:**
```javascript
// In getUserDashboardData(), change from:
const { data: waitlistData, error: waitlistError } = await supabaseClient
    .from('waitlist_signups')
    .select('email_verified, created_at')
    .eq('user_id', userId)
    .single(); // ❌ Fails if no record

// To:
const { data: waitlistData } = await supabaseClient
    .from('waitlist_signups')
    .select('email_verified, created_at')
    .eq('user_id', userId)
    .maybeSingle(); // ✅ Returns null if no record

// Then handle null case:
return { 
    success: true, 
    data: {
        ...userData,
        email_verified: waitlistData?.email_verified ?? true,
        created_at: waitlistData?.created_at ?? userData.created_at
    }
};
```

**Impact:** Affects all mobile app users trying to access web dashboard.

**Priority:** **HIGH** - Breaks cross-platform experience.

---

### 2. Row Level Security Disabled (CRITICAL)

**Problem:** RLS is disabled on all core tables.

**Risk:**
- Any authenticated user can theoretically query other users' data
- Malicious user could read balances, emails, referral codes
- Potential data leak if client code is modified

**Tables Affected:**
- `public.users`
- `waitlist_signups`
- `seed_transactions`

**Why Disabled:** Debugging during development, never re-enabled.

**Required Policies (Before Public Launch):**

```sql
-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE waitlist_signups ENABLE ROW LEVEL SECURITY;
ALTER TABLE seed_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view only their own record
CREATE POLICY "Users view own record" ON public.users
FOR SELECT TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users insert own record" ON public.users
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users update own record" ON public.users
FOR UPDATE TO authenticated
USING (auth.uid() = id);

-- Service role bypasses RLS (for functions)
CREATE POLICY "Service role full access" ON public.users
TO service_role
USING (true) WITH CHECK (true);

-- Repeat for waitlist_signups and seed_transactions
```

**Testing After Enable:**
```sql
-- Should work (own data)
SELECT * FROM public.users WHERE id = auth.uid();

-- Should return empty (other user's data)
SELECT * FROM public.users WHERE email = 'other@user.com';
```

**Impact:** Major security vulnerability if not fixed before launch.

**Priority:** **CRITICAL** - Must fix before any public announcement.

---

### 3. Terms Acceptance Not Stored

**Problem:** Signup form has "I accept terms" checkbox, but acceptance is not stored in database.

**Current State:**
- Checkbox is required for form submission (client-side validation)
- Not stored in `public.users` or `waitlist_signups`

**Proposed Solution:**
1. Add column: `ALTER TABLE waitlist_signups ADD COLUMN terms_accepted BOOLEAN DEFAULT false;`
2. Update JavaScript to send checkbox value
3. Store `terms_accepted` and `terms_accepted_at` timestamp

**Legal Risk:** Cannot prove user accepted terms if dispute arises.

**Priority:** **MEDIUM** - Important for legal compliance, not blocking.

---

### 4. Cloudflare Turnstile Console Warnings

**Problem:** Console shows warnings/errors from Turnstile script.

**Symptoms:**
- "Request for the Private Access Token challenge"
- "401 Unauthorized" for PAT challenge
- "Resource preloaded but not used"
- CSP warnings

**Impact:** **None** - Turnstile functions correctly despite warnings.

**Root Cause:**
- Cloudflare testing advanced features (Private Access Tokens)
- Browser doesn't support new features yet
- Falls back to standard challenge successfully

**Proposed Fix:** None needed (cosmetic issue only).

**Priority:** **LOW** - Annoying but not functional problem.

---

### 5. Duplicate `record_seed_transaction` Function

**Problem:** Two versions of same function exist in database.

**Why:** Function was updated during development, old version not dropped.

**Impact:** **None** - PostgreSQL uses most recent definition.

**Fix:**
```sql
-- Check function signatures
SELECT routine_name, specific_name, routine_definition
FROM information_schema.routines
WHERE routine_name = 'record_seed_transaction';

-- Drop old version (identify by specific_name)
DROP FUNCTION IF EXISTS record_seed_transaction(uuid, integer, text, text, jsonb);
```

**Priority:** **LOW** - Cleanup only, no functional impact.

---

## Testing Checklist

### Core Flows (Must Test Before Launch)

- [ ] **Fresh signup** (never used email)
  - [ ] Form validation works (missing fields)
  - [ ] Disposable email blocked
  - [ ] Turnstile challenge completes
  - [ ] Account created successfully
  - [ ] Verification email received
  - [ ] Email link contains `?type=signup`
  
- [ ] **Email verification (new user)**
  - [ ] Link opens `/verify/` page
  - [ ] Session established
  - [ ] Seeds awarded (100 + 50 = 150)
  - [ ] Two transactions in `seed_transactions`
  - [ ] Flags set (`waitlist_bonus_claimed`, `email_verified_bonus_claimed`)
  - [ ] Coin rain animation plays
  - [ ] Redirect to `/referral/` after 3s
  
- [ ] **Dashboard loads**
  - [ ] User email displayed
  - [ ] Seed balance shows 150
  - [ ] Referral code displayed
  - [ ] Referral link copyable
  - [ ] Copy button works
  
- [ ] **Referral flow**
  - [ ] Copy referral link
  - [ ] Open incognito window
  - [ ] Paste referral link
  - [ ] `?ref=` parameter in URL
  - [ ] Sign up with different email
  - [ ] New user gets 150 seeds
  - [ ] Referrer gets +200 seeds (total 350)
  - [ ] Referrer's `referral_count` incremented
  - [ ] Both users have correct `seed_transactions`
  
- [ ] **Magic link login**
  - [ ] Click "Log in to dashboard"
  - [ ] Modal opens
  - [ ] Enter email, submit
  - [ ] "Magic link sent" message
  - [ ] Email received with `?type=login`
  - [ ] Click link → verify page
  - [ ] "Welcome back!" (no seed award)
  - [ ] Redirect to dashboard immediately
  
- [ ] **Double-click protection**
  - [ ] Verify email (get 150 seeds)
  - [ ] Click verification link again
  - [ ] "Welcome back!" (no additional seeds)
  - [ ] Balance still 150 (not 300)
  
- [ ] **Logout & re-login**
  - [ ] Logout from dashboard
  - [ ] Redirect to homepage
  - [ ] Request magic link
  - [ ] Login successfully
  - [ ] Dashboard loads correctly

---

### Security & Fraud (Before Public Launch)

- [ ] **RLS enabled and tested**
  - [ ] All three tables have RLS enabled
  - [ ] Policies created for authenticated users
  - [ ] Service role can still execute functions
  - [ ] Users cannot query other users' data
  
- [ ] **Turnstile active**
  - [ ] Widget initializes on page load
  - [ ] Challenge completes on form submit
  - [ ] Form blocked if challenge fails
  
- [ ] **Fingerprinting working**
  - [ ] IP address collected
  - [ ] Timezone, browser, OS detected
  - [ ] Fingerprint hash generated
  - [ ] Data stored in `waitlist_signups`
  
- [ ] **Disposable email blocking**
  - [ ] Test with `test@tempmail.com`
  - [ ] Blocked with error message
  
- [ ] **Referral fraud detection**
  - [ ] Multiple signups from same IP tracked
  - [ ] Referee metadata includes `referee_id`
  - [ ] Can query duplicate fingerprints

---

### Edge Cases (Should Test)

- [ ] **Expired verification link**
  - [ ] Use link older than 24 hours
  - [ ] Shows "Link expired" error
  - [ ] Option to request new link
  
- [ ] **Invalid referral code**
  - [ ] Signup with `?ref=INVALID`
  - [ ] Signup proceeds (invalid ref ignored)
  - [ ] No referrer linked in database
  
- [ ] **Already verified user**
  - [ ] User clicks old signup link
  - [ ] Treated as login (no seeds)
  - [ ] Dashboard loads normally
  
- [ ] **Mobile app user logs in**
  - [ ] ⚠️ CURRENTLY BROKEN (see Known Issues #1)
  - [ ] Should work after fix applied

---

### Database Integrity (Periodic Checks)

- [ ] **Balance = sum of transactions**
  ```sql
  SELECT * FROM public.users u
  LEFT JOIN (SELECT user_id, SUM(amount) as tx_sum FROM seed_transactions GROUP BY user_id) t
  ON u.id = t.user_id
  WHERE u.seeds_balance != COALESCE(t.tx_sum, 0);
  ```
  - [ ] Should return 0 rows
  
- [ ] **All verified users have 150+ seeds**
  ```sql
  SELECT * FROM public.users
  WHERE email_verified_bonus_claimed = true
  AND seeds_balance < 150;
  ```
  - [ ] Should return 0 rows (unless referrer with 0 referrals)
  
- [ ] **Referral counts match transactions**
  ```sql
  SELECT u.id, u.referral_count, COUNT(st.id) as tx_count
  FROM public.users u
  LEFT JOIN seed_transactions st ON st.user_id = u.id AND st.source = 'referral_reward'
  WHERE u.referral_count != COALESCE(COUNT(st.id), 0)
  GROUP BY u.id, u.referral_count;
  ```
  - [ ] Should return 0 rows

---

## Future Improvements

### High Priority (Next 30 Days)

1. **Fix Cross-App User Experience**
   - [ ] Update `getUserDashboardData()` to handle missing `waitlist_signups`
   - [ ] Test mobile app users logging into web dashboard
   - [ ] Add `is_waitlist_user` flag to distinguish sources
   
2. **Enable Row Level Security**
   - [ ] Create RLS policies for all tables
   - [ ] Test with multiple users
   - [ ] Verify functions still work with `SECURITY DEFINER`
   - [ ] Document RLS policies
   
3. **Store Terms Acceptance**
   - [ ] Add `terms_accepted` column to `waitlist_signups`
   - [ ] Update JavaScript to send checkbox value
   - [ ] Add `terms_accepted_at` timestamp
   - [ ] Update privacy policy link
   
4. **IPQS Integration (Fraud Prevention)**
   - [ ] Sign up for IPQS account
   - [ ] Add API key to environment
   - [ ] Call IPQS on signup (email + IP check)
   - [ ] Store fraud score in `waitlist_signups`
   - [ ] Block signups with score >85

---

### Medium Priority (Next 60 Days)

5. **Transaction History UI**
   - [ ] Add "History" tab to dashboard
   - [ ] Display `seed_transactions` in table
   - [ ] Show source, amount, timestamp
   - [ ] Paginate for users with many transactions
   
6. **Referral Leaderboard**
   - [ ] Public leaderboard page
   - [ ] Top 10 referrers by count
   - [ ] Anonymize or use usernames (not emails)
   - [ ] Monthly reset option
   
7. **Enhanced Fingerprinting**
   - [ ] Integrate FingerprintJS
   - [ ] Collect canvas, WebGL, audio fingerprints
   - [ ] Detect incognito mode
   - [ ] Flag suspicious devices
   
8. **Admin Dashboard**
   - [ ] Internal tool to view signups
   - [ ] Flag/unflag fraud accounts
   - [ ] Manually adjust seed balances
   - [ ] Export data to CSV
   
9. **Email Improvements**
   - [ ] Welcome email series (drip campaign)
   - [ ] Weekly update on referral progress
   - [ ] Remind unverified users after 24 hours
   - [ ] Pre-launch countdown emails

---

### Low Priority (Future)

10. **Social Proof**
    - [ ] Display signup count on homepage
    - [ ] Show recent signups (anonymized)
    - [ ] Country/region distribution
    
11. **A/B Testing**
    - [ ] Test different reward amounts
    - [ ] Test signup form variations
    - [ ] Track conversion rates
    
12. **Internationalization**
    - [ ] Translate to Spanish, Portuguese, French
    - [ ] Detect browser language
    - [ ] Localize currency (seeds still universal)
    
13. **SEO Optimization**
    - [ ] Meta tags for social sharing
    - [ ] OpenGraph images
    - [ ] Sitemap generation
    - [ ] Blog content for organic traffic
    
14. **Performance**
    - [ ] Lazy load images
    - [ ] Minify CSS/JS
    - [ ] CDN for assets
    - [ ] Service worker for offline support

---

## Developer Guide

### Local Development Setup

**Prerequisites:**
- Git
- Modern browser (Chrome, Firefox, Safari)
- Text editor (VS Code recommended)

**Steps:**

1. **Clone repository**
   ```bash
   git clone https://github.com/yourusername/farmcash-public.git
   cd farmcash-public
   ```

2. **Update Supabase credentials**
   
   Edit `js/farmcash-auth.js`:
   ```javascript
   const SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
   ```

3. **Update Cloudflare Turnstile key**
   
   Edit `index.html` (search for `sitekey:`):
   ```javascript
   turnstile.render('#cf-turnstile', {
       sitekey: 'YOUR_TURNSTILE_SITE_KEY',
       // ...
   });
   ```

4. **Run local server**
   
   Python 3:
   ```bash
   python -m http.server 8000
   ```
   
   Or Node.js:
   ```bash
   npx http-server -p 8000
   ```

5. **Open browser**
   ```
   http://localhost:8000
   ```

**Note:** Supabase redirect URLs must include `http://localhost:8000/verify/` for local testing.

---

### Deployment (GitHub Pages)

**Steps:**

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Update X"
   git push origin main
   ```

2. **Enable GitHub Pages**
   - Go to repository Settings → Pages
   - Source: Deploy from branch `main`
   - Folder: `/ (root)`
   - Save

3. **Custom domain (optional)**
   - Add CNAME file with `farmcash.app`
   - Configure DNS:
     - A record: `185.199.108.153`
     - A record: `185.199.109.153`
     - A record: `185.199.110.153`
     - A record: `185.199.111.153`
     - CNAME `www` → `yourusername.github.io`

4. **Update Supabase redirect URLs**
   - Add `https://farmcash.app/verify/` to allowed redirect URLs
   - Remove localhost if deploying to production

**Deploy time:** 1-2 minutes after push.

---

### Database Migrations

**Adding a new bonus type:**

1. **Add config value**
   ```sql
   INSERT INTO app_config (config_key, config_value, value_type, description)
   VALUES ('new_bonus_seeds', '25', 'integer', 'Description of bonus');
   ```

2. **Create award function**
   ```sql
   CREATE OR REPLACE FUNCTION award_new_bonus(p_user_id UUID)
   RETURNS TABLE(...) AS $$
   DECLARE
       v_bonus_amount INTEGER;
       v_new_balance INTEGER;
   BEGIN
       -- Get config
       SELECT COALESCE(
           (SELECT config_value::integer FROM app_config WHERE config_key = 'new_bonus_seeds'),
           25
       ) INTO v_bonus_amount;
       
       -- Award seeds
       v_new_balance := record_seed_transaction(
           p_user_id,
           v_bonus_amount,
           'new_bonus',
           'specific_reference',
           jsonb_build_object('awarded_at', now())
       );
       
       RETURN QUERY SELECT true, v_bonus_amount, v_new_balance, 'Success message'::TEXT;
   END;
   $$ LANGUAGE plpgsql SECURITY DEFINER;
   ```

3. **Update frontend to call function**
   ```javascript
   const { data, error } = await supabaseClient.rpc('award_new_bonus', {
       p_user_id: userId
   });
   ```

---

### Troubleshooting

**Problem: "Cannot coerce the result to a single JSON object"**

**Cause:** Query expects 1 row but got 0 or multiple.

**Fix:** Use `.maybeSingle()` instead of `.single()`.

---

**Problem: Seeds not awarded after verification**

**Check:**
1. Are bonus flags already true? (Query `public.users`)
2. Does `seed_transactions` have records?
3. Check RPC call logs in browser console
4. Test function manually in Supabase SQL Editor

---

**Problem: Turnstile not loading**

**Check:**
1. Is script tag in `<head>`?
2. Correct site key?
3. Domain whitelisted in Cloudflare dashboard?
4. Console errors?

---

**Problem: Referral link not working**

**Check:**
1. Is `?ref=` parameter in URL?
2. Is code stored in localStorage? (Check DevTools → Application → Local Storage)
3. Does `getUserIdFromReferralCode()` return valid UUID?
4. Is `referred_by` set in `public.users`?

---

### Useful SQL Queries

**View all users:**
```sql
SELECT 
    u.email,
    u.seeds_balance,
    u.referral_code,
    u.referral_count,
    u.email_verified_bonus_claimed,
    w.email_verified,
    w.created_at
FROM public.users u
LEFT JOIN waitlist_signups w ON w.user_id = u.id
ORDER BY u.created_at DESC
LIMIT 20;
```

**Check seed transaction log:**
```sql
SELECT 
    u.email,
    st.amount,
    st.source,
    st.reference,
    st.balance_after,
    st.created_at
FROM seed_transactions st
JOIN public.users u ON u.id = st.user_id
ORDER BY st.created_at DESC
LIMIT 50;
```

**Find users who haven't verified:**
```sql
SELECT email, created_at
FROM waitlist_signups
WHERE email_verified = false
AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

**Referral analytics:**
```sql
SELECT 
    u.email as referrer,
    u.referral_count,
    SUM(st.amount) as total_earned
FROM public.users u
JOIN seed_transactions st ON st.user_id = u.id AND st.source = 'referral_reward'
WHERE u.referral_count > 0
GROUP BY u.id, u.email, u.referral_count
ORDER BY u.referral_count DESC;
```

---

## Environment Variables

**Required:**

| Variable | Location | Value |
|----------|----------|-------|
| `SUPABASE_URL` | `js/farmcash-auth.js` | `https://[project].supabase.co` |
| `SUPABASE_ANON_KEY` | `js/farmcash-auth.js` | `eyJhb...` (public anon key) |
| `TURNSTILE_SITE_KEY` | `index.html` | `0x4AAAAAACdO5PPgE1nOO6Xa` |

**Optional:**
- None currently (IPQS will require API key when implemented)

**Security Notes:**
- Anon key is safe to expose (RLS controls access)
- Turnstile site key is public (secret key stays on Cloudflare)
- No server secrets in client-side code

---

## Support & Contact

**Product Owner:** Malcolm Lowry  
**Company:** Mega Unlimited LTD  
**Email:** malcolm@megaunlimited.io  
**Website:** https://farmcash.app

**For Issues:**
- GitHub Issues (if public repo)
- Email for urgent/security issues

**For Users:**
- In-app support (future)
- Email: support@farmcash.app (future)

---

## Changelog

**v1.0.0 - February 2026**
- Initial waitlist launch
- Signup + referral system
- Email verification
- Seed economy (100 signup + 50 verification + 200/100/50 referral)
- Cloudflare Turnstile bot protection
- Dashboard with referral link

**Known Issues This Version:**
- RLS disabled (MUST fix before public launch)
- Cross-app user experience broken
- Terms acceptance not stored
- Turnstile console warnings (cosmetic only)

---

## License

**Proprietary - All Rights Reserved**

© 2025 Mega Unlimited LTD. This software and documentation are proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.

---

**END OF DOCUMENTATION**

*Last Updated: February 16, 2026*  
*Version: 1.0.0*  
*Status: Production - Waitlist Phase*