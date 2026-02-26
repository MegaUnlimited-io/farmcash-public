# Mega Unlimited LTD - Business Overview

**Last Updated:** February 25, 2026  
**Document Version:** 2.0

---

## Company Structure

**Legal Entity:** Mega Unlimited LTD  
**Jurisdiction:** United Kingdom (Private Limited Company)  
**Registration:** England & Wales  
**Director:** Malcolm Lowry (Based in Berlin, Germany)  
**Business Model:** Mobile application development, publishing, and performance marketing

### Primary Brand/Product
**FarmCash** - Rewarded gaming mobile application for Android and iOS

## Team Background

### Malcolm (Product/Tech Lead) - Solo Dev/Founder
- 15 years performance marketing experience (online advertising, mobile gaming)
- 7 years as Head of User Acquisition at mobile gaming studios (including Next Games, Helsinki)
- Former CEO of gaming project startup and junior product manager at game studios - understands game design, progression systems, timer psychology
- Recently transitioned to full-stack development (Python FastAPI, LangChain, PostgreSQL, Claude Code)
- Deep understanding of UA economics, conversion optimization, tracking, and analytics
- Deep operational understanding of app and web advertising (UA), including creative production, major ad netowrk setup, campaigns setup, budget planning, optimization towards financial goals
- Based in Berlin, Germany
- Operating as solo founder (previous cofounders amicably separated)

---

## Business Description

### Industry & Sector
Mega Unlimited LTD operates in the **mobile app monetization and performance marketing** industry, specifically within the **rewarded advertising** sector. We develop and publish mobile applications that connect users with brand offers through incentivized engagement models.

**Core Industry Categories:**
- Mobile Application Development & Publishing
- Performance Marketing (CPA/CPI)
- Rewarded Advertising Technology
- Consumer Rewards & Loyalty Programs

### What We Do
We build mobile experiences that reward user engagement. Our flagship product, FarmCash, gamifies the rewards experience by allowing users to earn real cash by completing partner offers and tasks. We serve as a bridge between:
1. **Advertisers/Brands** seeking user acquisition and engagement
2. **End Users** looking to earn rewards through app engagement
3. **Technology Partners** providing infrastructure and analytics

---

## Partner Ecosystem

### 1. Reward Networks & Offerwalls
**Type:** Primary revenue and offer supply partners  
**Function:** Provide offers, tasks, and surveys that users can complete for rewards  
**Examples:**
- Prodege / Bitlabs (parent company of Swagbucks, InboxDollars)
- AyeT-Studios (European offerwall network)
- RevU (Revenue Universe - premium offerwall provider)
- AdGate Media
- Pollfish

**Integration:** API-based offerwall and direct integrations

**Long term strategy:** Demonstrate success, onboard direct advertisers (Games, Apps, Surveys, etc.) for our own exclusive offers generating even higher payouts for us and users.

---

### 2. Direct Advertisers
**Type:** Brand and app marketing partners  
**Function:** Commission us directly for user acquisition campaigns  
**Examples:**
- Mobile game developers seeking CPI (Cost Per Install) campaigns
- E-commerce brands offering trial signups
- Subscription services (streaming, SaaS, etc.)
- Financial services (credit cards, banking apps)

**Integration:** Direct CPA/CPI campaigns, custom offer placements

---

### 3. Analytics & Attribution Providers
**Type:** Technology infrastructure partners  
**Function:** Track user behavior, measure engagement, and optimize performance  
**Examples:**
- Mixpanel (user analytics and behavioral tracking)
- Amplitude (product analytics)
- Appsflyer / Adjust (mobile attribution)
- Firebase (Google's app development platform)

**Integration:** SDK-based tracking, event analytics, cohort analysis

---

### 4. Fraud Detection & Security
**Type:** Risk management and compliance partners  
**Function:** Prevent fraud, verify user authenticity, protect platform integrity  
**Examples:**
- IPQS (IPQualityScore - IP/device/user fraud detection)
- SEON (fraud prevention platform)
- Custom internal anti-fraud algorithms

**Integration:** Real-time API verification, device fingerprinting, behavioral analysis

---

### 5. Payment & Payout Infrastructure
**Type:** Financial services partners  
**Function:** Process user cashouts and handle partner settlements  
**Examples:**
- PayPal (user payouts)
- Gift card providers (Amazon, Google Play, etc.)
- Cryptocurrency payment processors (future consideration)

**Integration:** API-based payment processing

---

### 6. Infrastructure & Development Tools
**Type:** Technology stack partners  
**Function:** Host backend services, store data, enable development  
**Examples:**
- Supabase (backend-as-a-service, database)
- Google Cloud Platform / Firebase (notifications only)
- GitHub (version control, CI/CD)

**Integration:** Platform-based services

---

## Product Overview: FarmCash

### Concept
FarmCash is a mobile rewarded gaming app that gamifies earning real cash. Users plant virtual crops by completing offers, nurture them through engagement, and harvest real cash rewards.

### User Journey

#### 1. Acquisition & Onboarding
- User discovers FarmCash via Google Play Store or Apple App Store
- Downloads and installs the application
- Creates account (email/magic link)
- Completes onboarding tutorial

#### 2. Offer Discovery & Engagement
- User browses available offers within the app
- Offers displayed via integrated offerwall partners (Prodege, AyeT, RevU, etc.)
- Offer types include:
  - App installs (download and open new app)
  - Trial signups (subscribe to service)
  - Surveys and polls
  - Game progression (reach level X in partner game)
  
#### 3. Task Completion & Verification
- User selects an offer and completes the required action
- Partner network verifies completion via:
  - Server-to-server postback (received using our proprietary system OCG)
  - We send our userID on first offer click
  - Partners postback when events completed with userID, status, payout and other parameters
- Verification can be:
  - **Instant:** Immediate credit upon completion (can be delayed a few hours depends on advertiser/offer)
  - **Pending:** Requires advertiser validation (1-30 days)
  - **Rejected:** Fraud detected or requirements not met

#### 4. Virtual Currency Crediting
- Upon successful verification, user receives **Seeds** (virtual currency #1)
- Seeds accumulate in user's account
- Users can view:
  - Pending Seeds (awaiting verification)
  - Available Seeds (ready to redeem)
  - Total lifetime earnings

#### 5. Redemption & Payout
- User converts Seeds to real cash through our farming game layer
- Minimum payout threshold: $10 (May change)
- Payout methods:
  - PayPal (first payout method)
  - Gift cards (Amazon, Google Play, etc.)
  - Bank transfer (future)
- Payout processing time: 1-7 business days

---

## Fraud Prevention & User Moderation

### Anti-Fraud Strategy
We implement **aggressive fraud detection and prevention** to protect partner relationships and platform integrity.

### Fraud Detection Measures

#### Real-Time Prevention
- IP address quality scoring (IPQS integration)
- Device fingerprinting and duplicate detection (phase 2: build our own, tools are too expensive)
- VPN/proxy/datacenter IP blocking (IPQS)
- Geolocation verification (IPQS)
- Email history/fraud check (IPQS)
- Suspicious behavior pattern detection (phase 2/3 as we learn fraud patterns)

#### Behavioral Analysis (future)
- Offer completion velocity checks (too fast = suspicious)
- Account age and history verification
- Cross-referencing with known fraud databases
- ML-based anomaly detection (future)
- Multi-account prevention (one user, with multiple accounts)

### User Moderation Actions

#### 1. Account Suspension
**Trigger:** Suspicious activity detected  
**Action:** Temporary freeze on new offer completions and payouts  
**Duration:** Pending manual review (24-72 hours)

#### 2. Payout Delay/Hold
**Trigger:** First-time cashout, high-value redemption, fraud signals  
**Action:** Extended verification period before payout processing  
**Duration:** 7-30 days additional hold

#### 3. Virtual Currency Clawback
**Trigger:** Fraudulent offer completion confirmed after crediting (partners/networks provide this)  
**Action:** Deduct Seeds from user account (even if negative balance) 
**Notification:** User informed of reversal and reason

#### 4. Permanent Ban
**Trigger:** Confirmed fraud, repeat violations, TOS breach  
**Action:** 
- Account permanently disabled
- All pending and available Seeds forfeited
- IP/device blacklisted from future registrations
- No appeal process for egregious violations

#### 5. Graduated Penalties
- **Warning:** First minor violation, educational notice
- **Restrictions:** Reduced earning limits, offer access restrictions
- **Shadowban:** User can complete offers but rewards never credit (for serial abusers)

### User Communication
- Clear Terms of Service explaining prohibited behaviors
- In-app notifications for account status changes
- Support ticket system for appeals (legitimate cases only)
- Transparency in fraud policies (deter bad actors)

---

## Revenue Model

### Primary Revenue Streams

#### 1. Performance Marketing Margins
- Partners pay us CPA/CPI rates for completed offers (All ad networks currently pay per action, not per install)
- We credit users a portion as Seeds (First Margin Take - we take a protective cut of unitial payout)
- **Margin:** Difference between partner payout and user reward
- **Example:** Partner pays $2.00 CPI, user receives $1.20 in Seeds, we retain $0.80. User plants seeds and selects a slower growing crop with higher yield and converts those seeds to $1.35. They get a better yield/ROI for waiting, we get more cashflow.

#### 2. Payout Breakage
- Users who never reach minimum payout threshold
- Accounts banned before redemption
- Expired/abandoned accounts with unredeemed Seeds

#### 3. Premium Features (Future)
- Subscription with better XP, better yields, more farming plots, etc
- Purchase permanent farming plot upgrades to max out plots beyond the leveling cap
- Exclusive high-value offers

### Cost Structure

#### Variable Costs
- User payouts (Variable based on farming yield mechanics) but does not drop below certain margin (on average) thanks to the game economy design.
- Payment processing fees (PayPal, gift cards)
- Fraud detection API costs (IPQS, etc.)
- Cloud hosting (scales with users)


#### Fixed Costs
- Development and maintenance
- Analytics and monitoring tools
- Legal and compliance
- Customer support
- LLM Usage / Subscriptions
---

## Target Markets

### Geographic Focus
**Primary:** United States, United Kingdom, Germany  
**Secondary:** Canada, Australia, France, Spain  
**Future Expansion:** Global (localized versions)

### User Demographics
- **Age:** 18-45 (majority 25-35)
- **Income:** Lower to middle income seeking supplemental earnings
- **Tech Savvy:** Comfortable with mobile apps and online tasks
- **Motivation:** Earn extra cash, discover new apps/services, gaming entertainment

---

## Regulatory & Compliance Considerations

### Data Privacy
- GDPR compliance (EU users)
- CCPA compliance (California users)
- Clear privacy policy and data handling practices
- User consent for data collection and sharing

### Age Restrictions
- Minimum age: 18+ (enforced via signup)
- No targeting or marketing to minors
- Age verification for high-value payouts

### Financial Regulations
- Anti-money laundering (AML) awareness
- Proper tax reporting for user earnings (1099 thresholds in US)
- Transparent terms regarding virtual currency and real money

### Advertising Standards
- Compliance with FTC guidelines on endorsements/testimonials
- Clear disclosure of incentivized actions
- No misleading offers or false advertising

---

## Technology Stack

### Frontend
- **Mobile Apps:** Flutter (Android first, iOS in later phase)
- **Template:** ApparenceKit Pro v5 (lifetime updates)
- **Platform:** Native compilation for optimal performance

### Backend
- **Database:** Supabase (PostgreSQL)
- **Template:** ApparenceKit Pro (lifetime updates)
- **Authentication:** Supabase Auth
- **API:** RESTful APIs, real-time subscriptions
- **Web Hosting:** Github Pages, Cloudflare

### Integrations
- **Offerwall SDKs:** Partner-specific integrations (Prodege, AyeT, RevU)
- **Analytics:** Mixpanel, Firebase (future)
- **Error monitoring:** Sentry.io (future)
- **Fraud Prevention:** IPQS API
- **Payments:** PayPal API, gift card fulfillment APIs

---

## Growth Strategy

### Phase 1: Soft Launch (Current - Month 3)
- Partner integrations complete
- Core app functionality tested
- Limited user acquisition (organic, small paid tests)
- Fraud systems validated
- Establish baseline unit economics

### Phase 2: Scaling (Month 4-12)
- Expand partner relationships
- Optimize user acquisition costs
- Improve payout margins through negotiation
- Enhanced gamification features
- Referral program launch

### Phase 3: Market Leadership (Year 2+)
- Multi-country expansion
- Direct advertiser relationships
- Proprietary fraud ML models
- Additional product verticals (new apps)
- Acquisition or partnership opportunities

---

## Competitive Advantages

1. **Gamified Experience:** Unlike generic offerwall apps, FarmCash provides an engaging game loop
2. **Aggressive Fraud Prevention:** Protects partners, ensures sustainability
3. **Multi-Partner Aggregation:** Best offers from multiple networks in one place
4. **Transparent Economics:** Users understand exactly how they earn
5. **Mobile-First Design:** Optimized UX for smartphone users
6. **Bootstrap-Lean Operations:** Low overhead, sustainable from day one
7. **Highest payouts:** Can we offer highest payouts from longest-duration crops?

---

## Key Performance Indicators (KPIs)

### User Metrics
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- User retention (D1, D7, D30)
- Average revenue per user (ARPU)
- Lifetime value (LTV)

### Business Metrics
- Gross revenue (partner payouts)
- User payout costs
- Gross margin percentage
- Customer acquisition cost (CAC)
- LTV:CAC ratio

### Operational Metrics
- Offer completion rate
- Fraud detection accuracy
- Payout processing time
- Support ticket volume and resolution time
- App store ratings and reviews

---

## Contact Information

**Company:** Mega Unlimited LTD  
**Website:** megaunlimited.io  
**Email:** malcolm@megaunlimited.io  
**Director:** Malcolm Lowry

---

**Document Control:**  
This document serves as the master reference for Mega Unlimited LTD's business operations, partner relationships, and product functionality. It should be referenced when drafting legal documents, partner agreements, privacy policies, and terms of service.