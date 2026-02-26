# FarmCash - Complete Public Schema Documentation v3.0

## Document Overview

**Created:** February 10, 2026
**Last Updated:** February 25, 2026
**Author:** Malcolm
**Version:** 3.0
**Purpose:** Complete and accurate documentation of ALL public schema tables, functions, and views
**Status:** Source of Truth — Based on actual database through MIGRATION008
**Scope:** All tables, functions, triggers, and views in public schema

---

## ⚠️ IMPORTANT NOTES

- **This document reflects the ACTUAL schema** including all migrations through MIGRATION008
- All table names, column names, data types, and defaults are exact matches
- Use this as the authoritative reference when writing code
- Last verified: February 25, 2026
- The FarmCash Supabase backend is used by 3 separate applications:
  - **FarmCash Mobile App** (`farmcash-app`) — Flutter/Android
  - **FarmCash Web App** (`farmcash-public`) at https://farmcash.app
    - Serves branded verification pages (email confirmation, password change)
    - Custom Waitlist Signup system with referral seed awards
    - Main homepage
  - **Offer Completion Gateway (OCG)** — receives partner postbacks, deduplicates, credits seeds

---

## Table of Contents

1. [Core User & Game Tables](#core-user--game-tables)
   - [public.users](#publicusers)
   - [public.user_farms](#publicuser_farms)
   - [public.crop_types](#publiccrop_types)
   - [public.crops](#publiccrops)
   - [public.harvest_history](#publicharvest_history)

2. [Progression & Farm Layout Tables](#progression--farm-layout-tables)
   - [public.levels](#publiclevels)
   - [public.farm_rows](#publicfarm_rows)
   - [public.user_unlocked_plots](#publicuser_unlocked_plots)

3. [Transaction & Economy Tables](#transaction--economy-tables)
   - [public.seed_transactions](#publicseed_transactions)
   - [public.postback_log](#publicpostback_log)
   - [public.postback_deduplication](#publicpostback_deduplication)

4. [Referral & Waitlist Tables](#referral--waitlist-tables)
   - [public.referrals](#publicreferrals)
   - [public.waitlist_signups](#publicwaitlist_signups)

5. [Security & Fraud Tables](#security--fraud-tables)
   - [public.fraud_events](#publicfraud_events)

6. [Feature & Feedback Tables](#feature--feedback-tables)
   - [public.feature_requests](#publicfeature_requests)
   - [public.feature_votes](#publicfeature_votes)
   - [public.awaiting_feature_requests](#publicawaiting_feature_requests)

7. [System & Configuration Tables](#system--configuration-tables)
   - [public.app_config](#publicapp_config)
   - [public.user_infos](#publicuser_infos)
   - [public.devices](#publicdevices)
   - [public.notifications](#publicnotifications)
   - [public.subscriptions](#publicsubscriptions)

8. [Views](#views)
   - [active_crops_with_details](#active_crops_with_details-view)
   - [farm_overview](#farm_overview-view)
   - [top_referrers](#top_referrers-view)
   - [referral_stats](#referral_stats-view)

9. [Functions & Stored Procedures](#functions--stored-procedures)
   - [Core / Signup](#core--signup-functions)
   - [Game Economy](#game-economy-functions)
   - [Progression](#progression-functions)
   - [Referral & Waitlist](#referral--waitlist-functions)
   - [Fraud Detection](#fraud-detection-functions)
   - [Utility](#utility-functions)

10. [Triggers](#triggers)

11. [Migration History](#migration-history)

12. [Key Relationships Diagram](#key-relationships-diagram)

13. [Pending TODOs](#pending-todos)

---

# Core User & Game Tables

## public.users

### **Purpose**
Core user profile table. Stores account information, game progression (level, XP), virtual currency balances, and referral tracking. Currency and progression live here (not on user_farms).

### **Complete Schema**

```sql
CREATE TABLE public.users (
  id                          uuid        NOT NULL DEFAULT gen_random_uuid(),
  creation_date               timestamptz NOT NULL DEFAULT now(),
  last_update_date            timestamp,
  name                        character varying,
  email                       character varying,
  avatar_url                  text,
  onboarded                   boolean     NOT NULL DEFAULT false,
  seeds_balance               integer     DEFAULT 0,
  cash_balance                numeric     DEFAULT 0.00,
  level                       integer     DEFAULT 1,
  total_harvests              integer     DEFAULT 0,
  xp                          integer     DEFAULT 0,
  water_balance               integer     DEFAULT 100,
  locale                      text        DEFAULT 'en',
  watering_unlocked           boolean     NOT NULL DEFAULT false,
  sprouting_seeds_balance     integer     NOT NULL DEFAULT 0,
  referral_code               text        UNIQUE,
  referred_by                 uuid        REFERENCES public.users(id) ON DELETE SET NULL,
  referral_count              integer     DEFAULT 0,
  is_waitlist_user            boolean     DEFAULT false,
  waitlist_bonus_claimed      boolean     DEFAULT false,
  email_verified_bonus_claimed boolean    DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | UUID | `gen_random_uuid()` | Primary key — matches `auth.users.id` |
| `creation_date` | TIMESTAMPTZ | `now()` | Account creation timestamp |
| `last_update_date` | TIMESTAMP | NULL | Last modification timestamp |
| `name` | VARCHAR | NULL | Display name |
| `email` | VARCHAR | NULL | Email (mirrors auth.users.email) |
| `avatar_url` | TEXT | NULL | Profile picture URL |
| `onboarded` | BOOLEAN | `false` | FTUE completion status |
| `seeds_balance` | INTEGER | `0` | Available seeds for planting |
| `cash_balance` | NUMERIC | `0.00` | Harvested cash (real USD equivalent) |
| `level` | INTEGER | `1` | Progression level (1–10). Renamed from `user_level` in MIGRATION008 |
| `total_harvests` | INTEGER | `0` | Lifetime harvest count |
| `xp` | INTEGER | `0` | Experience points. Renamed from `experience_points` in MIGRATION008. Never decremented |
| `water_balance` | INTEGER | `100` | Watering resource (0–999) |
| `locale` | TEXT | `'en'` | Language preference |
| `watering_unlocked` | BOOLEAN | `false` | Set to true when user reaches Level 3. Controls watering UI. Added in MIGRATION008 |
| `sprouting_seeds_balance` | INTEGER | `0` | Seeds pending advertiser confirmation (postback status = 'pending'). Not yet wired to OCG — placeholder for Week 3. Added in MIGRATION008 |
| `referral_code` | TEXT UNIQUE | Auto-generated | 8-char alphanumeric referral code |
| `referred_by` | UUID | NULL | FK to users.id — who referred this user |
| `referral_count` | INTEGER | `0` | Count of successful referrals made |
| `is_waitlist_user` | BOOLEAN | `false` | Whether user joined via waitlist |
| `waitlist_bonus_claimed` | BOOLEAN | `false` | Waitlist bonus claimed flag |
| `email_verified_bonus_claimed` | BOOLEAN | `false` | Email verification bonus claimed flag |

### **Indexes**
- `idx_users_referral_code` on `referral_code`
- `idx_users_referred_by` on `referred_by`
- `idx_users_is_waitlist` on `is_waitlist_user`
- `idx_users_referral_count` on `referral_count` WHERE `referral_count > 0`

### **RLS Policies**
- `"Allow user creation"` — INSERT for anon/authenticated where `auth.uid() = id`
- `"Users can read own record"` — SELECT for authenticated where `auth.uid() = id`
- `"Users can update own profile"` — UPDATE for authenticated; prevents direct modification of `seeds_balance`, `cash_balance`, `water_balance`, `referral_count`

### **⚠️ Column Rename Notice (MIGRATION008)**
`user_level` → `level` and `experience_points` → `xp`. Any code or queries using the old names will break. Flutter model `UserBalances` uses `@JsonKey(name: 'level')` and `@JsonKey(name: 'xp')` while keeping Dart field names `userLevel` / `experiencePoints` for backward compatibility.

---

## public.user_farms

### **Purpose**
One farm per user (enforced by UNIQUE on `user_id`). Stores farm identity and plot capacity. All currency and progression live on `public.users`, not here.

### **Complete Schema**

```sql
CREATE TABLE public.user_farms (
  id         uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  farm_name  varchar     DEFAULT 'My Farm',
  max_plots  integer     DEFAULT 6,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT user_farms_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | UUID | `gen_random_uuid()` | Farm identifier |
| `user_id` | UUID | — | FK → `auth.users(id)`. UNIQUE — one farm per user |
| `farm_name` | VARCHAR | `'My Farm'` | User-customizable farm name |
| `max_plots` | INTEGER | `6` | Currently unlocked plot capacity. Starts at 6 (rows 1+2). Grows as rows are unlocked. Changed from 15 in MIGRATION008 |
| `created_at` | TIMESTAMPTZ | `now()` | Farm creation time |
| `updated_at` | TIMESTAMPTZ | `now()` | Last update time |

### **Important Notes**
- `max_plots` starts at 6, not 15. Plot capacity now derives from `user_unlocked_plots` count, but `max_plots` is kept in sync for fast reads.
- Columns `seeds_balance`, `cash_balance`, `farm_level`, `total_harvests`, `experience_points` were moved to `public.users` in MIGRATION002.

---

## public.crop_types

### **Purpose**
Master data table defining the 4 crop varieties. Stores growth properties and the per-crop yield probability table (p1–p4) used by `roll_yield()`. **Updated significantly in MIGRATION008.**

### **Complete Schema**

```sql
CREATE TABLE public.crop_types (
  id                integer     NOT NULL DEFAULT nextval('crop_types_id_seq'),
  name              varchar     NOT NULL UNIQUE,
  display_name      varchar     NOT NULL,
  growth_time_hours integer     NOT NULL,
  seed_cost         integer     NOT NULL,
  emoji             varchar,
  unlock_level      integer     NOT NULL DEFAULT 1,
  p1                numeric     NOT NULL DEFAULT 0,
  p2                numeric     NOT NULL DEFAULT 0,
  p3                numeric     NOT NULL DEFAULT 0,
  p4                numeric     NOT NULL DEFAULT 0,
  active            boolean     DEFAULT true,
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now(),
  CONSTRAINT crop_types_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key (1=Tomato, 2=Eggplant, 3=Corn, 4=Golden Melon) |
| `name` | VARCHAR UNIQUE | Internal name: `'tomato'`, `'eggplant'`, `'corn'`, `'golden_melon'` |
| `display_name` | VARCHAR | User-facing name |
| `growth_time_hours` | INTEGER | Hours until harvestable |
| `seed_cost` | INTEGER | Seeds deducted from user on planting |
| `emoji` | VARCHAR | Display emoji |
| `unlock_level` | INTEGER | Minimum user level required to plant. Added in MIGRATION008 |
| `p1` | NUMERIC | Probability weight for Y1 (Speedy Harvest, 80% yield). Added in MIGRATION008 |
| `p2` | NUMERIC | Probability weight for Y2 (Standard Harvest, 100% yield). Added in MIGRATION008 |
| `p3` | NUMERIC | Probability weight for Y3 (Bountiful Harvest, 125% yield). Added in MIGRATION008 |
| `p4` | NUMERIC | Probability weight for Y4 (Golden Harvest, 200% yield). Exclusive to Golden Melon. Added in MIGRATION008 |
| `active` | BOOLEAN | Whether crop appears in offerwall |

### **⚠️ Removed Column (MIGRATION008)**
`base_yield_percentage` was dropped and replaced by the RYR (Random Yield Roll) system via `p1`–`p4` probabilities.

### **Current Crop Data**

| id | name | display_name | growth_time_hours | seed_cost | unlock_level | p1 | p2 | p3 | p4 | EV |
|----|------|-------------|------------------|-----------|-------------|-----|-----|-----|-----|-----|
| 1 | tomato | Tomato 🍅 | 4 | 12 | 1 | 0.80 | 0.20 | 0.00 | 0.00 | 84% |
| 2 | eggplant | Eggplant 🍆 | 24 | 24 | 4 | 0.42 | 0.56 | 0.02 | 0.00 | 92.1% |
| 3 | corn | Corn 🌽 | 168 | 100 | 6 | 0.00 | 0.97 | 0.03 | 0.00 | 100.75% |
| 4 | golden_melon | Golden Melon 🍈 | 504 | 200 | 8 | 0.00 | 0.93 | 0.04 | 0.03 | 104% |

**Note:** Golden Melon growth is 504 hours (21 days), not 720h/30 days as in previous design documents. The design doc was updated; the migration SQL is the source of truth.

**Yield EV formula:** `(p1×0.80) + (p2×1.00) + (p3×1.25) + (p4×2.00)`

**Harvest cash formula:** `ROUND((seeds_planted / base_rate) × yield_multiplier, 2)` where `base_rate = 250` from `app_config`.

---

## public.crops

### **Purpose**
Active growing crops on user farms. Each row is one crop instance occupying one plot.

### **Complete Schema**

```sql
CREATE TABLE public.crops (
  id               uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_farm_id     uuid        NOT NULL REFERENCES public.user_farms(id),
  crop_type_id     integer     NOT NULL REFERENCES public.crop_types(id),
  plot_position    integer     NOT NULL CHECK (plot_position >= 0 AND plot_position < 50),
  planted_at       timestamptz DEFAULT now(),
  harvest_ready_at timestamptz NOT NULL,
  harvested_at     timestamptz,
  seeds_invested   integer     NOT NULL CHECK (seeds_invested > 0),
  yield_multiplier numeric     DEFAULT 1.0 CHECK (yield_multiplier > 0),
  final_cash_value numeric,
  status           varchar     DEFAULT 'growing'
    CHECK (status IN ('growing', 'ready', 'harvested')),
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now(),
  CONSTRAINT crops_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX idx_crops_active_plot
  ON crops (user_farm_id, plot_position)
  WHERE harvested_at IS NULL;
```

### **Column Reference**

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Crop instance ID |
| `user_farm_id` | UUID | FK → `user_farms(id)` |
| `crop_type_id` | INTEGER | FK → `crop_types(id)` |
| `plot_position` | INTEGER | Plot index 0–49. Active plot range is 0–23 (rows 1–8) |
| `planted_at` | TIMESTAMPTZ | When planted |
| `harvest_ready_at` | TIMESTAMPTZ | `planted_at + growth_time_hours`. When harvestable |
| `harvested_at` | TIMESTAMPTZ | NULL while growing. Set at harvest |
| `seeds_invested` | INTEGER | Seeds deducted at planting. Snapshot from crop_types.seed_cost |
| `yield_multiplier` | NUMERIC | Actual yield multiplier applied at harvest (set by roll_yield()) |
| `final_cash_value` | NUMERIC | Cash credited to user. Set at harvest |
| `status` | VARCHAR | `growing` / `ready` / `harvested`. Do not rely on stored status for `ready` — use `active_crops_with_details` view which computes dynamically |

### **Important Notes**
- `status` can go stale. The `active_crops_with_details` view computes status dynamically from `harvest_ready_at <= now()`. Use the view for display logic.
- The unique index on `(user_farm_id, plot_position) WHERE harvested_at IS NULL` enforces one active crop per plot.
- `plot_position` allows up to 50 but active range is 0–23 per `user_unlocked_plots`.

---

## public.harvest_history

### **Purpose**
Immutable audit log of all successful harvests. INSERT only — never updated or deleted.

### **Complete Schema**

```sql
CREATE TABLE public.harvest_history (
  id                    uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_farm_id          uuid        NOT NULL REFERENCES public.user_farms(id),
  crop_type_id          integer     NOT NULL REFERENCES public.crop_types(id),
  seeds_invested        integer     NOT NULL,
  cash_earned           numeric     NOT NULL,
  growth_time_actual    interval    NOT NULL,
  yield_percentage      integer     NOT NULL,
  plot_position         integer     NOT NULL,
  harvested_at          timestamptz DEFAULT now(),
  user_level_at_harvest integer,
  total_harvests_before integer,
  created_at            timestamptz DEFAULT now(),
  CONSTRAINT harvest_history_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Description |
|--------|-------------|
| `seeds_invested` | Seeds used for this crop |
| `cash_earned` | Cash added to user balance |
| `growth_time_actual` | Actual elapsed time (interval) from plant to harvest |
| `yield_percentage` | `ROUND(yield_multiplier × 100)` — e.g. 80, 100, 125, 200 |
| `user_level_at_harvest` | User's level when harvested (analytics snapshot) |
| `total_harvests_before` | User's harvest count before this one |

---

# Progression & Farm Layout Tables

*Added in MIGRATION008*

## public.levels

### **Purpose**
Single source of truth for all progression logic. Defines XP thresholds, crop unlocks, row soft-unlocks, and watering unlock per level.

### **Complete Schema**

```sql
CREATE TABLE public.levels (
  level             integer  PRIMARY KEY,
  xp_threshold      integer  NOT NULL,
  xp_to_next        integer  NULL,
  crop_unlock_id    integer  NULL REFERENCES public.crop_types(id),
  row_unlock        integer  NULL REFERENCES public.farm_rows(row_number),
  unlocks_watering  boolean  NOT NULL DEFAULT false,
  label             text     NOT NULL
);

CREATE INDEX idx_levels_xp_threshold ON public.levels(xp_threshold);
```

### **Column Reference**

| Column | Type | Description |
|--------|------|-------------|
| `level` | INTEGER | Level number 1–10. PRIMARY KEY |
| `xp_threshold` | INTEGER | Cumulative XP required to reach this level |
| `xp_to_next` | INTEGER | XP needed to reach the next level. NULL at max level (10) |
| `crop_unlock_id` | INTEGER | FK → `crop_types(id)`. Which crop becomes plantable at this level. NULL if no crop unlock |
| `row_unlock` | INTEGER | FK → `farm_rows(row_number)`. Which farm row becomes soft-unlocked. NULL if no row unlock |
| `unlocks_watering` | BOOLEAN | If true, sets `users.watering_unlocked = true` when user reaches this level |
| `label` | TEXT | Display name for the level |

### **RLS**
Read-only for all authenticated users: `"levels_read_authenticated"`.

### **Level Data**

| Level | Label | XP Threshold | XP to Next | Crop Unlock | Row Unlock | Watering |
|-------|-------|-------------|-----------|-------------|-----------|---------|
| 1 | Seedling | 0 | 500 | Tomato | — | No |
| 2 | Sprout | 500 | 500 | — | Row 3 | No |
| 3 | Grower | 1,000 | 1,000 | — | Row 4 | **Yes** |
| 4 | Farmer | 2,000 | 2,000 | Eggplant | — | No |
| 5 | Cultivator | 4,000 | 4,000 | — | Row 5 | No |
| 6 | Harvester | 8,000 | 8,000 | Corn | — | No |
| 7 | Rancher | 16,000 | 16,000 | — | Row 6 | No |
| 8 | Orchardist | 32,000 | 32,000 | Golden Melon | — | No |
| 9 | Agronomist | 64,000 | 64,000 | — | Row 7 | No |
| 10 | Legendary Farmer | 128,000 | NULL | — | Row 8 | No |

**XP source:** 1 XP per seed earned from offer completions. XP is never deducted.

**Level 1 note:** Rows 1+2 (plots 0–5) are granted free at signup via `create_initial_farm_for_user()`. No `row_unlock` event is needed.

---

## public.farm_rows

### **Purpose**
Static reference table. Defines the physical layout of the farm grid — which plot IDs belong to each row, what level soft-unlocks the row, and the seed cost to fully unlock each plot.

### **Complete Schema**

```sql
CREATE TABLE public.farm_rows (
  row_number    integer  PRIMARY KEY,
  plot_id_start integer  NOT NULL,
  plot_id_end   integer  NOT NULL,
  unlock_level  integer  NOT NULL,
  cost_per_plot integer  NOT NULL DEFAULT 0,
  CONSTRAINT farm_rows_plot_range CHECK (plot_id_end >= plot_id_start),
  CONSTRAINT farm_rows_cost_check  CHECK (cost_per_plot >= 0)
);
```

### **Column Reference**

| Column | Description |
|--------|-------------|
| `row_number` | 1-indexed row number (1–8). PRIMARY KEY |
| `plot_id_start` | First plot ID in this row (inclusive) |
| `plot_id_end` | Last plot ID in this row (inclusive) |
| `unlock_level` | User level at which this row becomes visible (soft-unlock). Plot purchase is a separate step |
| `cost_per_plot` | Seeds to fully unlock one plot in this row. 0 = free (rows 1–2) |

### **RLS**
Read-only for all authenticated users: `"farm_rows_read_authenticated"`.

### **Farm Layout**

```
Visual layout: 3 columns × 8 rows = 24 max plots

Row 1 (Level 1, free):   [0]  [1]  [2]
Row 2 (Level 1, free):   [3]  [4]  [5]
Row 3 (Level 2, 100/pl): [6]  [7]  [8]
Row 4 (Level 3, 150/pl): [9]  [10] [11]
Row 5 (Level 5, 250/pl): [12] [13] [14]
Row 6 (Level 7, 400/pl): [15] [16] [17]
Row 7 (Level 9, 900/pl): [18] [19] [20]
Row 8 (Level 10,1200/pl):[21] [22] [23]
```

| Row | Plot IDs | Unlock Level | Cost/Plot | Total Row Cost |
|-----|----------|-------------|----------|----------------|
| 1 | 0–2 | 1 | 0 | 0 |
| 2 | 3–5 | 1 | 0 | 0 |
| 3 | 6–8 | 2 | 100 | 300 |
| 4 | 9–11 | 3 | 150 | 450 |
| 5 | 12–14 | 5 | 250 | 750 |
| 6 | 15–17 | 7 | 400 | 1,200 |
| 7 | 18–20 | 9 | 900 | 2,700 |
| 8 | 21–23 | 10 | 1,200 | 3,600 |
| **Total** | | | | **9,000 seeds** |

---

## public.user_unlocked_plots

### **Purpose**
Per-user record of which plots have been purchased or granted. Plots 0–5 are auto-inserted for every new user at signup. All other plots require a seed purchase via `unlock_plot()`.

### **Complete Schema**

```sql
CREATE TABLE public.user_unlocked_plots (
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plot_id     integer     NOT NULL CHECK (plot_id >= 0 AND plot_id <= 23),
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, plot_id)
);

CREATE INDEX idx_user_unlocked_plots_user ON public.user_unlocked_plots(user_id);
```

### **Column Reference**

| Column | Description |
|--------|-------------|
| `user_id` | FK → `users(id)`. Part of composite PK |
| `plot_id` | Plot ID 0–23. Part of composite PK |
| `unlocked_at` | When this plot was unlocked |

### **RLS**
Users see and manage only their own rows: `"user_unlocked_plots_own"`.

### **Important Notes**
- A plot must be present in this table before a crop can be planted on it.
- Plots 0–5 are inserted by `create_initial_farm_for_user()` at signup.
- Use `unlock_plot(user_id, plot_id)` to purchase additional plots.
- Count of rows per user = user's effective plot capacity (cross-check with `user_farms.max_plots`).

---

# Transaction & Economy Tables

## public.seed_transactions

### **Purpose**
Complete ledger of all seed balance changes. Every credit and debit is logged here. Used for reconciliation, support, and fraud detection.

### **Complete Schema**

```sql
CREATE TABLE public.seed_transactions (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now(),
  amount       integer     NOT NULL,
  source       varchar     NOT NULL,
  reference    varchar,
  balance_after integer    NOT NULL,
  metadata     jsonb,
  sequence     bigint      NOT NULL DEFAULT nextval('seed_transactions_sequence_seq'),
  xp_granted   integer     NOT NULL DEFAULT 0,
  CONSTRAINT seed_transactions_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Transaction ID |
| `user_id` | UUID | FK → `auth.users(id)` |
| `created_at` | TIMESTAMPTZ | Transaction timestamp |
| `amount` | INTEGER | Seeds credited (positive) or debited (negative) |
| `source` | VARCHAR | Transaction type — see sources below |
| `reference` | VARCHAR | External reference (action_id, offer_id, `plot_N`, etc.) |
| `balance_after` | INTEGER | Seed balance snapshot after transaction |
| `metadata` | JSONB | Additional context (partner, offer details, etc.) |
| `sequence` | BIGINT | Monotonically increasing sequence for ordering and reconciliation |
| `xp_granted` | INTEGER | XP awarded with this transaction. Non-zero only for `offer_completion`. Added in MIGRATION008 |

### **Source Values**

| Source | Direction | When |
|--------|-----------|------|
| `demo_seeds` | + | Initial grant at signup |
| `offer_completion` | + | Verified offer postback |
| `reversal` | − | Advertiser clawback |
| `signup_bonus` | + | Waitlist signup bonus (from award_signup_bonus) |
| `email_verification` | + | Email confirmation bonus |
| `referral_reward` | + | Referral bonus for referrer |
| `plot_unlock` | − | Seed cost of purchasing a plot |
| `planting` | − | Seeds spent planting crops (future) |
| `admin_adjustment` | ± | Manual correction |

**Audit check:** `SELECT SUM(xp_granted) FROM seed_transactions WHERE source = 'offer_completion' AND user_id = $1` should equal `users.xp`.

---

## public.postback_log

### **Purpose**
Complete audit trail of all partner postback callbacks. Every postback received — successful, duplicate, or reversed — is logged here.

### **Complete Schema**

```sql
CREATE TABLE public.postback_log (
  id                uuid        NOT NULL DEFAULT gen_random_uuid(),
  partner           varchar     NOT NULL,
  action_id         varchar     NOT NULL,
  user_id           uuid        REFERENCES auth.users(id),
  offer_id          varchar,
  offer_name        text,
  currency_amount   integer     NOT NULL,
  status            varchar     NOT NULL CHECK (status IN ('completed', 'reversed')),
  commission        numeric,
  processed_at      timestamptz DEFAULT now(),
  response_code     integer,
  response_body     text,
  raw_params        jsonb,
  duplicate_attempts integer    DEFAULT 0,
  last_duplicate_at timestamptz,
  CONSTRAINT postback_log_pkey PRIMARY KEY (id)
);
```

### **Column Reference**

| Column | Description |
|--------|-------------|
| `partner` | Network name: `'AyeT'`, `'RevU'`, `'Prodege'` |
| `action_id` | Partner's unique conversion ID — used for deduplication |
| `currency_amount` | Seeds to credit. Negative for reversals |
| `status` | `completed` = normal credit. `reversed` = clawback |
| `commission` | USD revenue to FarmCash for this action |
| `response_code` | HTTP response code returned to partner (200 = OK, 409 = duplicate) |
| `duplicate_attempts` | How many times this action_id was re-submitted |
| `raw_params` | Full JSONB of original postback request for debugging |

---

## public.postback_deduplication

### **Purpose**
Lightweight duplicate prevention. Checked before processing any postback. `process_postback()` inserts here atomically, so any race-condition retry also fails the duplicate check.

### **Complete Schema**

```sql
CREATE TABLE public.postback_deduplication (
  partner      varchar     NOT NULL,
  action_id    varchar     NOT NULL,
  processed_at timestamptz DEFAULT now(),
  CONSTRAINT postback_deduplication_pkey PRIMARY KEY (partner, action_id)
);
```

### **Important Notes**
- Composite PK on `(partner, action_id)` enforces uniqueness.
- Records older than 90 days are eligible for cleanup via `cleanup_old_deduplication_records()`.
- Always check this table before crediting seeds.

---

# Referral & Waitlist Tables

## public.referrals

### **Purpose**
Audit log of all referral events. Created in MIGRATION005.

### **Complete Schema**

```sql
CREATE TABLE public.referrals (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referee_id  uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  seeds_awarded integer   NOT NULL,
  created_at  timestamptz DEFAULT now(),
  UNIQUE(referrer_id, referee_id)
);
```

### **Column Reference**

| Column | Description |
|--------|-------------|
| `referrer_id` | User who made the referral |
| `referee_id` | User who was referred |
| `seeds_awarded` | Seeds awarded to referrer. Tiered: 1st=200, 2nd=100, 3rd=50, 4th+=25 |

### **RLS**
Users can view referrals where they are referrer or referee.

---

## public.waitlist_signups

### **Purpose**
Tracks web waitlist signups with survey answers and fraud detection signals. Created in MIGRATION006.

### **Complete Schema**

```sql
CREATE TABLE public.waitlist_signups (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  email            text        NOT NULL UNIQUE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  game_type        text,
  rewarded_apps    text[],
  devices          text[],
  ip_address       text,
  timezone         text,
  browser          text,
  os               text,
  device_type      text,
  fingerprint_hash text,
  fraud_status     text        DEFAULT 'pending'
    CHECK (fraud_status IN ('pending','approved','suspicious','flagged','rejected')),
  email_verified      boolean  DEFAULT false,
  email_verified_at   timestamptz,
  migrated_to_app     boolean  DEFAULT false,
  migrated_at         timestamptz,
  referrer            text,
  utm_source          text,
  utm_medium          text,
  utm_campaign        text
);
```

### **Column Reference**

| Column | Description |
|--------|-------------|
| `user_id` | FK → `auth.users(id)`. UNIQUE — one record per user |
| `fraud_status` | `pending` → `approved` / `suspicious` / `flagged` / `rejected` |
| `email_verified` | Set to true by `process_email_verification()` |
| `migrated_to_app` | Set to true when user first opens the mobile app |
| `fingerprint_hash` | Browser/device fingerprint hash for duplicate detection |
| `ip_address` | Signup IP for geo and fraud checks |

### **Fraud Status Values**
- `pending` — New signup, not yet reviewed
- `approved` — Email verified, clean signals
- `suspicious` — Auto-flagged by system
- `flagged` — Admin review required
- `rejected` — Blocked from platform

### **RLS (MIGRATION007)**
- INSERT allowed for anon/authenticated where `auth.uid() = user_id`
- SELECT/UPDATE for authenticated where `auth.uid() = user_id`

---

# Security & Fraud Tables

## public.fraud_events

### **Purpose**
Logs detected fraud events for review and pattern analysis.

### **Complete Schema**

```sql
CREATE TABLE public.fraud_events (
  id          uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id     uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type  varchar     NOT NULL,
  severity    varchar     NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  details     jsonb       NOT NULL,
  created_at  timestamptz DEFAULT now(),
  reviewed    boolean     DEFAULT false,
  reviewed_at timestamptz,
  reviewed_by uuid        REFERENCES auth.users(id),
  resolution  text,
  ip_address  text,
  CONSTRAINT fraud_events_pkey PRIMARY KEY (id)
);
```

### **Event Types**
`vpn_detected`, `geo_mismatch`, `velocity_abuse`, `multi_accounting`, `suspicious_offer_pattern`, `duplicate_fingerprint`, `disposable_email`, `NEGATIVE_BALANCE`

---

# Feature & Feedback Tables

## public.feature_requests

```sql
CREATE TABLE public.feature_requests (
  id               uuid      NOT NULL DEFAULT gen_random_uuid(),
  creation_date    timestamptz NOT NULL DEFAULT now(),
  last_update_date timestamptz NOT NULL DEFAULT now(),
  title            jsonb     NOT NULL,
  description      jsonb     NOT NULL,
  votes            smallint  NOT NULL,
  active           boolean   NOT NULL,
  CONSTRAINT feature_requests_pkey PRIMARY KEY (id)
);
```

`title` and `description` are JSONB for multi-language support.

---

## public.feature_votes

```sql
CREATE TABLE public.feature_votes (
  id            uuid      NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamptz NOT NULL DEFAULT now(),
  user_uid      uuid      NOT NULL REFERENCES auth.users(id),
  feature_id    uuid      NOT NULL REFERENCES public.feature_requests(id),
  CONSTRAINT feature_votes_pkey PRIMARY KEY (id)
);
```

---

## public.awaiting_feature_requests

```sql
CREATE TABLE public.awaiting_feature_requests (
  id            uuid      NOT NULL DEFAULT gen_random_uuid(),
  creation_date timestamptz NOT NULL DEFAULT now(),
  title         text      NOT NULL,
  description   text      NOT NULL,
  user_uid      uuid      NOT NULL REFERENCES auth.users(id),
  CONSTRAINT awaiting_feature_requests_pkey PRIMARY KEY (id)
);
```

Feature requests submitted by users, pending admin approval before becoming public.

---

# System & Configuration Tables

## public.app_config

### **Purpose**
Global key-value configuration store. All economy parameters live here and can be changed without code deploys. Updated in MIGRATION008 with new economy keys.

### **Complete Schema**

```sql
CREATE TABLE public.app_config (
  id           integer   NOT NULL DEFAULT nextval('app_config_id_seq'),
  config_key   varchar   NOT NULL UNIQUE,
  config_value text      NOT NULL,
  value_type   varchar   DEFAULT 'string',
  description  text,
  updated_by   uuid      REFERENCES auth.users(id),
  updated_at   timestamptz DEFAULT now(),
  CONSTRAINT app_config_pkey PRIMARY KEY (id)
);
```

### **Current Config Keys**

#### Economy (MIGRATION008)

| Key | Value | Type | Description |
|-----|-------|------|-------------|
| `base_rate` | `250` | integer | Seeds per $1 USD — internal reference. Used in harvest: `cash = ROUND((seeds / 250) × yield_multiplier, 2)` |
| `payout_rate` | `138` | integer | Seeds per $1 USD delivered to user after FMT. Set in offerwall partner dashboards. Formula: `250 × (1 − 0.45) = 137.5 → 138` |
| `first_margin_take` | `0.45` | decimal | FMT: 45% of gross offer revenue retained by FarmCash before crediting seeds |
| `y1` | `0.80` | decimal | Yield tier 1 multiplier — Speedy Harvest |
| `y2` | `1.00` | decimal | Yield tier 2 multiplier — Standard Harvest |
| `y3` | `1.25` | decimal | Yield tier 3 multiplier — Bountiful Harvest |
| `y4` | `2.00` | decimal | Yield tier 4 multiplier — Golden Harvest (exclusive to Golden Melon) |

#### Referral System (MIGRATION005)

| Key | Value | Description |
|-----|-------|-------------|
| `referral_reward_1st` | `200` | Seeds for referrer's 1st successful referral |
| `referral_reward_2nd` | `100` | Seeds for 2nd referral |
| `referral_reward_3rd` | `50` | Seeds for 3rd referral |
| `referral_reward_ongoing` | `25` | Seeds for 4th+ referrals |
| `waitlist_bonus_seeds` | `100` | One-time bonus for waitlist users on first app open |
| `referral_link_bonus` | `50` | Seeds for sharing referral link |

#### Waitlist Rewards (MIGRATION006)

| Key | Value | Description |
|-----|-------|-------------|
| `signup_bonus_seeds` | `100` | Seeds awarded at waitlist signup |
| `email_verification_bonus_seeds` | `50` | Seeds awarded on email confirmation |

#### General

| Key | Value | Description |
|-----|-------|-------------|
| `demo_seeds` | `100` | Starting seeds granted to all new users at signup |
| `min_withdrawal_amount` | `10.00` | Minimum cash balance to request payout |

#### ⚠️ Removed Keys (MIGRATION008)
- `max_plots_default` — Replaced by `farm_rows` + `user_unlocked_plots` system
- `seeds_to_dollar_rate` — Replaced by `base_rate` and `payout_rate`

---

## public.user_infos

Flexible key-value metadata store per user.

```sql
CREATE TABLE public.user_infos (
  id         uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id),
  info_key   text NOT NULL,
  info_value text NOT NULL,
  CONSTRAINT user_infos_pkey PRIMARY KEY (id)
);
```

Example uses: survey answers (`survey_game_type`), notification preferences.

---

## public.devices

Push notification token registry.

```sql
CREATE TABLE public.devices (
  id               uuid      NOT NULL DEFAULT gen_random_uuid(),
  user_id          uuid      NOT NULL REFERENCES auth.users(id),
  creation_date    timestamptz NOT NULL,
  last_update_date timestamptz NOT NULL,
  installation_id  text      NOT NULL,
  token            text      NOT NULL,
  operatingSystem  text      NOT NULL,
  CONSTRAINT devices_pkey PRIMARY KEY (id)
);
```

---

## public.notifications

In-app and push notification log.

```sql
CREATE TABLE public.notifications (
  id            uuid      NOT NULL DEFAULT gen_random_uuid(),
  user_id       uuid      NOT NULL REFERENCES auth.users(id),
  title         text      NOT NULL,
  body          text      NOT NULL,
  data          jsonb,
  type          text,
  creation_date timestamptz NOT NULL,
  read_date     timestamptz,
  CONSTRAINT notifications_pkey PRIMARY KEY (id)
);
```

`read_date = NULL` means unread.

---

## public.subscriptions

In-app purchase subscription tracking.

```sql
CREATE TABLE public.subscriptions (
  id               uuid NOT NULL DEFAULT gen_random_uuid(),
  creation_date    timestamptz NOT NULL DEFAULT now(),
  sku_id           text NOT NULL,
  last_update_date timestamptz NOT NULL,
  period_end_date  timestamptz,
  user_id          uuid REFERENCES auth.users(id),
  store            USER-DEFINED,
  status           USER-DEFINED NOT NULL,
  CONSTRAINT subscriptions_pkey PRIMARY KEY (id)
);
```

`store` and `status` are custom enums (App Store / Play Store; Active / Expired / Cancelled).

---

# Views

## active_crops_with_details (View)

**Purpose:** Active crops joined with crop type data. Status is computed dynamically — always accurate regardless of stored `crops.status`.

**Updated in MIGRATION008:** removed `base_yield_percentage`, added `p1`–`p4`, `unlock_level`, `final_cash_value`, `harvested_at`. Status derived from `harvest_ready_at <= now()`.

```sql
CREATE OR REPLACE VIEW public.active_crops_with_details AS
SELECT
  c.id,
  c.user_farm_id,
  c.crop_type_id,
  c.plot_position,
  c.planted_at,
  c.harvest_ready_at,
  c.harvested_at,
  c.seeds_invested,
  c.yield_multiplier::double precision AS yield_multiplier,
  c.final_cash_value,
  CASE
    WHEN c.harvest_ready_at <= now() THEN 'ready'
    ELSE 'growing'
  END::character varying(20) AS status,
  ct.name         AS crop_name,
  ct.display_name,
  ct.emoji,
  ct.growth_time_hours,
  ct.unlock_level,
  ct.p1, ct.p2, ct.p3, ct.p4
FROM crops c
JOIN crop_types ct ON ct.id = c.crop_type_id
WHERE c.harvested_at IS NULL;
```

---

## farm_overview (View)

Farm summary with user balance and progression from the user table.

```sql
CREATE VIEW farm_overview AS
SELECT
  uf.id          AS farm_id,
  uf.user_id,
  uf.farm_name,
  uf.max_plots,
  u.seeds_balance,
  u.cash_balance,
  u.level,
  u.total_harvests,
  u.xp,
  COUNT(c.id) AS active_crops,
  COUNT(CASE WHEN c.harvest_ready_at <= NOW() THEN 1 END) AS crops_ready_to_harvest
FROM user_farms uf
JOIN public.users u ON uf.user_id = u.id
LEFT JOIN crops c ON uf.id = c.user_farm_id AND c.harvested_at IS NULL
GROUP BY uf.id, uf.user_id, uf.farm_name, uf.max_plots,
         u.seeds_balance, u.cash_balance, u.level, u.total_harvests, u.xp;
```

Uses `level` and `xp` (renamed from `user_level`/`experience_points` in MIGRATION008).

---

## top_referrers (View)

Leaderboard of top 100 users by referral count. Created in MIGRATION005.

**Columns:** `id`, `name`, `referral_code`, `referral_count`, `seeds_balance`, `is_waitlist_user`, `creation_date`, `total_referrals_logged`, `total_seeds_earned_from_referrals`

```sql
SELECT * FROM top_referrers;
```

---

## referral_stats (View)

High-level referral program statistics. Created in MIGRATION005.

**Columns:** `waitlist_users`, `app_users`, `total_users`, `referred_users`, `referral_rate_percentage`, `total_referrals_made`, `avg_referrals_per_user`, `waitlist_bonuses_claimed`, `waitlist_bonuses_pending`

```sql
SELECT * FROM referral_stats;
```

---

# Functions & Stored Procedures

## Core / Signup Functions

### handle_new_user()

**Trigger function** — fires AFTER INSERT on `auth.users`.

**What it does:**
1. Generates a unique 8-char referral code (retry up to 5 times on collision)
2. Inserts row into `public.users` with `level=1, xp=0`
3. Calls `create_initial_farm_for_user()`
4. Calls `grant_initial_seeds()`

**Updated in MIGRATION008:** Uses `level` and `xp` column names (renamed from `user_level`/`experience_points`). Referral code generation now runs for all signups (not just waitlist).

**Returns:** TRIGGER

---

### create_initial_farm_for_user(user_id_param uuid)

Creates the user's farm record and grants starter plots.

**What it does:**
1. INSERTs into `user_farms` with `max_plots = 6`
2. INSERTs plot IDs 0–5 into `user_unlocked_plots` (rows 1 and 2, free)

**Updated in MIGRATION008:** `max_plots` changed from 15 → 6. Now also populates `user_unlocked_plots`.

**Returns:** `uuid` (farm_id)

**Security:** SECURITY DEFINER

---

### grant_initial_seeds(user_id_param uuid)

Awards starting seeds to a new user if their balance is 0 or NULL.

**What it does:** Reads `demo_seeds` from `app_config` (default 100), updates `users.seeds_balance`, logs to `seed_transactions` with `source = 'demo_seeds'`.

**Updated in MIGRATION008:** Source changed from `'signup_bonus'` → `'demo_seeds'` to avoid collision with `award_signup_bonus()` idempotency check.

**Returns:** `integer` (seeds granted, or 0 if user already had seeds)

**Security:** SECURITY DEFINER

---

### create_waitlist_user_complete(...)

Server-side function for the waitlist web app to create users safely. Created in MIGRATION007 (replaces client-side insert). Updated in MIGRATION008 for column renames.

**Parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `p_user_id` | UUID | Auth user ID |
| `p_email` | TEXT | Email address |
| `p_game_type` | TEXT | Survey answer |
| `p_rewarded_apps` | TEXT[] | Survey answer |
| `p_devices` | TEXT[] | Survey answer |
| `p_ip_address` | TEXT | Signup IP |
| `p_timezone` | TEXT | Browser timezone |
| `p_browser` | TEXT | Browser UA |
| `p_os` | TEXT | OS |
| `p_device_type` | TEXT | mobile/desktop |
| `p_fingerprint_hash` | TEXT | Duplicate detection hash |
| `p_referrer` | TEXT | HTTP referrer |
| `p_referred_by` | UUID | Referrer user ID (optional) |

**Logic:** If user already exists (created by `handle_new_user` trigger), updates `is_waitlist_user = true`. If not, creates the user manually using `level`/`xp` column names. Always creates `waitlist_signups` record.

**Returns:** `jsonb` `{ success, user_id, email, referral_code }`

**Security:** SECURITY DEFINER

---

### get_user_id_from_referral_code(p_referral_code text)

Lookup a user by referral code. Used by the waitlist web app to validate referral links before signup.

**Returns:** `uuid` (NULL if code not found)

**Security:** SECURITY DEFINER

---

## Game Economy Functions

### process_postback(...)

Atomic postback processing. Called by the OCG Edge Function after initial validation.

**Parameters:**

| Param | Type |
|-------|------|
| `p_partner` | varchar |
| `p_action_id` | varchar |
| `p_user_id` | uuid |
| `p_currency` | integer (seeds to credit) |
| `p_offer_id` | varchar |
| `p_offer_name` | text |
| `p_status` | varchar (`'completed'` or `'reversed'`) |
| `p_commission` | numeric |
| `p_raw_params` | jsonb |

**Steps:**
1. Deduplication check against `postback_deduplication` (90-day window)
2. Insert deduplication record
3. Validate user exists in `auth.users`
4. Lock user row (`FOR UPDATE`)
5. Determine source: `'offer_completion'` or `'reversal'`
6. Update `users.seeds_balance`
7. Insert `seed_transactions` with `xp_granted` field
8. Call `award_xp(user_id, p_currency)` — **skipped for reversals**
9. Insert `postback_log`

**Updated in MIGRATION008:** source values changed (`'POSTBACK'`→`'offer_completion'`, `'REVERSAL'`→`'reversal'`); `award_xp()` called after offer completion; `xp_granted` added to seed_transactions insert; response payload includes `xp_granted`.

**⚠️ Clawback path TODO:** When `p_status = 'reversed'`, seeds are deducted but XP is NOT. Large reversals should auto-insert into `fraud_events`. Implementation target: Week 3 (when OCG live integration is built).

**Returns:** `jsonb`
```json
{
  "success": true,
  "action_id": "...",
  "postback_id": "uuid",
  "transaction_id": "uuid",
  "old_balance": 100,
  "new_balance": 238,
  "transaction_amount": 138,
  "xp_granted": 138
}
```

**Security:** SECURITY DEFINER

---

### record_seed_transaction(p_user_id, p_amount, p_source, p_reference, p_metadata, p_xp_granted)

Generic helper to record any seed transaction with automatic balance update and audit logging.

**Updated in MIGRATION008:** Added optional `p_xp_granted integer DEFAULT 0` parameter. Existing callers unaffected.

**Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `p_user_id` | uuid | — | |
| `p_amount` | integer | — | Positive = credit, negative = debit |
| `p_source` | text | — | See source values above |
| `p_reference` | text | — | |
| `p_metadata` | jsonb | `'{}'` | |
| `p_xp_granted` | integer | `0` | XP awarded alongside this transaction |

**Returns:** `integer` (new seeds balance)

**Security:** SECURITY DEFINER

---

### test_harvest_crop(p_crop_id uuid)

Developer testing function. Harvests a crop using the full production path (roll_yield, cash calculation, harvest_history insert).

**Updated in MIGRATION008:** Removed `p_cash_amount` parameter — cash is now calculated internally via `roll_yield()` and `base_rate` from `app_config`. Formula: `ROUND((seeds_invested / base_rate) × yield_multiplier, 2)`.

**⚠️ Flutter testing page must be updated:** Remove the `p_cash_amount` argument from any calls to this function.

**Returns:** `jsonb`
```json
{
  "success": true,
  "cash_earned": 0.10,
  "new_cash_balance": 0.10,
  "seeds_invested": 24,
  "crop_name": "eggplant",
  "yield_tier": "y3",
  "yield_label": "Bountiful Harvest",
  "yield_multiplier": 1.25
}
```

**Security:** SECURITY DEFINER

---

### test_create_crops(p_farm_id uuid, p_crop_type_id integer, p_num_plots integer)

Developer testing function. Plants multiple crops on a farm.

**Updated in MIGRATION008:** Seed cost is now read dynamically from `crop_types.seed_cost` instead of a hardcoded CASE statement (old hardcoded values were wrong: 25/50/100/200 vs actual 12/24/100/200).

**Default parameters:** `p_crop_type_id = 1`, `p_num_plots = 6`

**Returns:** `json` with planted count, crop type, seed cost, growth time, ready_at, plots used.

---

## Progression Functions

### roll_yield(p_crop_type_id integer)

Weighted random yield roll for a harvest. Reads probability weights from `crop_types.p1–p4` and multiplier values from `app_config.y1–y4`.

**New in MIGRATION008.**

**Logic:**
1. Reads `p1, p2, p3, p4` for the crop
2. Reads `y1, y2, y3, y4` from `app_config`
3. Rolls `random()` in [0, 1)
4. Walks cumulative probability bands
5. Y4 catches any floating-point remainder

**Returns:** `TABLE(yield_multiplier numeric, tier_label text, tier text)`

Example results:
- Tomato: `(0.80, 'Speedy Harvest', 'y1')` or `(1.00, 'Standard Harvest', 'y2')`
- Golden Melon: above + `(1.25, 'Bountiful Harvest', 'y3')` or `(2.00, 'Golden Harvest', 'y4')`

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM public.roll_yield(1);  -- Tomato
```

---

### award_xp(p_user_id uuid, p_amount integer)

Awards XP, evaluates level thresholds, triggers level-ups, unlocks watering if earned. Handles multiple level-ups from a single large XP grant. Uses `FOR UPDATE` to prevent concurrent level-up races.

**New in MIGRATION008.**

**XP rules:**
- 1 XP per seed earned from offer completion
- XP is NEVER deducted (not on clawbacks, not on bans)
- If fraud confirmed → account banned → XP irrelevant

**Level-up payload** (returned when levels are crossed):
```json
[
  {
    "level": 3,
    "label": "Grower",
    "row_unlock": 4,
    "crop_unlock_id": null,
    "crop_name": null,
    "unlocks_watering": true
  }
]
```

**Returns:** `TABLE(new_xp integer, new_level integer, leveled_up boolean, level_up_data jsonb)`

Flutter consumes `level_up_data` to show level-up modals and trigger row soft-unlocks in the UI.

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM public.award_xp('<user-uuid>', 138);
```

---

### unlock_plot(p_user_id uuid, p_plot_id integer)

User purchases a specific plot. Validates level gate, checks not already unlocked, deducts seeds, logs transaction, inserts into `user_unlocked_plots`.

**New in MIGRATION008.**

**Validations:**
1. User exists
2. Plot ID in range 0–23
3. Plot assigned to a farm row
4. User level ≥ row's `unlock_level`
5. Plot not already in `user_unlocked_plots`
6. User has enough seeds (skipped for free plots where `cost_per_plot = 0`)

**Returns:** `TABLE(success boolean, seeds_spent integer, new_seeds_balance integer, message text)`

**Security:** SECURITY DEFINER

**Usage:**
```sql
SELECT * FROM public.unlock_plot('<user-uuid>', 6);
-- Returns: (true, 100, 400, 'Plot 6 unlocked! 🌱')
```

---

## Referral & Waitlist Functions

### credit_referrer()

Trigger function — fires AFTER INSERT on `public.users` (via `on_user_referral_signup` trigger). Auto-credits referrer when new user signs up with a referral code.

**Tiered rewards:** 1st referral=200 seeds, 2nd=100, 3rd=50, 4th+=25. Logs to `public.referrals`.

**Created:** MIGRATION005

---

### claim_waitlist_bonus(p_user_id uuid)

One-time bonus for waitlist users on first app open.

**Returns:** `(success boolean, seeds_awarded integer, message text)`

**Created:** MIGRATION005 | **Security:** SECURITY DEFINER

---

### get_user_referral_info(p_user_id uuid)

Returns complete referral data for a user including referral history array.

**Returns:** `(referral_code, referral_count, seeds_balance, is_waitlist_user, waitlist_bonus_claimed, referrals jsonb)`

**Created:** MIGRATION005 | **Security:** SECURITY DEFINER

---

### process_email_verification(p_user_id uuid, p_referred_by uuid)

Orchestrator for all email verification rewards. Calls individual bonus functions in sequence.

**Steps:** Mark email verified → `award_signup_bonus()` (+100 seeds) → `award_verification_bonus()` (+50 seeds) → `award_referral_bonus()` to referrer (if referred).

**Returns:** `(success, total_seeds_awarded, breakdown jsonb, message)`

**Example breakdown:**
```json
{
  "signup_bonus": 100,
  "verification_bonus": 50,
  "referral_awarded_to_referrer": 200,
  "referrer_id": "uuid"
}
```

**Created:** MIGRATION006 | **Security:** SECURITY DEFINER

---

### award_signup_bonus(p_user_id uuid)

Awards one-time signup bonus (default 100 seeds). Idempotent — checks for existing `'signup_bonus'` transaction before awarding.

**Created:** MIGRATION006 | **Security:** SECURITY DEFINER

---

### award_verification_bonus(p_user_id uuid)

Awards one-time email verification bonus (default 50 seeds). Also updates `fraud_status` to `'approved'` if still `'pending'`.

**Created:** MIGRATION006 | **Security:** SECURITY DEFINER

---

### award_referral_bonus(p_referrer_id uuid, p_referee_id uuid)

Tiered referral reward. Increments referrer's `referral_count`, determines reward tier, records transaction. Idempotent per referee.

**Returns:** `(success, seeds_awarded, new_balance, referral_number, message)`

**Created:** MIGRATION006 | **Security:** SECURITY DEFINER

---

## Fraud Detection Functions

### check_fraud_signals(p_ip_address, p_email, p_fingerprint_hash)

**⚠️ PLACEHOLDER — not yet implemented.** Returns safe defaults. TODO: integrate IPQS API.

**Returns:** `(risk_score, is_vpn, is_proxy, is_disposable_email, country_code, fraud_status)`

**Created:** MIGRATION006 | **Security:** SECURITY DEFINER

---

## Utility Functions

### get_user_balances(user_id_param uuid)
Returns `(seeds_balance, cash_balance)` for a user. Created in MIGRATION002.

### update_user_seeds(user_id_param uuid, seeds_change integer)
Adds/subtracts seeds from a user's balance. Returns new balance. Created in MIGRATION002.

### update_user_cash(user_id_param uuid, cash_change numeric)
Adds/subtracts cash from a user's balance. Returns new balance. Created in MIGRATION002.

### get_user_transactions(p_user_id, p_limit, p_offset)
Paginated seed transaction history for a user. Created in MIGRATION003.

### cleanup_old_deduplication_records(p_days_to_keep integer)
Deletes `postback_deduplication` records older than N days (default 90). Run via cron. Created in MIGRATION003.

### ~~update_user_progression(user_id_param uuid, xp_change integer)~~
**DROPPED in MIGRATION008.** Was using a broken SQRT-based level formula and referenced old column names. Replaced entirely by `award_xp()`.

---

# Triggers

## on_auth_user_created (Trigger)

**Table:** `auth.users`
**Event:** AFTER INSERT FOR EACH ROW
**Executes:** `handle_new_user()`

Fires on every new signup. Creates `public.users`, farm, starter plots, and demo seeds.

---

## on_user_referral_signup (Trigger)

**Table:** `public.users`
**Event:** AFTER INSERT FOR EACH ROW
**Executes:** `credit_referrer()`

Fires when new user is inserted into `public.users`. If `referred_by` is set, credits the appropriate tiered seed reward to the referrer.

**Created:** MIGRATION005

---

# Migration History

## MIGRATION001 — January 5, 2026
Initial farming tables: `crop_types`, `user_farms`, `crops`, `harvest_history`, `app_config`. Basic RLS and helper views.

## MIGRATION002 — January 5, 2026
Moved `seeds_balance`, `cash_balance`, `user_level`, `total_harvests`, `experience_points` from `user_farms` to `public.users`. Added `get_user_balances()`, `update_user_seeds()`, `update_user_cash()`, `update_user_progression()` (later dropped in M008).

## MIGRATION003 — January 13, 2026
OCG tables: `postback_log`, `postback_deduplication`, `seed_transactions`, `fraud_events`. First version of `process_postback()`. Added RLS on all four tables.

## MIGRATION004 — January 2026
Added `locale` column to `public.users` for ApparenceKit v5 compatibility.

## MIGRATION005 — February 10, 2026
Referral system. Added `referral_code`, `referred_by`, `referral_count`, `is_waitlist_user`, `waitlist_bonus_claimed` to `public.users`. New table `public.referrals`. Functions: `credit_referrer()`, `claim_waitlist_bonus()`, `get_user_referral_info()`. Updated `handle_new_user()`. Views: `top_referrers`, `referral_stats`. Trigger: `on_user_referral_signup`.

## MIGRATION006 — February 12, 2026
Waitlist reward system. New table `public.waitlist_signups`. Functions: `record_seed_transaction()`, `award_signup_bonus()`, `award_verification_bonus()`, `award_referral_bonus()`, `process_email_verification()`, `check_fraud_signals()` (placeholder). Config keys: `signup_bonus_seeds`, `email_verification_bonus_seeds`.

## MIGRATION007 — February 2026
RLS policy overhaul on `public.users` and `public.waitlist_signups` — balance fields now protected against direct client writes. Created `create_waitlist_user_complete()` (server-side user creation for waitlist web app). Created `get_user_id_from_referral_code()`.

## MIGRATION008 — February 25, 2026

### New Tables
- `public.levels` — 10-level progression system
- `public.farm_rows` — 8-row farm layout with plot IDs and unlock costs
- `public.user_unlocked_plots` — per-user plot purchase records

### Modified Tables

**public.users:**
- `user_level` RENAMED → `level`
- `experience_points` RENAMED → `xp`
- ADDED: `watering_unlocked boolean NOT NULL DEFAULT false`
- ADDED: `sprouting_seeds_balance integer NOT NULL DEFAULT 0`

**public.crop_types:**
- DROPPED: `base_yield_percentage`
- ADDED: `unlock_level`, `p1`, `p2`, `p3`, `p4`
- UPDATED seed costs: 25→12 (tomato), 50→24 (eggplant), 100 (corn unchanged), 200 (melon unchanged)
- UPDATED growth times: tomato=4h, eggplant=24h, corn=168h, golden_melon=504h (21 days)

**public.seed_transactions:**
- ADDED: `xp_granted integer NOT NULL DEFAULT 0`

**public.user_farms:**
- `max_plots` default changed from 15 → 6

### Modified Views
- `active_crops_with_details`: dropped `base_yield_percentage`, added `p1–p4`, `unlock_level`, `final_cash_value`, `harvested_at`. Status now computed dynamically.

### New Config Keys
`base_rate`, `payout_rate`, `first_margin_take`, `y1`, `y2`, `y3`, `y4`

### Removed Config Keys
`max_plots_default`, `seeds_to_dollar_rate`

### New Functions
- `roll_yield(p_crop_type_id integer)` — weighted random yield roll
- `award_xp(p_user_id uuid, p_amount integer)` — XP + level-up with payload
- `unlock_plot(p_user_id uuid, p_plot_id integer)` — plot purchase

### Modified Functions
- `handle_new_user()` — uses `level`/`xp` column names
- `create_initial_farm_for_user()` — max_plots=6, inserts plots 0–5 into `user_unlocked_plots`
- `grant_initial_seeds()` — source `'signup_bonus'` → `'demo_seeds'`
- `record_seed_transaction()` — added `p_xp_granted` optional param
- `process_postback()` — source names changed; calls `award_xp()`; returns `xp_granted`
- `test_harvest_crop()` — removed `p_cash_amount` param; calculates internally via `roll_yield()`
- `test_create_crops()` — reads seed cost from `crop_types` dynamically
- `create_waitlist_user_complete()` — uses `level`/`xp` column names

### Dropped Functions
- `update_user_progression(uuid, integer)` — broken SQRT formula; replaced by `award_xp()`

---

# Key Relationships Diagram

```
auth.users (Supabase Auth)
    │
    ├──> public.users (1:1)
    │       ├──> user_farms (1:1)
    │       │       ├──> crops (1:many)
    │       │       └──> harvest_history (1:many)
    │       ├──> user_unlocked_plots (1:many)  ← NEW M008
    │       ├──> seed_transactions (1:many)
    │       ├──> devices (1:many)
    │       ├──> notifications (1:many)
    │       ├──> referrals as referrer (1:many)
    │       ├──> referrals as referee (1:many)
    │       ├──> waitlist_signups (1:1)
    │       └──> users.referred_by (self-referencing)
    │
    ├──> postback_log (1:many)
    ├──> feature_votes (1:many)
    └──> awaiting_feature_requests (1:many)

crop_types (master data)
    ├──> crops (1:many)
    ├──> harvest_history (1:many)
    └──> levels.crop_unlock_id (1:many)   ← NEW M008

farm_rows (reference data)                ← NEW M008
    └──> levels.row_unlock (1:many)
    └──> user_unlocked_plots via plot_id range

levels (reference data)                   ← NEW M008
```

---

# Schema Summary

**Total Tables:** 22 in public schema

| Category | Tables |
|----------|--------|
| Core Game | users, user_farms, crop_types, crops, harvest_history |
| Progression (M008) | levels, farm_rows, user_unlocked_plots |
| Economy | seed_transactions, postback_log, postback_deduplication |
| Referral & Waitlist | referrals, waitlist_signups |
| Security | fraud_events |
| Features | feature_requests, feature_votes, awaiting_feature_requests |
| System | app_config, user_infos, devices, notifications, subscriptions |

**Functions:** 20+ stored procedures
**Views:** 4 (`active_crops_with_details`, `farm_overview`, `top_referrers`, `referral_stats`)
**Triggers:** 2 (`on_auth_user_created`, `on_user_referral_signup`)

---

# Pending TODOs

### High Priority
- [ ] Wire `sprouting_seeds_balance` to OCG pending/confirmed state (Week 3)
- [ ] Implement clawback path in `process_postback()` — fraud_events insert, account flagging
- [ ] Integrate IPQS API into `check_fraud_signals()`
- [ ] Drop stale `test_harvest_crop(uuid, numeric)` overload (old signature with manual cash_amount)
- [ ] Update Flutter testing page to remove `p_cash_amount` arg from `test_harvest_crop` calls

### Medium Priority
- [ ] Build production `harvest_crop()` function (non-test path)
- [ ] Build `plant_crop()` RPC function for Flutter planting flow
- [ ] Set up email verification webhook to call `process_email_verification()`
- [ ] Admin dashboard for fraud review

### Low Priority
- [ ] Scheduled cron job for `cleanup_old_deduplication_records()`
- [ ] Referral vanity URLs
- [ ] Watering mechanics (Phase 2 — see Game Economy Design doc)

---

**Document Control:**
Complete public schema as of February 25, 2026.
Source of truth: SQL migration files M001–M008.
Next update: After OCG live integration (Week 3) or major schema changes.

**Questions or Issues?**
Malcolm — support@megaunlimited.io