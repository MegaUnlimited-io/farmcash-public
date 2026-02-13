# FarmCash - Complete Public Schema Documentation v3.0

## Document Overview

**Created:** February 10, 2026  
**Last Updated:** February 12, 2026  
**Author:** Malcolm  
**Version:** 3.0  
**Purpose:** Complete and accurate documentation of ALL public schema tables, functions, and views  
**Status:** Source of Truth - Based on actual database with MIGRATION005 & MIGRATION006  
**Scope:** All tables, functions, triggers, and views in public schema

---

## ⚠️ IMPORTANT NOTES

- **This document reflects the ACTUAL schema** including all migrations through February 12, 2026
- All table names, column names, data types, and defaults are exact matches
- Use this as the authoritative reference when writing code
- Last verified: February 12, 2026
- Includes referral system (MIGRATION005) and waitlist rewards system (MIGRATION006)

---

## Table of Contents

1. [Core User & Game Tables](#core-user--game-tables)
   - [public.users](#publicusers)
   - [public.user_farms](#publicuser_farms)
   - [public.crop_types](#publiccrop_types)
   - [public.crops](#publiccrops)
   - [public.harvest_history](#publicharvest_history)
   
2. [Transaction & Economy Tables](#transaction--economy-tables)
   - [public.seed_transactions](#publicseed_transactions)
   - [public.postback_log](#publicpostback_log)
   - [public.postback_deduplication](#publicpostback_deduplication)
   
3. [Referral & Waitlist Tables](#referral--waitlist-tables)
   - [public.referrals](#publicreferrals)
   - [public.waitlist_signups](#publicwaitlist_signups)
   
4. [Security & Fraud Tables](#security--fraud-tables)
   - [public.fraud_events](#publicfraud_events)
   
5. [Feature & Feedback Tables](#feature--feedback-tables)
   - [public.feature_requests](#publicfeature_requests)
   - [public.feature_votes](#publicfeature_votes)
   - [public.awaiting_feature_requests](#publicawaiting_feature_requests)
   
6. [System & Configuration Tables](#system--configuration-tables)
   - [public.app_config](#publicapp_config)
   - [public.user_infos](#publicuser_infos)
   - [public.devices](#publicdevices)
   - [public.notifications](#publicnotifications)
   - [public.subscriptions](#publicsubscriptions)

7. [Functions & Stored Procedures](#functions--stored-procedures)
   - [User Management Functions](#user-management-functions)
   - [Referral Functions](#referral-functions)
   - [Reward Functions](#reward-functions)
   - [Fraud Detection Functions](#fraud-detection-functions)

8. [Views & Analytics](#views--analytics)
   - [top_referrers](#top_referrers-view)
   - [referral_stats](#referral_stats-view)

9. [Triggers](#triggers)
   - [on_user_referral_signup](#on_user_referral_signup-trigger)

10. [Migration History](#migration-history)

---

# Core User & Game Tables

## public.users

### **Purpose**
Core user profile table containing account information, game progression, virtual currency balances, and referral tracking.

### **Complete Schema**

```sql
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamp with time zone NOT NULL DEFAULT now(),
  last_update_date timestamp without time zone,
  name character varying,
  email character varying,
  avatar_url text,
  onboarded boolean NOT NULL DEFAULT false,
  seeds_balance integer DEFAULT 100,
  cash_balance numeric DEFAULT 0.00,
  user_level integer DEFAULT 1,
  total_harvests integer DEFAULT 0,
  experience_points integer DEFAULT 0,
  water_balance integer DEFAULT 100,
  locale text DEFAULT 'en'::text,
  
  -- Referral System (MIGRATION005)
  referral_code text UNIQUE,
  referred_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  referral_count integer DEFAULT 0,
  is_waitlist_user boolean DEFAULT false,
  waitlist_bonus_claimed boolean DEFAULT false,
  
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | Primary key, should match auth.users.id |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | `now()` | Account creation timestamp |
| `last_update_date` | TIMESTAMP WITHOUT TIME ZONE | NULL | - | Last modification timestamp |
| `name` | CHARACTER VARYING | NULL | - | Display name |
| `email` | CHARACTER VARYING | NULL | - | Email (duplicates auth.users.email) |
| `avatar_url` | TEXT | NULL | - | Profile picture URL |
| `onboarded` | BOOLEAN | NOT NULL | `false` | FTUE completion status |
| `seeds_balance` | INTEGER | NULL | `100` | Virtual currency for planting |
| `cash_balance` | NUMERIC | NULL | `0.00` | Real money earned |
| `user_level` | INTEGER | NULL | `1` | Progression level |
| `total_harvests` | INTEGER | NULL | `0` | Lifetime harvest count |
| `experience_points` | INTEGER | NULL | `0` | XP for leveling |
| `water_balance` | INTEGER | NULL | `100` | Watering resource (0-999) |
| `locale` | TEXT | NULL | `'en'` | Language preference |
| `referral_code` | TEXT | NULL | Auto-generated | Unique 8-char referral code |
| `referred_by` | UUID | NULL | - | User who referred this user |
| `referral_count` | INTEGER | NULL | `0` | Number of successful referrals |
| `is_waitlist_user` | BOOLEAN | NULL | `false` | Whether user joined via waitlist |
| `waitlist_bonus_claimed` | BOOLEAN | NULL | `false` | Whether waitlist bonus was claimed |

### **Indexes**
- `idx_users_referral_code` on `referral_code`
- `idx_users_referred_by` on `referred_by`
- `idx_users_is_waitlist` on `is_waitlist_user`
- `idx_users_referral_count` on `referral_count` WHERE `referral_count > 0`

### **Relationships**
- **Self-referencing:** `referred_by` → `users(id)` (for referral chain)
- **Referenced by:** user_farms, devices, notifications, seed_transactions, feature_votes, awaiting_feature_requests, referrals, waitlist_signups

### **Related Functions**
- `handle_new_user()` - Auto-generates referral code on signup
- `credit_referrer()` - Auto-credits referrer when new user signs up
- `claim_waitlist_bonus()` - Awards bonus to waitlist users
- `get_user_referral_info()` - Returns complete referral information

---

## public.user_farms

### **Purpose**
Stores individual farm instances. Each user has exactly one farm (one-to-one relationship).

### **Complete Schema**

```sql
CREATE TABLE public.user_farms (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  farm_name character varying DEFAULT 'My Farm'::character varying,
  max_plots integer DEFAULT 15,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_farms_pkey PRIMARY KEY (id),
  CONSTRAINT user_farms_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Farm identifier |
| `user_id` | UUID | NOT NULL | - | UNIQUE, FK → auth.users(id) | Owner of this farm |
| `farm_name` | CHARACTER VARYING | NULL | `'My Farm'` | - | Customizable farm name |
| `max_plots` | INTEGER | NULL | `15` | - | Number of available plots |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Farm creation time |
| `updated_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Last update time |

### **Relationships**
- **References:** auth.users(id)
- **Referenced by:** crops, harvest_history

### **Important Notes**
- One user = one farm (enforced by UNIQUE constraint on user_id)
- Waitlist users won't have a farm until they open the app

---

## public.crop_types

### **Purpose**
Master data table defining the 4 crop varieties and their properties (tomato, eggplant, corn, golden melon).

### **Complete Schema**

```sql
CREATE TABLE public.crop_types (
  id integer NOT NULL DEFAULT nextval('crop_types_id_seq'::regclass),
  name character varying NOT NULL UNIQUE,
  display_name character varying NOT NULL,
  growth_time_hours integer NOT NULL,
  base_yield_percentage integer NOT NULL,
  seed_cost integer NOT NULL,
  emoji character varying,
  unlock_level integer DEFAULT 1,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT crop_types_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | INTEGER | NOT NULL | `nextval(...)` | PRIMARY KEY | Crop type ID |
| `name` | CHARACTER VARYING | NOT NULL | - | UNIQUE | Internal name (e.g., 'tomato') |
| `display_name` | CHARACTER VARYING | NOT NULL | - | - | User-facing name (e.g., 'Tomato') |
| `growth_time_hours` | INTEGER | NOT NULL | - | - | Hours until harvest (4, 24, 168, 720) |
| `base_yield_percentage` | INTEGER | NOT NULL | - | - | Base yield (75, 100, 115, 130) |
| `seed_cost` | INTEGER | NOT NULL | - | - | Seeds required to plant |
| `emoji` | CHARACTER VARYING | NULL | - | - | Display emoji (🍅, 🍆, 🌽, 🈀) |
| `unlock_level` | INTEGER | NULL | `1` | - | User level required |
| `active` | BOOLEAN | NULL | `true` | - | Whether crop is available |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Record creation time |
| `updated_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Last update time |

### **Relationships**
- **Referenced by:** crops, harvest_history

### **Initial Data (4 Crops)**
- Tomato: 4h, 75%, 25 seeds, 🍅
- Eggplant: 24h, 100%, 50 seeds, 🍆
- Corn: 7d (168h), 115%, 100 seeds, 🌽
- Golden Melon: 30d (720h), 130%, 200 seeds, 🈀

---

## public.crops

### **Purpose**
Active growing crops on user farms. Each record represents one crop instance.

### **Complete Schema**

```sql
CREATE TABLE public.crops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_farm_id uuid NOT NULL,
  crop_type_id integer NOT NULL,
  plot_position integer NOT NULL CHECK (plot_position >= 0 AND plot_position < 50),
  planted_at timestamp with time zone DEFAULT now(),
  harvest_ready_at timestamp with time zone NOT NULL,
  harvested_at timestamp with time zone,
  seeds_invested integer NOT NULL CHECK (seeds_invested > 0),
  yield_multiplier numeric DEFAULT 1.0 CHECK (yield_multiplier > 0::numeric),
  final_cash_value numeric,
  status character varying DEFAULT 'growing'::character varying 
    CHECK (status::text = ANY (ARRAY['growing'::character varying, 'ready'::character varying, 'harvested'::character varying]::text[])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT crops_pkey PRIMARY KEY (id),
  CONSTRAINT crops_user_farm_id_fkey FOREIGN KEY (user_farm_id) REFERENCES public.user_farms(id),
  CONSTRAINT crops_crop_type_id_fkey FOREIGN KEY (crop_type_id) REFERENCES public.crop_types(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Crop instance ID |
| `user_farm_id` | UUID | NOT NULL | - | FK → user_farms(id) | Which farm owns this |
| `crop_type_id` | INTEGER | NOT NULL | - | FK → crop_types(id) | Which crop variety |
| `plot_position` | INTEGER | NOT NULL | - | 0-49 | Plot index on farm |
| `planted_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | When planted |
| `harvest_ready_at` | TIMESTAMP WITH TIME ZONE | NOT NULL | - | - | When harvestable |
| `harvested_at` | TIMESTAMP WITH TIME ZONE | NULL | - | - | When harvested (NULL = growing) |
| `seeds_invested` | INTEGER | NOT NULL | - | > 0 | Seeds used to plant |
| `yield_multiplier` | NUMERIC | NULL | `1.0` | > 0 | Yield modifier (watering bonus) |
| `final_cash_value` | NUMERIC | NULL | - | - | Cash earned at harvest |
| `status` | CHARACTER VARYING | NULL | `'growing'` | Enum: growing/ready/harvested | Current status |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Record creation |
| `updated_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Last update |

### **Relationships**
- **References:** user_farms(id), crop_types(id)

### **Important Notes**
- `plot_position` allows up to 50 plots (expansion from default 15)
- `status` auto-updates when `harvest_ready_at` passes
- One crop per plot when actively growing

---

## public.harvest_history

### **Purpose**
Immutable audit log of all successful harvests. Used for analytics and user progress tracking.

### **Complete Schema**

```sql
CREATE TABLE public.harvest_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_farm_id uuid NOT NULL,
  crop_type_id integer NOT NULL,
  seeds_invested integer NOT NULL,
  cash_earned numeric NOT NULL,
  growth_time_actual interval NOT NULL,
  yield_percentage integer NOT NULL,
  plot_position integer NOT NULL,
  harvested_at timestamp with time zone DEFAULT now(),
  user_level_at_harvest integer,
  total_harvests_before integer,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT harvest_history_pkey PRIMARY KEY (id),
  CONSTRAINT harvest_history_user_farm_id_fkey FOREIGN KEY (user_farm_id) REFERENCES public.user_farms(id),
  CONSTRAINT harvest_history_crop_type_id_fkey FOREIGN KEY (crop_type_id) REFERENCES public.crop_types(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | Harvest record ID |
| `user_farm_id` | UUID | NOT NULL | - | Which farm harvested |
| `crop_type_id` | INTEGER | NOT NULL | - | Which crop was harvested |
| `seeds_invested` | INTEGER | NOT NULL | - | Seeds used for this crop |
| `cash_earned` | NUMERIC | NOT NULL | - | Cash from this harvest |
| `growth_time_actual` | INTERVAL | NOT NULL | - | Actual time from plant to harvest |
| `yield_percentage` | INTEGER | NOT NULL | - | Final yield with bonuses |
| `plot_position` | INTEGER | NOT NULL | - | Which plot was used |
| `harvested_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | When harvested |
| `user_level_at_harvest` | INTEGER | NULL | - | User's level when harvested |
| `total_harvests_before` | INTEGER | NULL | - | User's harvest count before this |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | Record creation |

### **Relationships**
- **References:** user_farms(id), crop_types(id)

### **Important Notes**
- INSERT only (no updates/deletes)
- Rich analytics data for behavioral analysis
- Tracks user progression context

---

# Transaction & Economy Tables

## public.seed_transactions

### **Purpose**
Audit log of all seed balance changes. Tracks source and amount of every seed transaction.

### **Complete Schema**

```sql
CREATE TABLE public.seed_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  amount integer NOT NULL,
  source character varying NOT NULL,
  reference character varying,
  balance_after integer NOT NULL,
  metadata jsonb,
  sequence bigint NOT NULL DEFAULT nextval('seed_transactions_sequence_seq'::regclass),
  CONSTRAINT seed_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT seed_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Transaction ID |
| `user_id` | UUID | NOT NULL | - | FK → auth.users(id) | User who received/spent seeds |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | Transaction timestamp |
| `amount` | INTEGER | NOT NULL | - | - | Seeds added/removed (can be negative) |
| `source` | CHARACTER VARYING | NOT NULL | - | - | Where seeds came from |
| `reference` | CHARACTER VARYING | NULL | - | - | External reference (offer ID, etc.) |
| `balance_after` | INTEGER | NOT NULL | - | - | Seed balance after transaction |
| `metadata` | JSONB | NULL | - | - | Additional transaction data |
| `sequence` | BIGINT | NOT NULL | `nextval(...)` | - | Sequential order (for reconciliation) |

### **Relationships**
- **References:** auth.users(id)

### **Common Sources**
- `'signup_bonus'` - Initial seeds from waitlist signup
- `'email_verification'` - Email verification bonus
- `'referral_reward'` - Referral bonus for referrer
- `'offer_completion'` - Completed partner offer
- `'planting'` - Seeds spent on crop (negative)
- `'admin_adjustment'` - Manual correction

### **Related Functions**
- `record_seed_transaction()` - Generic transaction recording function

---

## public.postback_log

### **Purpose**
Logs all postback callbacks from partner networks (AyeT, RevU, Prodege). Tracks offer completions and reversals.

### **Complete Schema**

```sql
CREATE TABLE public.postback_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  partner character varying NOT NULL,
  action_id character varying NOT NULL,
  user_id uuid,
  offer_id character varying,
  offer_name text,
  currency_amount integer NOT NULL,
  status character varying NOT NULL 
    CHECK (status::text = ANY (ARRAY['completed'::character varying, 'reversed'::character varying]::text[])),
  commission numeric,
  processed_at timestamp with time zone DEFAULT now(),
  response_code integer,
  response_body text,
  raw_params jsonb,
  duplicate_attempts integer DEFAULT 0,
  last_duplicate_at timestamp with time zone,
  CONSTRAINT postback_log_pkey PRIMARY KEY (id),
  CONSTRAINT postback_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Log entry ID |
| `partner` | CHARACTER VARYING | NOT NULL | - | - | Network name (AyeT, RevU, etc.) |
| `action_id` | CHARACTER VARYING | NOT NULL | - | - | Partner's unique action ID |
| `user_id` | UUID | NULL | - | FK → auth.users(id) | User who completed offer |
| `offer_id` | CHARACTER VARYING | NULL | - | - | Partner's offer ID |
| `offer_name` | TEXT | NULL | - | - | Offer description |
| `currency_amount` | INTEGER | NOT NULL | - | - | Seeds to credit |
| `status` | CHARACTER VARYING | NOT NULL | - | Enum: completed/reversed | Completion or reversal |
| `commission` | NUMERIC | NULL | - | - | Our revenue from this action |
| `processed_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | When postback received |
| `response_code` | INTEGER | NULL | - | - | HTTP response code sent back |
| `response_body` | TEXT | NULL | - | - | Response we sent |
| `raw_params` | JSONB | NULL | - | - | Full postback payload |
| `duplicate_attempts` | INTEGER | NULL | `0` | - | How many times this was retried |
| `last_duplicate_at` | TIMESTAMP WITH TIME ZONE | NULL | - | - | Last duplicate attempt time |

### **Relationships**
- **References:** auth.users(id)

### **Important Notes**
- `status = 'reversed'` → clawback seeds from user
- Used for fraud detection and revenue tracking

---

## public.postback_deduplication

### **Purpose**
Prevents duplicate postback processing. Stores unique partner+action_id combinations.

### **Complete Schema**

```sql
CREATE TABLE public.postback_deduplication (
  partner character varying NOT NULL,
  action_id character varying NOT NULL,
  processed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT postback_deduplication_pkey PRIMARY KEY (partner, action_id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `partner` | CHARACTER VARYING | NOT NULL | - | PRIMARY KEY (composite) | Network name |
| `action_id` | CHARACTER VARYING | NOT NULL | - | PRIMARY KEY (composite) | Partner's action ID |
| `processed_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | First processing time |

### **Important Notes**
- Composite primary key ensures uniqueness
- Check this table before processing postbacks

---

# Referral & Waitlist Tables

## public.referrals

### **Purpose**
Audit log of all referral events and seed rewards. Created in MIGRATION005.

### **Complete Schema**

```sql
CREATE TABLE public.referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  seeds_awarded integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(referrer_id, referee_id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Referral record ID |
| `referrer_id` | UUID | NOT NULL | - | FK → users(id), UNIQUE (composite) | User who referred |
| `referee_id` | UUID | NOT NULL | - | FK → users(id), UNIQUE (composite) | User who was referred |
| `seeds_awarded` | INTEGER | NOT NULL | - | - | Seeds awarded to referrer |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | When referral occurred |

### **Indexes**
- `idx_referrals_referrer` on `referrer_id`
- `idx_referrals_referee` on `referee_id`
- `idx_referrals_created` on `created_at`

### **Relationships**
- **References:** users(id) for both referrer and referee

### **Row Level Security**
- Users can view referrals where they are either referrer or referee

### **Important Notes**
- Unique constraint prevents duplicate referrals
- Used by `credit_referrer()` function to log referral events
- Seed amounts: 1st referral = 200, 2nd = 100, 3rd = 50, 4th+ = 0 (tracked but unpaid)

### **Related Functions**
- `credit_referrer()` - Auto-credits referrer on new signup
- `award_referral_bonus()` - Awards referral rewards
- `get_user_referral_info()` - Retrieves referral history

---

## public.waitlist_signups

### **Purpose**
Tracks web waitlist signups with survey answers and fraud detection data. Created in MIGRATION006.

### **Complete Schema**

```sql
CREATE TABLE public.waitlist_signups (
  -- Core Identity
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  email text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  
  -- Survey Answers
  game_type text,
  rewarded_apps text[],
  devices text[],
  
  -- Fraud Detection
  ip_address text,
  timezone text,
  browser text,
  os text,
  device_type text,
  fingerprint_hash text,
  fraud_status text DEFAULT 'pending' CHECK (
    fraud_status IN ('pending', 'approved', 'suspicious', 'flagged', 'rejected')
  ),
  
  -- Status Tracking
  email_verified boolean DEFAULT false,
  email_verified_at timestamptz,
  migrated_to_app boolean DEFAULT false,
  migrated_at timestamptz,
  
  -- Marketing
  referrer text,
  utm_source text,
  utm_medium text,
  utm_campaign text
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | Waitlist signup ID |
| `user_id` | UUID | NOT NULL | - | Auth user ID (unique) |
| `email` | TEXT | NOT NULL | - | Email address (unique) |
| `created_at` | TIMESTAMPTZ | NOT NULL | `now()` | Signup timestamp |
| `game_type` | TEXT | NULL | - | Survey: preferred game type |
| `rewarded_apps` | TEXT[] | NULL | - | Survey: apps they've used |
| `devices` | TEXT[] | NULL | - | Survey: device types |
| `ip_address` | TEXT | NULL | - | Signup IP address |
| `timezone` | TEXT | NULL | - | Browser timezone |
| `browser` | TEXT | NULL | - | Browser user agent |
| `os` | TEXT | NULL | - | Operating system |
| `device_type` | TEXT | NULL | - | Device type (mobile/desktop) |
| `fingerprint_hash` | TEXT | NULL | - | Hash for duplicate detection |
| `fraud_status` | TEXT | NULL | `'pending'` | Fraud check status |
| `email_verified` | BOOLEAN | NULL | `false` | Email confirmed flag |
| `email_verified_at` | TIMESTAMPTZ | NULL | - | Verification timestamp |
| `migrated_to_app` | BOOLEAN | NULL | `false` | Whether user opened app |
| `migrated_at` | TIMESTAMPTZ | NULL | - | App migration timestamp |
| `referrer` | TEXT | NULL | - | HTTP referrer |
| `utm_source` | TEXT | NULL | - | Marketing source |
| `utm_medium` | TEXT | NULL | - | Marketing medium |
| `utm_campaign` | TEXT | NULL | - | Marketing campaign |

### **Indexes**
- `idx_waitlist_user_id` on `user_id`
- `idx_waitlist_email` on `email`
- `idx_waitlist_fingerprint` on `fingerprint_hash`
- `idx_waitlist_ip` on `ip_address`
- `idx_waitlist_created` on `created_at DESC`
- `idx_waitlist_fraud_status` on `fraud_status`
- `idx_waitlist_verified` on `email_verified`

### **Relationships**
- **References:** auth.users(id)

### **Row Level Security**
- Users can view/insert/update only their own waitlist data

### **Fraud Status Values**
- `pending` - New signup, not yet reviewed
- `approved` - Email verified, clean signals
- `suspicious` - Auto-flagged by system
- `flagged` - Admin review required
- `rejected` - Blocked from platform

### **Related Functions**
- `process_email_verification()` - Orchestrates all verification rewards
- `award_signup_bonus()` - Awards initial 100 seeds
- `award_verification_bonus()` - Awards 50 seeds for email verification
- `check_fraud_signals()` - Placeholder for IPQS integration

---

# Security & Fraud Tables

## public.fraud_events

### **Purpose**
Logs detected fraud events for review and pattern analysis.

### **Complete Schema**

```sql
CREATE TABLE public.fraud_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  event_type character varying NOT NULL,
  severity character varying NOT NULL 
    CHECK (severity::text = ANY (ARRAY['LOW'::character varying, 'MEDIUM'::character varying, 'HIGH'::character varying, 'CRITICAL'::character varying]::text[])),
  details jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  reviewed boolean DEFAULT false,
  reviewed_at timestamp with time zone,
  reviewed_by uuid,
  resolution text,
  ip_address text,
  CONSTRAINT fraud_events_pkey PRIMARY KEY (id),
  CONSTRAINT fraud_events_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Event ID |
| `user_id` | UUID | NULL | - | - | User who triggered event |
| `event_type` | CHARACTER VARYING | NOT NULL | - | - | Type of fraud detected |
| `severity` | CHARACTER VARYING | NOT NULL | - | Enum: LOW/MEDIUM/HIGH/CRITICAL | Severity level |
| `details` | JSONB | NOT NULL | - | - | Event details and context |
| `created_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | When detected |
| `reviewed` | BOOLEAN | NULL | `false` | - | Admin reviewed flag |
| `reviewed_at` | TIMESTAMP WITH TIME ZONE | NULL | - | - | Review timestamp |
| `reviewed_by` | UUID | NULL | - | FK → auth.users(id) | Admin who reviewed |
| `resolution` | TEXT | NULL | - | - | Action taken |
| `ip_address` | TEXT | NULL | - | - | User's IP |

### **Relationships**
- **References:** auth.users(id) for reviewed_by

### **Event Types**
- `'vpn_detected'`
- `'geo_mismatch'`
- `'velocity_abuse'`
- `'multi_accounting'`
- `'suspicious_offer_pattern'`
- `'duplicate_fingerprint'`
- `'disposable_email'`

---

# Feature & Feedback Tables

## public.feature_requests

### **Purpose**
User-submitted feature requests with voting system.

### **Complete Schema**

```sql
CREATE TABLE public.feature_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamp with time zone NOT NULL DEFAULT now(),
  last_update_date timestamp with time zone NOT NULL DEFAULT now(),
  title jsonb NOT NULL,
  description jsonb NOT NULL,
  votes smallint NOT NULL,
  active boolean NOT NULL,
  CONSTRAINT feature_requests_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | Feature request ID |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | `now()` | When created |
| `last_update_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | `now()` | Last update |
| `title` | JSONB | NOT NULL | - | Localized title |
| `description` | JSONB | NOT NULL | - | Localized description |
| `votes` | SMALLINT | NOT NULL | - | Total vote count |
| `active` | BOOLEAN | NOT NULL | - | Still accepting votes |

### **Important Notes**
- Title and description are JSONB for multi-language support
- Votes are denormalized (updated when feature_votes added)

---

## public.feature_votes

### **Purpose**
Individual votes on feature requests (many-to-many).

### **Complete Schema**

```sql
CREATE TABLE public.feature_votes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamp with time zone NOT NULL DEFAULT now(),
  user_uid uuid NOT NULL,
  feature_id uuid NOT NULL,
  CONSTRAINT feature_votes_pkey PRIMARY KEY (id),
  CONSTRAINT user_uid_fkey FOREIGN KEY (user_uid) REFERENCES auth.users(id),
  CONSTRAINT feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.feature_requests(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Vote ID |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | `now()` | - | When voted |
| `user_uid` | UUID | NOT NULL | - | FK → auth.users(id) | Who voted |
| `feature_id` | UUID | NOT NULL | - | FK → feature_requests(id) | What they voted for |

### **Relationships**
- **References:** auth.users(id), feature_requests(id)

---

## public.awaiting_feature_requests

### **Purpose**
Feature requests pending admin approval before becoming public.

### **Complete Schema**

```sql
CREATE TABLE public.awaiting_feature_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamp with time zone NOT NULL DEFAULT now(),
  title text NOT NULL,
  description text NOT NULL,
  user_uid uuid NOT NULL,
  CONSTRAINT awaiting_feature_requests_pkey PRIMARY KEY (id),
  CONSTRAINT user_uid_fkey FOREIGN KEY (user_uid) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Request ID |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | `now()` | - | When submitted |
| `title` | TEXT | NOT NULL | - | - | Request title |
| `description` | TEXT | NOT NULL | - | - | Request description |
| `user_uid` | UUID | NOT NULL | - | FK → auth.users(id) | Who submitted |

### **Relationships**
- **References:** auth.users(id)

---

# System & Configuration Tables

## public.app_config

### **Purpose**
Global app configuration (economics, settings). Admin-configurable without code changes.

### **Complete Schema**

```sql
CREATE TABLE public.app_config (
  id integer NOT NULL DEFAULT nextval('app_config_id_seq'::regclass),
  config_key character varying NOT NULL UNIQUE,
  config_value text NOT NULL,
  value_type character varying DEFAULT 'string'::character varying,
  description text,
  updated_by uuid,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT app_config_pkey PRIMARY KEY (id),
  CONSTRAINT app_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | INTEGER | NOT NULL | `nextval(...)` | PRIMARY KEY | Config entry ID |
| `config_key` | CHARACTER VARYING | NOT NULL | - | UNIQUE | Setting identifier |
| `config_value` | TEXT | NOT NULL | - | - | Value (stored as string) |
| `value_type` | CHARACTER VARYING | NULL | `'string'` | - | Data type hint |
| `description` | TEXT | NULL | - | - | Human-readable description |
| `updated_by` | UUID | NULL | - | FK → auth.users(id) | Who changed it last |
| `updated_at` | TIMESTAMP WITH TIME ZONE | NULL | `now()` | - | When changed |

### **Relationships**
- **References:** auth.users(id) for updated_by

### **Current Config Keys (MIGRATION005 & MIGRATION006)**

#### Referral System (MIGRATION005)
- `referral_reward_1st` = 200 (seeds for 1st referral)
- `referral_reward_2nd` = 100 (seeds for 2nd referral)
- `referral_reward_3rd` = 50 (seeds for 3rd referral)
- `referral_reward_ongoing` = 25 (seeds for 4th+ referrals)
- `waitlist_bonus_seeds` = 100 (bonus for waitlist users on app launch)
- `referral_link_bonus` = 50 (seeds for getting referral link)

#### Waitlist Rewards (MIGRATION006)
- `signup_bonus_seeds` = 100 (initial signup bonus)
- `email_verification_bonus_seeds` = 50 (email confirmation bonus)

#### Other Settings
- `demo_seeds` = 100
- `min_withdrawal_amount` = 10.00
- `max_plots_default` = 15

---

## public.user_infos

### **Purpose**
Flexible key-value storage for user-specific metadata.

### **Complete Schema**

```sql
CREATE TABLE public.user_infos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  info_key text NOT NULL,
  info_value text NOT NULL,
  CONSTRAINT user_infos_pkey PRIMARY KEY (id),
  CONSTRAINT user_infos_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Info entry ID |
| `user_id` | UUID | NOT NULL | - | FK → auth.users(id) | User this info belongs to |
| `info_key` | TEXT | NOT NULL | - | - | Key name |
| `info_value` | TEXT | NOT NULL | - | - | Value |

### **Relationships**
- **References:** auth.users(id)

### **Usage Examples**
- Survey answers: `info_key = 'survey_game_type'`
- Preferences: `info_key = 'notification_preference'`

---

## public.devices

### **Purpose**
Tracks user devices for push notifications and multi-device support.

### **Complete Schema**

```sql
CREATE TABLE public.devices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  creation_date timestamp with time zone NOT NULL,
  last_update_date timestamp with time zone NOT NULL,
  installation_id text NOT NULL,
  token text NOT NULL,
  operatingSystem text NOT NULL,
  CONSTRAINT devices_pkey PRIMARY KEY (id),
  CONSTRAINT devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Device ID |
| `user_id` | UUID | NOT NULL | - | FK → auth.users(id) | Device owner |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | - | - | First seen |
| `last_update_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | - | - | Last active |
| `installation_id` | TEXT | NOT NULL | - | - | App installation ID |
| `token` | TEXT | NOT NULL | - | - | Push notification token |
| `operatingSystem` | TEXT | NOT NULL | - | - | OS (iOS/Android) |

### **Relationships**
- **References:** auth.users(id)

---

## public.notifications

### **Purpose**
In-app notifications and push notification log.

### **Complete Schema**

```sql
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb,
  type text,
  creation_date timestamp with time zone NOT NULL,
  read_date timestamp with time zone,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Notification ID |
| `user_id` | UUID | NOT NULL | - | FK → auth.users(id) | Recipient |
| `title` | TEXT | NOT NULL | - | - | Notification title |
| `body` | TEXT | NOT NULL | - | - | Notification body |
| `data` | JSONB | NULL | - | - | Additional payload |
| `type` | TEXT | NULL | - | - | Notification type |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | - | - | When created |
| `read_date` | TIMESTAMP WITH TIME ZONE | NULL | - | - | When read (NULL = unread) |

### **Relationships**
- **References:** auth.users(id)

---

## public.subscriptions

### **Purpose**
In-app purchase subscriptions tracking.

### **Complete Schema**

```sql
CREATE TABLE public.subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamp with time zone NOT NULL DEFAULT now(),
  sku_id text NOT NULL,
  last_update_date timestamp with time zone NOT NULL,
  period_end_date timestamp with time zone,
  user_id uuid,
  store USER-DEFINED,
  status USER-DEFINED NOT NULL,
  CONSTRAINT subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

### **Column Reference**

| Column | Type | Nullable | Default | Constraints | Description |
|--------|------|----------|---------|-------------|-------------|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | PRIMARY KEY | Subscription ID |
| `creation_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | `now()` | - | When purchased |
| `sku_id` | TEXT | NOT NULL | - | - | Product SKU |
| `last_update_date` | TIMESTAMP WITH TIME ZONE | NOT NULL | - | - | Last status check |
| `period_end_date` | TIMESTAMP WITH TIME ZONE | NULL | - | - | Subscription end date |
| `user_id` | UUID | NULL | - | FK → auth.users(id) | Subscriber |
| `store` | USER-DEFINED | NULL | - | - | App Store / Play Store |
| `status` | USER-DEFINED | NOT NULL | - | - | Active/Expired/Cancelled |

### **Relationships**
- **References:** auth.users(id)

### **Important Notes**
- `USER-DEFINED` types are custom enums (not shown in export)
- Track premium subscriptions for ad-free, boosted earnings, etc.

---

# Functions & Stored Procedures

## User Management Functions

### handle_new_user()

**Purpose:** Auto-creates user profile and generates referral code when new user signs up via Supabase Auth.

**Trigger:** AFTER INSERT on `auth.users`

**Changes in MIGRATION005:**
- Now generates unique 8-character referral code
- Handles `is_waitlist_user` flag from user metadata
- Retry logic for referral code collisions (max 5 attempts)

**Returns:** Trigger (NEW)

**Usage:** Automatic - fires on auth signup

```sql
-- Called automatically when user signs up
-- No manual invocation needed
```

---

## Referral Functions

### credit_referrer()

**Purpose:** Automatically credits seeds to referrer when a new user signs up with a referral link.

**Created:** MIGRATION005

**Trigger:** AFTER INSERT on `public.users` (via `on_user_referral_signup` trigger)

**Logic:**
1. Check if new user has `referred_by` set
2. Determine seed reward based on referrer's current `referral_count`:
   - 1st referral: 200 seeds
   - 2nd referral: 100 seeds
   - 3rd referral: 50 seeds
   - 4th+ referrals: 25 seeds
3. Credit seeds using `update_user_seeds()`
4. Increment referrer's `referral_count`
5. Log event in `public.referrals` table

**Returns:** Trigger (NEW)

**Security:** SECURITY DEFINER

**Usage:** Automatic - fires when new user has referral

---

### claim_waitlist_bonus()

**Purpose:** Awards one-time bonus to waitlist users when they first open the app.

**Created:** MIGRATION005

**Parameters:**
- `p_user_id` (UUID) - User claiming bonus

**Returns:**
- `success` (BOOLEAN)
- `seeds_awarded` (INTEGER)
- `message` (TEXT)

**Validations:**
- User must exist
- User must be waitlist member (`is_waitlist_user = true`)
- Bonus not already claimed (`waitlist_bonus_claimed = false`)

**Bonus Amount:** Configured in `app_config.waitlist_bonus_seeds` (default: 100)

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM claim_waitlist_bonus('user-uuid-here');
```

---

### get_user_referral_info()

**Purpose:** Returns complete referral information for a user including their referrals and statistics.

**Created:** MIGRATION005

**Parameters:**
- `p_user_id` (UUID) - User to retrieve info for

**Returns:**
- `referral_code` (TEXT)
- `referral_count` (INTEGER)
- `seeds_balance` (INTEGER)
- `is_waitlist_user` (BOOLEAN)
- `waitlist_bonus_claimed` (BOOLEAN)
- `referrals` (JSONB) - Array of referral objects

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM get_user_referral_info('user-uuid-here');
```

**Example Output:**
```json
{
  "referral_code": "a1b2c3d4",
  "referral_count": 3,
  "seeds_balance": 500,
  "is_waitlist_user": true,
  "waitlist_bonus_claimed": true,
  "referrals": [
    {
      "referee_id": "uuid-1",
      "seeds_awarded": 200,
      "created_at": "2026-02-01T10:00:00Z"
    },
    {
      "referee_id": "uuid-2",
      "seeds_awarded": 100,
      "created_at": "2026-02-05T14:30:00Z"
    }
  ]
}
```

---

## Reward Functions

### record_seed_transaction()

**Purpose:** Generic function to record seed transactions with automatic balance updates and audit logging.

**Created:** MIGRATION006

**Parameters:**
- `p_user_id` (UUID) - User receiving/spending seeds
- `p_amount` (INTEGER) - Amount to add/subtract
- `p_source` (TEXT) - Transaction source
- `p_reference` (TEXT) - External reference
- `p_metadata` (JSONB) - Additional data (default: `{}`)

**Returns:** INTEGER (new balance)

**Process:**
1. Update `users.seeds_balance`
2. Insert record into `seed_transactions`
3. Return new balance

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT record_seed_transaction(
  'user-uuid',
  100,
  'signup_bonus',
  'waitlist_signup',
  '{"awarded_at": "2026-02-12T12:00:00Z"}'::jsonb
);
```

---

### award_signup_bonus()

**Purpose:** Awards one-time signup bonus (default 100 seeds) to new waitlist users.

**Created:** MIGRATION006

**Parameters:**
- `p_user_id` (UUID) - User to award bonus

**Returns:**
- `success` (BOOLEAN)
- `seeds_awarded` (INTEGER)
- `new_balance` (INTEGER)
- `message` (TEXT)

**Validations:**
- Idempotency check (prevents double-award)
- Checks if `signup_bonus` transaction already exists

**Bonus Amount:** Configured in `app_config.signup_bonus_seeds` (default: 100)

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM award_signup_bonus('user-uuid-here');
```

---

### award_verification_bonus()

**Purpose:** Awards one-time email verification bonus (default 50 seeds) after email confirmation.

**Created:** MIGRATION006

**Parameters:**
- `p_user_id` (UUID) - User to award bonus

**Returns:**
- `success` (BOOLEAN)
- `seeds_awarded` (INTEGER)
- `new_balance` (INTEGER)
- `message` (TEXT)

**Validations:**
- Email must be verified (`waitlist_signups.email_verified = true`)
- Idempotency check (prevents double-award)
- Auto-updates `fraud_status` to `approved` if still `pending`

**Bonus Amount:** Configured in `app_config.email_verification_bonus_seeds` (default: 50)

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM award_verification_bonus('user-uuid-here');
```

---

### award_referral_bonus()

**Purpose:** Awards referral bonuses with tiered rewards: 1st=200, 2nd=100, 3rd=50 seeds. Tracks but does not pay for referrals 4+.

**Created:** MIGRATION006

**Parameters:**
- `p_referrer_id` (UUID) - User who referred
- `p_referee_id` (UUID) - User who was referred

**Returns:**
- `success` (BOOLEAN)
- `seeds_awarded` (INTEGER)
- `new_balance` (INTEGER)
- `referral_number` (INTEGER)
- `message` (TEXT)

**Logic:**
1. Increment referrer's `referral_count`
2. Determine bonus amount:
   - Referral #1: 200 seeds
   - Referral #2: 100 seeds
   - Referral #3: 50 seeds
   - Referral #4+: 0 seeds (tracked only)
3. Record transaction even if amount is 0 (audit trail)
4. Return appropriate message

**Validations:**
- Idempotency check per referee (prevents double-payment)

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM award_referral_bonus('referrer-uuid', 'referee-uuid');
```

---

### process_email_verification()

**Purpose:** Orchestrates all email verification rewards: signup bonus, verification bonus, and referral rewards.

**Created:** MIGRATION006

**Parameters:**
- `p_user_id` (UUID) - User verifying email
- `p_referred_by` (UUID) - Optional referrer ID

**Returns:**
- `success` (BOOLEAN)
- `total_seeds_awarded` (INTEGER)
- `breakdown` (JSONB) - Detailed award breakdown
- `message` (TEXT)

**Process:**
1. Mark email as verified in `waitlist_signups`
2. Award signup bonus (+100 seeds)
3. Award verification bonus (+50 seeds)
4. If referred, award referral bonus to referrer
5. Return summary of all awards

**Security:** SECURITY DEFINER

**Usage:**
```sql
-- Without referral
SELECT * FROM process_email_verification('user-uuid');

-- With referral
SELECT * FROM process_email_verification('user-uuid', 'referrer-uuid');
```

**Example Output:**
```json
{
  "success": true,
  "total_seeds_awarded": 150,
  "breakdown": {
    "signup_bonus": 100,
    "verification_bonus": 50,
    "referral_awarded_to_referrer": 200,
    "referrer_id": "referrer-uuid"
  },
  "message": "Welcome to FarmCash! You received 150 seeds 🌱"
}
```

---

## Fraud Detection Functions

### check_fraud_signals()

**Purpose:** PLACEHOLDER for real-time fraud detection. Will integrate with IPQS API when ready.

**Created:** MIGRATION006

**Parameters:**
- `p_ip_address` (TEXT)
- `p_email` (TEXT)
- `p_fingerprint_hash` (TEXT)

**Returns:**
- `risk_score` (INTEGER)
- `is_vpn` (BOOLEAN)
- `is_proxy` (BOOLEAN)
- `is_disposable_email` (BOOLEAN)
- `country_code` (TEXT)
- `fraud_status` (TEXT)

**Current Implementation:** Returns safe defaults

**TODO:**
- Integrate IPQS API
- Check IP reputation
- Verify email deliverability
- Detect VPN/proxy/datacenter
- Return real risk scores

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM check_fraud_signals('1.2.3.4', 'user@example.com', 'hash123');
```

---

# Views & Analytics

## top_referrers (View)

**Purpose:** Leaderboard of top 100 users by referral count.

**Created:** MIGRATION005

**Columns:**
- `id` - User ID
- `name` - Display name
- `referral_code` - Referral code
- `referral_count` - Number of referrals
- `seeds_balance` - Current seed balance
- `is_waitlist_user` - Waitlist status
- `creation_date` - Account creation date
- `total_referrals_logged` - Count from referrals table
- `total_seeds_earned_from_referrals` - Sum of seed awards

**Filters:** Only users with `referral_count > 0`

**Ordering:** By `referral_count DESC`, then `total_seeds_earned_from_referrals DESC`

**Limit:** 100 rows

**Usage:**
```sql
SELECT * FROM top_referrers;
```

---

## referral_stats (View)

**Purpose:** High-level referral program statistics.

**Created:** MIGRATION005

**Columns:**
- `waitlist_users` - Count of waitlist users
- `app_users` - Count of non-waitlist users
- `total_users` - Total user count
- `referred_users` - Users who were referred
- `referral_rate_percentage` - % of users who were referred
- `total_referrals_made` - Sum of all referrals
- `avg_referrals_per_user` - Average referrals per user
- `waitlist_bonuses_claimed` - Waitlist bonuses claimed
- `waitlist_bonuses_pending` - Waitlist bonuses not yet claimed

**Usage:**
```sql
SELECT * FROM referral_stats;
```

**Example Output:**
```
waitlist_users: 1500
app_users: 500
total_users: 2000
referred_users: 800
referral_rate_percentage: 40.00
total_referrals_made: 1200
avg_referrals_per_user: 0.60
waitlist_bonuses_claimed: 300
waitlist_bonuses_pending: 1200
```

---

# Triggers

## on_user_referral_signup (Trigger)

**Purpose:** Automatically credits referrer when new user signs up with referral.

**Created:** MIGRATION005

**Table:** `public.users`

**Event:** AFTER INSERT

**For Each:** ROW

**Executes:** `credit_referrer()` function

**Process:**
1. Fires when new row inserted into `public.users`
2. Checks if `referred_by` is not NULL
3. If referred, credits appropriate seed reward to referrer
4. Increments referrer's `referral_count`
5. Logs event in `public.referrals` table

**Example Flow:**
```
1. New user signs up with referral code "abc123"
2. User inserted into auth.users
3. handle_new_user() creates public.users record with referred_by set
4. on_user_referral_signup trigger fires
5. credit_referrer() function executes
6. Referrer receives seeds based on their referral count
```

---

# Migration History

## Version 3.0 - February 12, 2026

### MIGRATION005: Referral System
**Date:** February 10, 2026  
**Purpose:** Add comprehensive referral tracking and rewards

**Changes:**

#### Tables Modified
- **public.users**: Added 5 new columns
  - `referral_code` TEXT UNIQUE
  - `referred_by` UUID (FK to users)
  - `referral_count` INTEGER
  - `is_waitlist_user` BOOLEAN
  - `waitlist_bonus_claimed` BOOLEAN

#### Tables Created
- **public.referrals**: Audit log of referral events
  - Tracks referrer, referee, seeds awarded
  - Unique constraint on (referrer_id, referee_id)

#### Functions Created
- `credit_referrer()` - Auto-credit on signup
- `claim_waitlist_bonus()` - Award early adopter bonus
- `get_user_referral_info()` - Retrieve referral data

#### Functions Modified
- `handle_new_user()` - Now generates referral codes

#### Views Created
- `top_referrers` - Leaderboard of top 100 referrers
- `referral_stats` - High-level program metrics

#### Triggers Created
- `on_user_referral_signup` - Auto-credit referrer

#### Configuration Added
- `referral_reward_1st` = 200
- `referral_reward_2nd` = 100
- `referral_reward_3rd` = 50
- `referral_reward_ongoing` = 25
- `waitlist_bonus_seeds` = 100
- `referral_link_bonus` = 50

#### Indexes Created
- `idx_users_referral_code`
- `idx_users_referred_by`
- `idx_users_is_waitlist`
- `idx_users_referral_count`
- `idx_referrals_referrer`
- `idx_referrals_referee`
- `idx_referrals_created`

---

### MIGRATION006: Waitlist Signups & Reward System
**Date:** February 12, 2026  
**Purpose:** Track web waitlist signups with automated rewards and fraud detection

**Changes:**

#### Tables Created
- **public.waitlist_signups**: Track waitlist signups
  - Core identity (user_id, email)
  - Survey answers (game_type, rewarded_apps, devices)
  - Fraud detection (IP, timezone, browser, fingerprint)
  - Status tracking (email_verified, migrated_to_app)
  - Marketing data (UTM params, referrer)

#### Functions Created
- `record_seed_transaction()` - Generic seed transaction helper
- `award_signup_bonus()` - Award 100 seeds on signup
- `award_verification_bonus()` - Award 50 seeds on email verify
- `award_referral_bonus()` - Tiered referral rewards (200/100/50/0)
- `process_email_verification()` - Orchestrator for all verification rewards
- `check_fraud_signals()` - Placeholder for IPQS integration

#### Configuration Added
- `signup_bonus_seeds` = 100
- `email_verification_bonus_seeds` = 50

#### Indexes Created
- `idx_waitlist_user_id`
- `idx_waitlist_email`
- `idx_waitlist_fingerprint`
- `idx_waitlist_ip`
- `idx_waitlist_created`
- `idx_waitlist_fraud_status`
- `idx_waitlist_verified`

#### RLS Policies Created
- Users can view/insert/update only their own waitlist data

---

## Version 2.0 - February 10, 2026

**Initial comprehensive documentation of existing schema**

**Tables Documented:**
- Core User & Game: users, user_farms, crop_types, crops, harvest_history
- Transaction & Economy: seed_transactions, postback_log, postback_deduplication
- Security & Fraud: fraud_events
- Feature & Feedback: feature_requests, feature_votes, awaiting_feature_requests
- System & Configuration: app_config, user_infos, devices, notifications, subscriptions

**Total Tables:** 17 in public schema

---

## Schema Summary

### **Tables by Category**

**Core Game (5 tables):**
- users, user_farms, crop_types, crops, harvest_history

**Economy (3 tables):**
- seed_transactions, postback_log, postback_deduplication

**Referral & Waitlist (2 tables):** ✨ NEW
- referrals, waitlist_signups

**Security (1 table):**
- fraud_events

**Features (3 tables):**
- feature_requests, feature_votes, awaiting_feature_requests

**System (5 tables):**
- app_config, user_infos, devices, notifications, subscriptions

**Total:** 19 tables in public schema

**Functions:** 10 stored procedures
**Views:** 2 analytics views
**Triggers:** 1 automatic trigger

---

## Key Relationships Diagram

```
auth.users (Supabase Auth)
    │
    ├──> public.users (1:1)
    │       ├──> user_farms (1:1)
    │       │       ├──> crops (1:many)
    │       │       └──> harvest_history (1:many)
    │       ├──> seed_transactions (1:many)
    │       ├──> devices (1:many)
    │       ├──> notifications (1:many)
    │       ├──> referrals (as referrer, 1:many) ✨ NEW
    │       ├──> referrals (as referee, 1:many) ✨ NEW
    │       ├──> waitlist_signups (1:1) ✨ NEW
    │       └──> users.referred_by (self-referencing) ✨ NEW
    │
    ├──> postback_log (1:many)
    ├──> feature_votes (1:many)
    └──> awaiting_feature_requests (1:many)

crop_types (master data)
    ├──> crops (1:many)
    └──> harvest_history (1:many)

feature_requests
    └──> feature_votes (1:many)
```

---

## Reward System Flow Chart

```
NEW USER SIGNUP
    │
    ├─> handle_new_user() fires
    │   └─> Generates referral_code
    │
    ├─> (If referred) on_user_referral_signup trigger fires
    │   └─> credit_referrer() executes
    │       ├─> Awards seeds to referrer (200/100/50/25)
    │       ├─> Increments referral_count
    │       └─> Logs in referrals table
    │
    └─> User verifies email
        └─> process_email_verification() executes
            ├─> award_signup_bonus() → +100 seeds
            ├─> award_verification_bonus() → +50 seeds
            └─> (If referred) award_referral_bonus() to referrer
```

---

## Best Practices

### When Working with Referrals
1. Always check `referral_count` before awarding to determine tier
2. Use `get_user_referral_info()` for comprehensive user data
3. Check `public.referrals` table for audit trail
4. Referral codes are auto-generated (8 chars, alphanumeric)

### When Working with Waitlist
1. Use `process_email_verification()` as orchestrator (don't call individual functions)
2. Check `fraud_status` before allowing withdrawals
3. Mark `migrated_to_app = true` when user opens app
4. Store fingerprint hash for duplicate detection

### When Recording Transactions
1. Always use `record_seed_transaction()` for consistency
2. Include descriptive `source` and `reference` values
3. Use `metadata` JSONB for additional context
4. Never manually update `seeds_balance` (use function)

### Security Considerations
1. All reward functions use SECURITY DEFINER
2. RLS policies restrict data access appropriately
3. Idempotency checks prevent double-rewards
4. Fraud detection placeholder ready for IPQS integration

---

## Pending TODOs

### High Priority
- [ ] Integrate IPQS API into `check_fraud_signals()`
- [ ] Build landing page at `/referral`
- [ ] Test full referral flow end-to-end
- [ ] Set up email verification system
- [ ] Create admin dashboard for fraud review

### Medium Priority
- [ ] Add analytics for referral conversion rates
- [ ] Implement automated fraud status updates
- [ ] Create function to handle app migration bonus
- [ ] Add webhook for email verification events
- [ ] Build referral leaderboard UI

### Low Priority
- [ ] Add more granular fraud event types
- [ ] Create scheduled job for inactive account cleanup
- [ ] Add referral code vanity URLs
- [ ] Implement referral link tracking analytics
- [ ] Create marketing attribution reports

---

**Document Control:**  
Complete public schema as of February 12, 2026.  
Source: Actual Supabase database with MIGRATION005 & MIGRATION006.  
Next update: After fraud detection integration or major schema changes.

---

**Questions or Issues?**  
Contact: Malcolm  
Email: support@megaunlimited.io  
Documentation: This file (FarmCash_Complete_Public_Schema_v3.md)
