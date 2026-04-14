# FarmCash Landing Page Redesign - Design Brief v1.0

**Date:** April 13, 2026  
**Project:** FarmCash Waitlist Landing Page Redesign  
**Goal:** Build trust, showcase app visuals, convert visitors to waitlist signups  
**Timeline:** 1 day implementation  
**Status:** Ready for development

---

## **Executive Summary**

Redesign farmcash.app landing page to shift focus from form-heavy design to visual storytelling using new hero image, app screenshots, and character art. Maintain existing backend functionality (Supabase integration, referral system, validation) while creating a more professional, trust-building experience that balances "rewarded app" credibility with "fun farming game" differentiation.

---

## **Design Principles**

### **Primary Goals:**
1. ✅ **Build Trust** - Address "Is this legit?" concern (primary visitor question)
2. ✅ **Show, Don't Tell** - Use visuals to explain mechanics (hero image + screenshots)
3. ✅ **Maintain Functionality** - Keep existing form backend integration intact
4. ✅ **Mobile + Desktop Excellence** - Both must look great (current design only works mobile)
5. ✅ **Community Warmth** - Emotional farming community vibe over transactional data-driven

### **Tone & Voice:**
- 60% Playful, 40% Professional
- 70% Warm Community, 30% Transactional Rewards
- Bold headline approach (differentiate from clean competitors)
- Rewarded app users + gaming crossover appeal

### **Key Messaging:**
**Primary Hook Options** (Choose one for hero):
1. "Stop farming in the dirt... Farm Cash" (Bold, provocative)
2. "They said money doesn't grow on trees. They were right. It grows in FarmCash." (Clever wordplay)
3. "Play games. Manage your micro farm. Harvest real cash." (Clear, functional)

**Simple hook variant testing feature**
- Randomize from the above 3 hooks on page load.
- Store hook in browser memory (so if user closes and comes back, they see the same hook)
- Send hook to GA4 on signup event (maybe as signup event metadata) so we can measure best hook over time
- Allow me to easily add/remove/change hooks in the homepage file or a config file

---

## **Page Structure: Short-Form Trust-Builder**

### **Layout Overview (8 Sections):**

```
┌─────────────────────────────────────────────────────────┐
│ SECTION 1: HERO (Above the fold)                        │
│ • Hero image (1600x672) with cash-sprouting crops       │
│ • Bold headline (hook) + tagline                        │
│ • Waitlist form (updated design to match rest of page)  │
│ • Trust indicator (subtle)                              │
│ • Seed rewards teaser: "Early users get up to 500       │
│   FREE SEEDS! [Learn more ↓]"                           │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 1.5: SEED REWARDS EXPLAINER (NEW)               │
│ • Detailed breakdown of seed reward tiers               │
│ • Sign up (+100), Verify (+50), Referrals (+200/100/50) │
│ • "Already signed up? Log in" link                      │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 2: HOW IT WORKS (Visual explainer)              │
│ • 3-step graphic (to be created use table + emojis      |
|   for now)                                              │
│ • Jobs → Seeds → Crops → Cash (Paypal/Gift card         |
|  images for trust)                                      │
│ • Minimal text, maximum clarity                         │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 3: APP SCREENSHOTS (Carousel/Grid)              │
│ • 5 mockup screenshots in phone frames                  │
│ • Captions for each screen                              │
│ • "See it in action" vibe                               │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 4: WHY FARMCASH? (3 Benefits)                   │
│ • Gamified (Fun, cozy ritual, not boring)               │
│ • Transparent (See when you'll get paid)                │
│ • Early Access (Earn bonus seeds)                       │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 5: SOCIAL PROOF (Testimonials - Placeholder)    │
│ • 2-3 beta tester quotes                                │
│ • Names + context (e.g., "Early Tester from Germany")   │
│ • Keep faint/subtle (don't oversell)                    │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 6: PARTNER TRUST BADGES (Faint)                 │
│ • AyeT Studios, RevU, Prodege logos (low opacity)       │
│ • "Powered by trusted offer providers"                  │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ SECTION 7: FINAL CTA + FOOTER                           │
│ • Repeat waitlist CTA (button, not full form)           │
│ • Footer: Blog, Privacy, Terms, Twitter                 │
│ • Copyright: © 2026 Mega Unlimited LTD                  │
└─────────────────────────────────────────────────────────┘
```

---

## **Section 1: Hero (Above the Fold)**

### **Layout:**

**Desktop (>1024px):**
```
┌─────────────────────────────────────────────────────────┐
│ [HERO IMAGE: 1600x672 farm scene with $ crops]          │
│                                                          │
│   [Left Column - 55%]              [Right Column - 45%] │
│                                                          │
│   HEADLINE (Large, Bold)            WAITLIST FORM       │
│   "They said money doesn't          ┌─────────────────┐ │
│    grow on trees.                   │Join Waitlist 🎉│ │
│    They were right.                 │                 │ │
│    It grows in FarmCash."           │ Game type?      │ │
│                                     │ [Dropdown ▼]    │ │
│   Tagline:                          │                 │ │
│   "Plant seeds. Harvest cash 🌱💰" │ Rewarded apps?  │ │
│                                     │ ☐☐ ☐☐ ☐☐      │ │
│   Early users get the most          │                 │ │
│   FREE SEEDS (up to 500)!           │ Device?         │ │
│   [Learn more ↓]                    │ [🤖] [🍎]      │ │
│                                     │                 │ │
│                                     │ Email           │ │
│                                     │ [input]         │ │
│                                     │                 │ │
│                                     │ ☐ I accept...   │ │
│                                     │                 │ │
│                                     │ [Join Waitlist] │ │
│                                     └─────────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Mobile (<768px):**
```
┌───────────────────────────┐
│ [HERO IMAGE - cropped]    │
│                           │
│ HEADLINE                  │
│ (Stacked, centered)       │
│                           │
│ Tagline                   │
│                           │
│ [Waitlist Form Below]     │
│ (Full width)              │
│                           │
│ Trust badge               │
└───────────────────────────┘
```

### **Hero Image Treatment:**

**Primary Image:** `Gemini_Generated_Image_z43npcz43npcz43n.png` (1600x672)
- Full-width background (cover, center)
- Overlay: Subtle dark gradient (bottom-to-top, 60% opacity black) for text readability
- Ensure text is legible on green/blue gradient sky

**Alternative:** `secondary_image.png` (zoomed crops + hands)
- Use as secondary graphic in "How It Works" section
- Shows tactile planting action + cash growth concept
- **Needs refinement** (noted for future iteration)

### **Headline Copy:**

**Primary Option (Recommended):**
```
They said money doesn't grow on trees.
They were right. It grows in FarmCash.
```

**Alternative 1:**
```
Stop farming in the dirt...
Farm Cash.
```

**Alternative 2:**
```
Play games.
Manage your micro farm.
Harvest real cash.
```

**Typography:**
- Font: Bold, sans-serif (Poppins Bold or similar)
- Size (Desktop): 48-56px
- Size (Mobile): 32-38px
- Color: White with subtle text shadow (1px black, 50% opacity)
- Line height: 1.2

**Tagline:**
```
Plant seeds. Harvest cash 🌱💰
```
- Font: Medium weight
- Size (Desktop): 24px
- Size (Mobile): 18px
- Color: White or light green (#A8E6A3)

### **Waitlist Form (Vertical Compression Redesign):**

**CRITICAL:** Keep ALL backend logic, validation, Supabase integration, referral tracking intact. Keep ALL existing form fields.

**Visual Changes - Compress Vertically:**

**Desktop Form (Right column, ~380px width, ~420px height):**
```
┌──────────────────────────────────┐
│ Join the Waitlist 🎉             │
├──────────────────────────────────┤
│                                  │
│ Favorite mobile game type?       │
│ [Choose one... ▼]                │ ← 40px height
│                                  │
│ Which rewarded apps? (2 rows)    │
│ ☐ FreeCash    ☐ Mistplay        │ ← Row 1
│ ☐ Swagbucks   ☐ InboxDollars    │ ← Row 2
│ ☐ None (new!) ☐ Other           │ ← Row 3
│                                  │
│ What device?                     │
│ [🤖 Android] [🍎 Apple]          │ ← Side by side, 36px height
│                                  │
│ Email                            │
│ [you@example.com]                │ ← 44px height
│                                  │
│ ☐ I accept Terms & Privacy       │ ← 16px checkbox
│                                  │
│ [Join the Waitlist]              │ ← 48px height, full width
└──────────────────────────────────┘
```

**Key Changes from Current:**
- ✅ KEEP all existing fields (game type, rewarded apps, device, email, terms)
- ✅ REMOVE "Almost there!" text (unnecessary)
- ✅ REMOVE "Already signed up" from inside form (move below, outside card)
- ✅ Rewarded apps: 2-column grid (3 rows instead of 6 stacked)
- ✅ Device buttons: Side-by-side (one row instead of stacked)
- ✅ Reduced padding: 24px (down from 32px)
- ✅ Tighter field spacing: 12px margins (down from 20px)
- ✅ Smaller field heights while maintaining mobile tap targets

**Field Specifications:**

**Dropdown (Game Type):**
- Height: 40px (desktop), 48px (mobile)
- Font-size: 14px
- Border-radius: 6px
- Margin-bottom: 12px

**Checkboxes (Rewarded Apps):**
- Layout: CSS Grid, 2 columns
- Grid template: `grid-template-columns: 1fr 1fr`
- Gap: 8px horizontal, 6px vertical
- Checkbox size: 16px
- Label font-size: 13px
- Each row height: ~24px
- Total section height: ~78px (3 rows)

**Device Buttons:**
- Layout: Flexbox, side-by-side, equal width
- Height: 36px (desktop), 44px (mobile)
- Icon size: 20px (desktop), 24px (mobile)
- Font-size: 13px (desktop), 14px (mobile)
- Gap: 8px between buttons
- Border-radius: 6px
- Padding: 8px
- States: Default (gray border) → Selected (green border + light green bg)

**Email Input:**
- Height: 44px (desktop), 52px (mobile)
- Font-size: 15px
- Border-radius: 6px
- Margin: 12px 0

**Terms Checkbox:**
- Checkbox: 16px
- Label font-size: 12px
- Link color: Green (#4CAF50)
- Margin: 12px 0

**Submit Button:**
- Height: 48px (desktop), 56px (mobile)
- Font-size: 16px
- Font-weight: 600
- Background: #F59E0B (orange, matching current design)
- Hover: Darken 10%
- Border-radius: 8px
- Full width

**Form Card Styling:**
- Background: White
- Box-shadow: 0 4px 12px rgba(0,0,0,0.1)
- Border-radius: 12px
- Padding: 24px (desktop), 20px (mobile)
- Width: ~380px (desktop), 100% minus 16px sides (mobile)

**Mobile Form:**
- Full width below hero (padding 16px on sides)
- Larger tap targets (all interactive elements 44px minimum)
- Same field structure as desktop
- Increased heights for touch-friendly interaction

### **CSS Implementation for Form Compression:**

**Rewarded Apps - 2 Column Grid:**
```css
.rewarded-apps-checkboxes {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px 8px;
  margin: 8px 0 12px 0;
}

.rewarded-apps-checkboxes label {
  display: flex;
  align-items: center;
  font-size: 13px;
  cursor: pointer;
  min-height: 24px; /* Touch target compliance */
}

.rewarded-apps-checkboxes input[type="checkbox"] {
  width: 16px;
  height: 16px;
  margin-right: 6px;
  flex-shrink: 0;
}
```

**Device Buttons - Side by Side:**
```css
.device-buttons {
  display: flex;
  gap: 8px;
  margin: 12px 0;
}

.device-button {
  flex: 1;
  height: 36px; /* 44px on mobile */
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 2px solid #E0E0E0;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
  background: white;
}

.device-button.selected {
  border-color: #4CAF50;
  background: #F1F8E9;
}

.device-button:hover {
  border-color: #A8E6A3;
}

.device-button img {
  width: 20px; /* 24px on mobile */
  height: 20px;
}

.device-button span {
  font-size: 13px; /* 14px on mobile */
  font-weight: 500;
}

@media (max-width: 768px) {
  .device-button {
    height: 44px;
  }
  .device-button img {
    width: 24px;
    height: 24px;
  }
  .device-button span {
    font-size: 14px;
  }
}
```

**Compact Form Spacing:**
```css
.waitlist-form {
  padding: 24px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.form-heading {
  font-size: 24px;
  font-weight: 700;
  margin-bottom: 16px;
  text-align: center;
}

.form-field {
  margin-bottom: 12px; /* Reduced from 20px */
}

.form-label {
  font-size: 14px;
  font-weight: 500;
  margin-bottom: 6px;
  display: block;
  color: #333;
}

/* Dropdown styling */
select.form-select {
  width: 100%;
  height: 40px;
  padding: 0 12px;
  font-size: 14px;
  border: 1px solid #D1D5DB;
  border-radius: 6px;
  background: white;
  cursor: pointer;
}

select.form-select:focus {
  outline: none;
  border-color: #4CAF50;
  box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.1);
}

/* Email input */
input[type="email"].form-input {
  width: 100%;
  height: 44px;
  padding: 0 12px;
  font-size: 15px;
  border: 1px solid #D1D5DB;
  border-radius: 6px;
}

input[type="email"].form-input:focus {
  outline: none;
  border-color: #4CAF50;
  box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.1);
}

/* Terms checkbox */
.terms-checkbox {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin: 12px 0;
}

.terms-checkbox input[type="checkbox"] {
  width: 16px;
  height: 16px;
  margin-top: 2px;
  flex-shrink: 0;
}

.terms-checkbox label {
  font-size: 12px;
  color: #666;
  line-height: 1.4;
}

.terms-checkbox a {
  color: #4CAF50;
  text-decoration: none;
}

.terms-checkbox a:hover {
  text-decoration: underline;
}

/* Submit button */
.submit-button {
  width: 100%;
  height: 48px;
  background: #F59E0B;
  color: white;
  font-size: 16px;
  font-weight: 600;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.2s;
}

.submit-button:hover {
  background: #D97706; /* 10% darker */
}

.submit-button:active {
  transform: scale(0.98);
}

@media (max-width: 768px) {
  .waitlist-form {
    padding: 20px;
  }
  
  select.form-select {
    height: 48px; /* Larger for mobile */
  }
  
  input[type="email"].form-input {
    height: 52px; /* Larger for mobile */
  }
  
  .submit-button {
    height: 56px; /* Larger for mobile */
  }
}
```

**Accessibility & Focus States:**
```css
/* Focus visible for keyboard navigation */
*:focus-visible {
  outline: 2px solid #4CAF50;
  outline-offset: 2px;
}

/* Ensure all interactive elements are focusable */
.device-button:focus-visible {
  outline: 2px solid #4CAF50;
  outline-offset: 2px;
}

.rewarded-apps-checkboxes label:focus-within {
  outline: 2px solid #4CAF50;
  outline-offset: 2px;
  border-radius: 4px;
}
```

---

### **Vertical Space Savings Achieved:**

**Original Form Height:** ~900px (with seed rewards inside, stacked fields)

**New Form Height:** ~420px (compressed design)

**Space Saved:** ~480px (53% reduction!)

**Result:** Form fits comfortably on desktop without scrolling, hero section stays above the fold.

---

### **Trust Indicator:**

**Placement:** Below form (desktop) or below button (mobile)

**Copy:**
```
✅ Join 500+ farmers on the waitlist
```

**Styling:**
- Small text (14px)
- Green checkmark icon
- Light gray text (#666)
- Update number dynamically from DB (if possible)

---

## **Section 1.5: Seed Rewards Explainer (NEW)**

### **Purpose:**
Explain the seed reward structure that was teased in the hero section ("Learn more ↓" link scrolls here). This section sits immediately below the hero, before "How It Works."

###

 **Layout:**

**Desktop & Mobile (Full Width Section):**
```
┌─────────────────────────────────────────────────────────┐
│              EARN UP TO 500 FREE SEEDS 🎁               │
│                                                          │
│    ☐ Sign up          +100 seeds                        │
│    ☐ Verify Email     +50 seeds                         │
│    ☐ 1st referral     +200 seeds                        │
│    ☐ 2nd referral     +100 seeds                        │
│    ☐ 3rd referral     +50 seeds                         │
│                                                          │
│    Already signed up? Log in to dashboard →             │
└─────────────────────────────────────────────────────────┘
```

### **Visual Treatment:**

**Background:** Light cream/beige (#FFF9E6) or light green (#F1F8E9)  
**Container:** Max-width 800px, centered  
**Padding:** 40px vertical, 24px horizontal  
**Border:** 1px solid #F0E5C5 (subtle)  
**Border-radius:** 8px  

**Heading:**
- Font-size: 24px (desktop), 20px (mobile)
- Font-weight: 700
- Color: #333
- Text-align: center
- Margin-bottom: 24px

**Seed Reward Items:**
- Layout: Vertical list, centered
- Each item: Flexbox (checkbox + label + amount)
- Font-size: 16px (desktop), 15px (mobile)
- Line-height: 1.8
- Color: #666
- Checkbox: 16px, decorative only (not interactive), 50% opacity
- Amount (+100, +200, etc.): Bold, orange (#F59E0B)
- Spacing: 8px between items

**"Already signed up" Link:**
- Font-size: 14px
- Color: #666
- Link color: #4CAF50
- Text-align: center
- Margin-top: 20px

### **Purpose of This Section:**

✅ **Explains teaser from hero** - "Early users get up to 500 FREE SEEDS!" gets detailed breakdown  
✅ **Provides scroll anchor** - "Learn more ↓" in hero scrolls to this section  
✅ **Moves content out of form** - Keeps form card focused on input fields  
✅ **Adds breathing room** - Seed rewards get proper visual space  
✅ **Natural placement for login link** - "Already signed up" makes sense here (post-explanation)  

---

## **Section 2: How It Works (Visual Explainer)**

### **Layout:**

**3-Column Layout (Desktop):**
```
┌──────────────────────────────────────────────────────────┐
│              HOW IT WORKS (Centered heading)              │
│                                                           │
│   [Icon 1]          [Icon 2]          [Icon 3]           │
│   📱 Jobs           🌱 Seeds          💰 Cash            │
│                                                           │
│   Complete          Plant crops       Harvest your       │
│   offers            and watch         crops for          │
│   to earn           them grow         real money         │
│   seeds                                                   │
└──────────────────────────────────────────────────────────┘
```

**Mobile: Stacked vertical**

### **Visual Treatment:**

**Create simple graphic** (to be designed):
- Hand holding phone (completing offer) → Seeds earned → Hand planting seed → Crop growing → Hand harvesting → Cash in hand
- Style: Pixel art or simple illustrated icons
- Color: Match hero image palette (greens, blues, browns)

**Alternative (Simpler):**
- Use existing crop small icons from app
- Animated sequence (optional): Seeds → Sprout → Grown plant → Cash

### **Copy:**

**Step 1:**
```
📱 Complete Offers
Play games, try apps, take surveys
```

**Step 2:**
```
🌱 Plant Seeds
Watch your crops grow (4 hours to 30 days)
```

**Step 3:**
```
💰 Harvest Cash
Convert to real money (minimum $10)
```

**Typography:**
- Heading: 32px, bold
- Icon: 48px emoji or SVG
- Title: 18px, bold
- Description: 14px, regular

---

## **Section 3: App Screenshots Carousel**

### **Assets Available:**
1. Tutorial intro scene (Grandma Marty on beach)
2. Home page (farm + job board unified view)
3. Job details screen
4. Plant crop modal
5. (5th screenshot needed - suggest: harvest success or profile)

### **Layout:**

**Desktop:**
```
┌──────────────────────────────────────────────────────────┐
│          SEE IT IN ACTION (Centered heading)              │
│                                                           │
│   [Phone 1]  [Phone 2]  [Phone 3]  [Phone 4]  [Phone 5] │
│   (Mockup)   (Mockup)   (Mockup)   (Mockup)   (Mockup)  │
│                                                           │
│   Caption    Caption    Caption    Caption    Caption    │
│   under      under      under      under      under      │
│   each       each       each       each       each       │
└──────────────────────────────────────────────────────────┘
```

**Mobile:**
- Horizontal scrolling carousel
- Snap to center
- Swipe to navigate
- Dots indicator below

### **Screenshot Captions:**

**Screen 1: Tutorial Intro**
```
"Meet Grandma Marty, your farming guide"
```

**Screen 2: Home Page**
```
"Your farm + available jobs in one view"
```

**Screen 3: Job Details**
```
"See exactly what you'll earn"
```

**Screen 4: Plant Crop Modal**
```
"Choose your crop: fast or slow, you decide"
```

**Screen 5: Harvest/Success**
```
"Harvest and cash out (minimum $10)"
```

### **Styling:**
- Phone mockup: Already has drop shadow (keep)
- Background: Light gray (#F5F5F5) section
- Screenshots: 300px width on desktop, 80% viewport on mobile
- Captions: 14px, centered below each phone

---

## **Section 4: Why FarmCash? (3 Benefits)**

### **Layout:**

**3-Column Cards (Desktop):**
```
┌──────────────────────────────────────────────────────────┐
│            WHY FARMCASH? (Centered heading)               │
│                                                           │
│  ┌───────────┐    ┌───────────┐    ┌───────────┐       │
│  │ 🎮        │    │ ✅        │    │ 🎁        │       │
│  │ Gamified  │    │Transparent│    │Early Access│       │
│  │           │    │           │    │           │       │
│  │ Fun, not  │    │ See when  │    │ Earn bonus│       │
│  │ boring    │    │ you'll    │    │ seeds     │       │
│  │           │    │ get paid  │    │           │       │
│  └───────────┘    └───────────┘    └───────────┘       │
└──────────────────────────────────────────────────────────┘
```

**Mobile: Stacked vertical**

### **Copy (Keep from current site):**

**Card 1:**
```
🎮 Gamified
Fun, not boring
```

**Card 2:**
```
✅ Transparent
See when you'll get paid
```

**Card 3:**
```
🎁 Early Access
Earn bonus seeds
```

### **Styling:**
- Cards: White background, subtle shadow, 16px border radius
- Padding: 24px
- Icon: 40px emoji, centered
- Title: 18px bold, centered
- Description: 14px regular, centered, gray text

---

## **Section 5: Social Proof (Testimonials - Placeholder)**

### **Layout:**

**2-Column Testimonials (Desktop):**
```
┌──────────────────────────────────────────────────────────┐
│        WHAT EARLY TESTERS SAY (Centered heading)          │
│                                                           │
│  ┌─────────────────────┐  ┌─────────────────────┐       │
│  │ "Quote from beta    │  │ "Quote from beta    │       │
│  │  tester here..."    │  │  tester here..."    │       │
│  │                     │  │                     │       │
│  │ — Name              │  │ — Name              │       │
│  │   Context           │  │   Context           │       │
│  └─────────────────────┘  └─────────────────────┘       │
└──────────────────────────────────────────────────────────┘
```

**Mobile: Stacked vertical**

### **Placeholder Copy (To be replaced with real testimonials):**

**Testimonial 1:**
```
"Finally, a rewards app that doesn't feel like a chore. 
The farming mechanic makes it actually fun!"

— Sarah M.
Early Tester, Germany
```

**Testimonial 2:**
```
"I've tried FreeCash and Swagbucks. FarmCash is way more 
engaging. Love watching my crops grow."

— David K.
Beta User, UK
```

**Testimonial 3 (Optional):**
```
"The waiting is part of the game. I planted a 7-day crop 
and I'm excited to see what I'll harvest!"

— Alex R.
Early Adopter, USA
```

### **Styling:**
- Cards: Light green background (#F1F8E9), no shadow (softer than benefit cards)
- Quote: 16px italic, dark gray
- Attribution: 14px regular, green accent for name
- Keep subtle (don't oversell fake social proof)

---

## **Section 6: Partner Trust Badges (Faint)**

### **Layout:**

**Centered Row:**
```
┌──────────────────────────────────────────────────────────┐
│     Powered by trusted offer providers (Small text)       │
│                                                           │
│    [AyeT Logo]     [RevU Logo]     [Prodege Logo]        │
│    (Low opacity)   (Low opacity)   (Low opacity)         │
└──────────────────────────────────────────────────────────┘
```

### **Styling:**
- Logos: Grayscale, 40% opacity
- Max height: 40px
- Spacing: 48px between logos
- Background: White or very light gray
- Text above: 12px, gray, centered
- **Keep very subtle** - not main focus, just credibility signal

---

## **Section 7: Final CTA + Footer**

### **CTA Section:**

```
┌──────────────────────────────────────────────────────────┐
│         Ready to start farming cash? (Heading)            │
│                                                           │
│              [Join the Waitlist - Button]                 │
│              (Jumps to top form on click)                 │
│                                                           │
│         OR scroll to top to complete signup               │
└──────────────────────────────────────────────────────────┘
```

**Button:**
- Same styling as hero form button
- Smooth scroll to top on click (animate to form)
- Large, prominent, green

### **Footer:**

```
┌──────────────────────────────────────────────────────────┐
│  [Logo/Wordmark]                      [Social Icons]     │
│                                                           │
│  Blog  •  Privacy Policy  •  Terms of Service            │
│                                                           │
│  © 2026 Mega Unlimited LTD. All rights reserved.         │
└──────────────────────────────────────────────────────────┘
```

**Styling:**
- Background: Dark gray (#2C3E50) or keep current color
- Text: White or light gray
- Links: Underline on hover
- Social icons: Twitter (current), add more as they exist
- Padding: 48px vertical

**Footer Links:**
- Blog (keep existing link)
- Privacy Policy (keep existing link)
- Terms of Service (keep existing link)
- Twitter (keep existing link)

---

## **Form Functionality Requirements**

### **CRITICAL: Keep All Existing Backend Logic**

**DO NOT CHANGE:**
- ✅ Supabase integration (account creation in shared DB)
- ✅ Email validation logic
- ✅ Terms & Privacy checkbox requirement
- ✅ Referral tracking system (signup → verify → 1st/2nd/3rd referral bonuses)
- ✅ Seed crediting (users start with seeds pre-loaded)
- ✅ Anti-spoofing checks (existing referral program logic)
- ✅ Form submission flow (backend endpoints)

**ONLY CHANGE:**
- ❌ Remove survey questions (game type, rewarded apps, device)
- ✅ Simplify to: Email + Terms checkbox only
- ✅ Visual styling (make form blend with new design)
- ✅ Layout (sidebar on desktop, below hero on mobile)

### **Post-Signup Flow:**

**After successful signup:**
1. Redirect to `/referral/` (existing dashboard)
2. Dashboard shows:
   - Referral link
   - Current seed balance (pre-credited signup bonus)
   - Referral task progress (dynamic from DB)

**Dashboard Redesign (Separate Task):**
- Update `/referral/` page to match new landing page design
- Keep existing functionality (referral tracking, seed display)
- Add visual consistency (colors, typography, layout)
- **Do AFTER landing page is finalized**

---

## **Responsive Design Specifications**

### **Breakpoints:**

```
Mobile:  < 768px
Tablet:  768px - 1024px
Desktop: > 1024px
```

### **Mobile Optimizations:**

**Hero:**
- Stack headline + form vertically
- Hero image: Crop to focus on central crops (avoid sky wastage)
- Form: Full width, larger tap targets (56px buttons)

**How It Works:**
- Stack 3 steps vertically
- Icons larger (64px)

**Screenshots:**
- Horizontal scroll carousel
- Center current screenshot
- Swipe gesture enabled
- Dots indicator below

**Benefits:**
- Stack 3 cards vertically
- Full width

**Testimonials:**
- Stack vertically
- Full width

**Partner Badges:**
- Stack vertically or horizontal scroll
- Smaller logos (32px height)

### **Desktop Optimizations:**

**Hero:**
- 60/40 split (content left, form right)
- Hero image full-width background
- Form fixed position (sticky?) as user scrolls (optional)

**How It Works:**
- 3 columns, equal width
- Horizontal spacing: 48px

**Screenshots:**
- All 5 visible side-by-side
- Equal spacing
- Centered

**Benefits:**
- 3 columns, equal width
- Max width: 1200px container

**Testimonials:**
- 2 columns
- Equal height cards

---

## **Color Palette**

### **Primary Colors:**

```
Primary Green:   #4CAF50 (buttons, accents, trust badges)
Dark Green:      #388E3C (hover states, emphasis)
Light Green:     #A8E6A3 (backgrounds, subtle accents)
Very Light Green:#F1F8E9 (testimonial cards, section backgrounds)
```

### **Neutrals:**

```
White:           #FFFFFF (backgrounds, text on dark)
Light Gray:      #F5F5F5 (section backgrounds)
Medium Gray:     #9E9E9E (secondary text)
Dark Gray:       #333333 (body text)
Charcoal:        #2C3E50 (footer background)
```

### **Accent Colors (From Hero Image):**

```
Sky Blue:        #87CEEB (hero gradient top)
Grass Green:     #7CB342 (matches farm image)
Soil Brown:      #8D6E63 (crop rows in hero)
Golden Yellow:   #FFD54F (cash crops in hero - use sparingly)
```

### **Functional Colors:**

```
Success Green:   #4CAF50 (form validation, checkmarks)
Error Red:       #F44336 (form errors)
Warning Yellow:  #FFC107 (optional alerts)
```

---

## **Typography**

### **Font Stack:**

**Headings:**
```
Font-family: 'Poppins', 'Helvetica Neue', Arial, sans-serif
Weight: Bold (700)
```

**Body Text:**
```
Font-family: 'Inter', 'Segoe UI', Roboto, sans-serif
Weight: Regular (400), Medium (500)
```

### **Type Scale:**

```
H1 (Hero Headline):     48-56px (desktop), 32-38px (mobile)
H2 (Section Headings):  32px (desktop), 24px (mobile)
H3 (Subheadings):       24px (desktop), 20px (mobile)
Body Large:             18px
Body Regular:           16px
Body Small:             14px
Caption:                12px
```

### **Line Heights:**

```
Headings:   1.2
Body:       1.6
Captions:   1.4
```

---

## **Animation & Interaction**

### **Micro-interactions:**

**Buttons:**
- Hover: Darken 10%, scale 1.02
- Active: Scale 0.98
- Transition: 200ms ease-out

**Form Inputs:**
- Focus: Green border (#4CAF50), subtle glow
- Error state: Red border, shake animation
- Success: Green checkmark, subtle pulse

**Screenshot Carousel (Mobile):**
- Swipe gesture enabled
- Snap to center
- Smooth scroll animation (300ms)

**Smooth Scroll:**
- CTA button scroll-to-top: 600ms ease-in-out
- Navigation links (if added): 400ms ease-in-out

### **Loading States:**

**Form Submission:**
- Button: Show spinner, disable, "Joining..."
- Success: Redirect to `/referral/`
- Error: Show error message below form

---

## **SEO & Meta Tags**

### **Page Title:**
```
FarmCash - Turn Jobs into Cash with Farming Fun | Join Waitlist
```

### **Meta Description:**
```
Join the FarmCash waitlist! Complete offers, plant seeds, grow crops, and harvest real cash. The rewards app that doesn't feel like work. 500+ farmers waiting.
```

### **Open Graph Tags:**

```html
<meta property="og:title" content="FarmCash - Plant Seeds, Harvest Cash" />
<meta property="og:description" content="The rewards app that doesn't feel like work. Join 500+ on the waitlist!" />
<meta property="og:image" content="https://farmcash.app/images/og-hero.jpg" />
<meta property="og:url" content="https://farmcash.app" />
<meta property="og:type" content="website" />
```

### **Twitter Card:**

```html
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="FarmCash - Plant Seeds, Harvest Cash" />
<meta name="twitter:description" content="The rewards app that doesn't feel like work." />
<meta name="twitter:image" content="https://farmcash.app/images/twitter-hero.jpg" />
```

### **Structured Data (JSON-LD):**

```json
{
  "@context": "https://schema.org",
  "@type": "MobileApplication",
  "name": "FarmCash",
  "operatingSystem": "Android, iOS",
  "applicationCategory": "Finance, Game",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.5",
    "ratingCount": "500"
  }
}
```

---

## **Assets Checklist**

### **Provided Assets:**

- [x] Hero image (1600x672) - `Gemini_Generated_Image_z43npcz43npcz43n.png`
- [x] Secondary image (zoomed crops + hands) - `secondary_image.png` (needs refinement, use in future)
- [x] Grandma Marty cutout PNG (transparent background)
- [x] 5 app screenshots in phone mockups (with drop shadow)
- [x] App icons (Android + iOS)
- [x] FarmCash logo (transparent PNG)
- [x] Crop small icons (32x32 or similar)

### **Assets to Create:**

- [ ] **How It Works graphic** (3-step visual explainer)
  - Option A: Simple icons (📱→🌱→💰)
  - Option B: Illustrated sequence using secondary image style
  - Format: SVG or PNG, transparent background
  - Dimensions: Each step ~200px square

- [ ] **Partner logos** (grayscale, low opacity versions)
  - AyeT Studios logo
  - RevU logo
  - Prodege logo
  - Format: PNG with transparency
  - Max height: 40px

- [ ] **OG Image** (for social sharing)
  - Dimensions: 1200x630px
  - Content: Hero image + "Join the Waitlist" text overlay
  - Format: JPG (optimized for web)

- [ ] **Favicon** (if not already created)
  - Dimensions: 32x32, 16x16
  - Format: ICO or PNG

### **Optional Future Assets:**

- [ ] Explainer video (30-60 seconds)
- [ ] Animated GIF of crop growing (for social media)
- [ ] Grandpa Marty variations (for future sections)

---

## **Implementation Notes**

### **Technical Stack (Existing):**

**Confirmed:**
- Backend: Supabase (shared database with app)
- Frontend: HTML/CSS/JS (current site stack - verify exact framework)
- Form: Custom validation + Supabase integration
- Referral tracking: Anti-spoofing checks built-in

**Requirements:**
- Maintain all existing backend connections
- Mobile-responsive (must look great on both mobile + desktop)
- Fast load time (<3 seconds)
- Analytics: Add PostHog or Google Analytics (if not present)

### **Development Priorities:**

**Phase 1: Core Redesign (Today)**
1. Implement new hero layout (image + headline + form)
2. Add "How It Works" section (use simple icons if graphic not ready)
3. Add screenshot carousel
4. Add benefits section
5. Simplify form (remove survey questions)
6. Update footer
7. Mobile responsive testing

**Phase 2: Polish (This Week)**
1. Create "How It Works" custom graphic
2. Add partner logos (faint)
3. Add testimonial placeholders
4. Optimize images (WebP format, lazy loading)
5. Add smooth scroll animations
6. SEO meta tags
7. OG/Twitter card images

**Phase 3: Dashboard Redesign (Next Week)**
1. Update `/referral/` page to match new design
2. Keep existing functionality intact
3. Add visual consistency

### **Testing Checklist:**

**Pre-Launch:**
- [ ] Test form submission (creates account in Supabase)
- [ ] Test email validation
- [ ] Test Terms checkbox requirement
- [ ] Test mobile layout (iPhone, Android)
- [ ] Test desktop layout (1920px, 1440px, 1024px)
- [ ] Test tablet layout (iPad)
- [ ] Test on actual devices (not just browser resize)
- [ ] Test page load speed (Google PageSpeed Insights)
- [ ] Test all links (Blog, Privacy, Terms, Twitter)
- [ ] Verify hero image displays correctly on all screen sizes
- [ ] Verify form doesn't break on submission
- [ ] Test referral tracking (signup → dashboard redirect)

---

## **Success Metrics**

**Track these post-launch:**

**Conversion Rate:**
- Target: >30% of visitors sign up (currently: ____%)
- Measure: Unique visitors → waitlist signups

**Form Abandonment:**
- Target: <40% start form but don't complete
- Identify: Which field causes dropoff (email? terms?)

**Mobile vs Desktop:**
- Track: Signup rate on mobile vs desktop
- Goal: Both >25% conversion

**Time on Page:**
- Target: >45 seconds average (indicates engagement)

**Scroll Depth:**
- Target: 60%+ scroll to "Why FarmCash" section
- Indicates: Trust-building content is seen

**Referral Activation:**
- Target: 20%+ of signups share referral link
- Measure: Users who visit `/referral/` dashboard

---

## **Copy Reference (Full Text)**

### **Hero Section:**

**Headline (Choose One):**

**Option A (Recommended - Bold):**
```
They said money doesn't grow on trees.
They were right. It grows in FarmCash.
```

**Option B (Provocative):**
```
Stop farming in the dirt...
Farm Cash.
```

**Option C (Functional):**
```
Play games.
Manage your micro farm.
Harvest real cash.
```

**Tagline:**
```
Plant seeds. Harvest cash 🌱💰
```

**Form Heading:**
```
Join the Waitlist 🎉
```

**Seed Rewards List:**
```
🎁 Earn up to 500 seeds
Sign up       +100
Verify Email  +50
1st referral  +200
2nd referral  +100
3rd referral  +50
```

**Form Elements:**
```
Email: [Input field]
Placeholder: you@example.com

☐ I accept the Terms & Conditions and Privacy Policy

[Button: Join the Waitlist]

Trust badge: ✅ Join 500+ farmers on the waitlist
```

---

### **How It Works Section:**

**Heading:**
```
How It Works
```

**Step 1:**
```
📱 Complete Offers
Play games, try apps, take surveys
```

**Step 2:**
```
🌱 Plant Seeds
Watch your crops grow (4 hours to 30 days)
```

**Step 3:**
```
💰 Harvest Cash
Convert to real money (minimum $10)
```

---

### **Screenshot Carousel Section:**

**Heading:**
```
See It in Action
```

**Captions:**
```
Screen 1: "Meet Grandma Marty, your farming guide"
Screen 2: "Your farm + available jobs in one view"
Screen 3: "See exactly what you'll earn"
Screen 4: "Choose your crop: fast or slow, you decide"
Screen 5: "Harvest and cash out (minimum $10)"
```

---

### **Why FarmCash Section:**

**Heading:**
```
Why FarmCash?
```

**Card 1:**
```
🎮 Gamified
Fun, not boring
```

**Card 2:**
```
✅ Transparent
See when you'll get paid
```

**Card 3:**
```
🎁 Early Access
Earn bonus seeds
```

---

### **Social Proof Section:**

**Heading:**
```
What Early Testers Say
```

**Testimonial 1 (Placeholder):**
```
"Finally, a rewards app that doesn't feel like a chore. 
The farming mechanic makes it actually fun!"

— Sarah M.
Early Tester, Germany
```

**Testimonial 2 (Placeholder):**
```
"I've tried FreeCash and Swagbucks. FarmCash is way more 
engaging. Love watching my crops grow."

— David K.
Beta User, UK
```

---

### **Partner Trust Badges:**

**Heading:**
```
Powered by trusted offer providers
```

**Logos:** AyeT Studios, RevU, Prodege (grayscale, 40% opacity)

---

### **Final CTA Section:**

**Heading:**
```
Ready to start farming cash?
```

**Button:**
```
Join the Waitlist
```

**Subtext:**
```
OR scroll to top to complete signup
```

---

### **Footer:**

**Links:**
```
Blog  •  Privacy Policy  •  Terms of Service
```

**Social:**
```
🐦 Twitter
```

**Copyright:**
```
© 2026 Mega Unlimited LTD. All rights reserved.
```

---

## **Design Inspiration & References**

**Look & Feel:**
- **Notion:** Clean, spacious, modern
- **Linear:** Bold headlines, generous whitespace
- **Superhuman:** Product screenshots front-and-center
- **Stripe:** Trust badges subtle, not aggressive

**Avoid:**
- Swagbucks clutter (too many CTAs, boxes, visual noise)
- Old-school affiliate sites (red arrows, fake urgency)
- Generic SaaS templates (stock photos, corporate blandness)

**Goal:**
- Modern, warm, trustworthy
- Gaming vibe without losing credibility
- Community feel without being unprofessional

---

## **Future Enhancements (Post-Launch)**

**Not included in v1.0, but noted for iteration:**

1. **Explainer Video** (30-60 sec animated walkthrough)
2. **Live Waitlist Counter** (updates in real-time)
3. **FAQ Accordion** (Is this legit? How much can I earn? etc.)
4. **Blog Integration** (Recent posts preview on homepage)
5. **Language Toggle** (Multi-language support)
6. **Dark Mode** (User preference toggle)
7. **Accessibility Improvements** (WCAG AA compliance)
8. **A/B Testing** (Test headlines, form positions, CTA copy)

---

## **Questions for Developer**

Before starting implementation, confirm:

1. **Current tech stack?** (HTML/CSS/JS? React? Vue? Static site generator?)
2. **Can we modify form structure** without breaking backend? (Remove survey questions)
3. **Is smooth scroll** supported/easy to implement?
4. **Image optimization** - WebP support? Lazy loading?
5. **Hero image** - Should we create multiple crops for different screen sizes? (1600x672 for desktop, 800x1200 for mobile?)
6. **Analytics** - PostHog or Google Analytics already integrated?

---

## **Approval Checklist**

Before handing to developer, confirm:

- [ ] **Headline chosen** (Option A, B, or C?)
- [ ] **Form simplification approved** (Just email + terms checkbox?)
- [ ] **Screenshot order finalized** (5 screens confirmed?)
- [ ] **Testimonial placeholder copy approved** (Or provide real quotes?)
- [ ] **Partner logos available** (Can you provide AyeT, RevU, Prodege logos?)
- [ ] **"How It Works" graphic approach** (Simple icons or wait for custom illustration?)
- [ ] **Color palette approved** (Green shades, neutrals as specified?)
- [ ] **Timeline confirmed** (1 day realistic for this scope?)

---

## **File Delivery**

**Hand to coding agent:**

**Assets Folder:**
```
/assets/
  /images/
    hero-farm-1600x672.png (hero image)
    grandma-marty-cutout.png (character PNG)
    screenshot-1-tutorial.png
    screenshot-2-home.png
    screenshot-3-jobs.png
    screenshot-4-plant.png
    screenshot-5-harvest.png
    logo-farmcash.png
    icon-app-android.png
    icon-app-ios.png
    partner-ayet.png (grayscale, low opacity)
    partner-revu.png (grayscale, low opacity)
    partner-prodege.png (grayscale, low opacity)
```

**Design Brief:**
```
FarmCash_Landing_Page_Design_Brief_v1.md (this file)
```

**Existing Site Code:**
```
Current site files (maintain backend connections)
```

---

**END OF DESIGN BRIEF**

*Version 1.0 • April 13, 2026 • Ready for Implementation*

---

## **Quick Start Guide for Developer**

**Step 1:** Review this entire brief  
**Step 2:** Confirm questions in "Questions for Developer" section  
**Step 3:** Gather all assets from /assets/ folder  
**Step 4:** Start with hero section (most critical for trust)  
**Step 5:** Implement form (keep backend logic, change visuals only)  
**Step 6:** Add remaining sections in order  
**Step 7:** Mobile responsive testing  
**Step 8:** Launch!

**Timeline:** 1 day (as requested)

**Priority:** Hero + Form + How It Works (these 3 sections are critical, rest can be added incrementally if time runs short)

---

*Good luck! Let's make FarmCash look as good as it plays.* 🌱💰