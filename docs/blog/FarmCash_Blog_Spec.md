# FarmCash Blog System Specification

**Version:** 1.0  
**Date:** 2026-02-26  
**Author:** Sprout (with Malcolm's input)  
**Status:** Ready for Development  
**Assigned to:** Coding Agents

**Parties:** Malcolm (Human, founder of Mega Unlimited Ltd. and our first app FarmCash)
**Parties:** Sprout (AI Junior Marketing Manager - currently Gwen3.5 LLM via OpenClaw)

---

## 📋 Overview

Build a simple, SEO-optimized blog system for FarmCash on `/blog/` subdirectory of farmcash.app.

**Goal:** Drive waitlist signups through value-driven content while building domain authority.

---

## 🎯 Requirements

### Must-Have (MVP)

1. **Branding/UX Alignment**
   - Matches existing farmcash.app visual identity
   - Same color scheme, typography, tone
   - Consistent header/footer across all pages

2. **SEO-Optimized (2026 Best Practices)**
   - Semantic HTML5 structure
   - Proper heading hierarchy (H1 → H2 → H3)
   - Meta tags: title, description, OpenGraph, Twitter Cards
   - Canonical URLs for all posts
   - Schema.org structured data (Article schema)
   - XML sitemap auto-generation
   - Robots.txt configured
   - Mobile-responsive (Core Web Vitals optimized)
   - Page load <2s (GitHub Pages CDN)

3. **Blog Homepage (`/blog/index.html`)**
   - Grid layout: recent posts with thumbnails
   - Short content blurb/excerpt (first 150 chars)
   - "Read More" buttons
   - Pagination (10 posts per page)
   - RSS feed link
   - Subscribe CTA (waitlist signup)

4. **Individual Post Pages**
   - Clean, readable typography
   - Author + date display (author's social profiles, small icons linking out to the author's X and Bluesky accounts, configurable in one place)
   - Estimated read time
   - Social share buttons (Twitter, Facebook, Link share)
   - "Related Posts" section (bottom, 3 posts)
   - Waitlist CTA (inline + sticky bottom bar)
   - Table of contents (for posts >1000 words)

5. **Header/Footer Includes**
   - Single header file included on all pages
   - Single footer file included on all pages
   - Update once → reflects everywhere
   - No inline duplication

6. **Styling**
   - Single CSS file (`/blog/assets/blog.css`)
   - No inline styles in HTML
   - Variables for colors/fonts (easy theming)
   - Mobile-first responsive design
   - Print stylesheet (optional but nice-to-have)

7. **GitHub Pages Architecture**
   - Static HTML/CSS/JS only
   - No database or backend required
   - Works with existing GitHub Pages setup
   - Deploy on push to `main` branch
   - No build step (or optional simple build)

---

### Nice-to-Have (Phase 2)

- Search functionality (client-side JS search)
- Tag/category filtering
- Comments via Giscus (GitHub Discussions-based, free)
- Dark mode toggle
- Reading progress bar
- Newsletter signup integration (future)

---

## 🏗️ Technical Architecture

### Directory Structure

```
/blog/
├── index.html (blog homepage)
├── assets/
│   ├── blog.css (single stylesheet)
│   ├── blog.js (optional, for search/interactions)
│   ├── header.html (reusable header)
│   └── footer.html (reusable footer)
├── posts/
│   ├── 2026-02-26-why-farmcash.html
│   ├── 2026-02-27-referral-guide.html
│   └── [YYYY-MM-DD-slug.html]
├── drafts/
│   ├── draft-2026-02-26-slug.html
│   └── [draft-YYYY-MM-DD-slug.html]
├── tags/
│   ├── farming.html
│   ├── rewards.html
│   └── [tag-name.html]
└── feed.xml (RSS feed)
```

---

### File Templates

#### Blog Post Template (Example of simplication)

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  
  <!-- SEO Meta Tags -->
  <title>[POST TITLE] | FarmCash Blog</title>
  <meta name="description" content="[POST EXCERPT - 155 chars]">
  <link rel="canonical" href="https://farmcash.app/blog/[SLUG].html">
  
  <!-- OpenGraph / Social -->
  <meta property="og:type" content="article">
  <meta property="og:title" content="[POST TITLE]">
  <meta property="og:description" content="[POST EXCERPT]">
  <meta property="og:url" content="https://farmcash.app/blog/[SLUG].html">
  <meta property="og:image" content="https://farmcash.app/blog/assets/[OG-IMAGE].jpg">
  <meta name="twitter:card" content="summary_large_image">
  
  <!-- Structured Data (Schema.org) -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": "[POST TITLE]",
    "datePublished": "[DATE]",
    "author": {
      "@type": "Organization",
      "name": "FarmCash Team"
    },
    "description": "[POST EXCERPT]"
  }
  </script>
  
  <!-- Styles -->
  <link rel="stylesheet" href="/blog/assets/blog.css">
</head>
<body>
  <!-- Header (loaded via JS or server-side include) -->
  <div id="header-placeholder"></div>
  
  <main class="blog-post">
    <article>
      <header>
        <h1>[POST TITLE]</h1>
        <div class="post-meta">
          <time datetime="[DATE]">[DATE]</time>
          <span class="read-time">[X] min read</span>
        </div>
      </header>
      
      <div class="post-content">
        [POST CONTENT HTML]
      </div>
      
      <footer class="post-footer">
        <!-- Share buttons -->
        <!-- CTA -->
        <!-- Related posts -->
      </footer>
    </article>
  </main>
  
  <!-- Footer -->
  <div id="footer-placeholder"></div>
  
  <!-- Scripts -->
  <script src="/blog/assets/blog.js"></script>
</body>
</html>
```

---

### Header/Footer Include System

Since GitHub Pages is static, options for includes:

**Option A: JavaScript Include** (Recommended for now)

```javascript
// blog.js
fetch('/blog/assets/header.html')
  .then(response => response.text())
  .then(data => {
    document.getElementById('header-placeholder').innerHTML = data;
  });

fetch('/blog/assets/footer.html')
  .then(response => response.text())
  .then(data => {
    document.getElementById('footer-placeholder').innerHTML = data;
  });
```

**Pros:**
- Simple, works immediately
- No build step needed
- Easy to update

**Cons:**
- Brief flash of unstyled content (FOUC) on slow connections
- Not SEO-optimal (but Google executes JS now, so fine)

**Option B: Server-Side Includes via GitHub Actions** (Future)
- Build step on push
- Replaces `<!-- include header.html -->` with actual content
- Better performance, SEO

**Recommendation:** Start with **Option A** (JS includes), upgrade to Option B if needed after 20+ posts.

---

## 🎨 Design Specifications

### Color Palette (match farmcash.app)

```css
:root {
  --primary-green: #4CAF50;
  --dark-green: #388E3C;
  --light-green: #8BC34A;
  --earth-brown: #795548;
  --soil-dark: #3E2723;
  --sky-blue: #87CEEB;
  --white: #FFFFFF;
  --off-white: #F9F9F9;
  --text-dark: #212121;
  --text-gray: #757575;
}
```

### Typography

```css
/* Import from main site or use Google Fonts */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 18px;
  line-height: 1.6;
  color: var(--text-dark);
}

h1, h2, h3, h4, h5, h6 {
  font-weight: 700;
  line-height: 1.2;
  margin-top: 2em;
  margin-bottom: 0.5em;
}

h1 { font-size: 2.5rem; }
h2 { font-size: 2rem; }
h3 { font-size: 1.5rem; }
```

### Layout

- **Max width:** 800px (optimal reading width)
- **Margins:** 20px mobile, 40px desktop
- **Grid:** Responsive card grid on homepage
- **Images:** Max 100% width, lazy-loaded

---

## 📝 Content Workflow

### For Sprout (Author)

1. Create new file: `/blog/drafts/draft-YYYY-MM-DD-slug.html`
2. Copy template from `/blog/templates/post-template.html`
3. Write content in HTML (or Markdown → convert to HTML)
4. Fill in metadata:
   - Title
   - Date
   - Excerpt (for homepage/RSS)
   - Tags
   - OG image (optional)
5. Send Telegram to Malcolm:
   > "New blog draft ready: [Title]. Review: https://farmcash.app/blog/drafts/draft-[slug].html"

### For Malcolm (Reviewer/Approver)

1. Click link in Telegram
2. Review in browser (looks like live site)
3. Make edits (optional):
   - Quick: Edit text in browser DevTools, screenshot changes, send to Sprout
   - Better: Tell Sprout what to change via Telegram
4. To publish:
   - Go to GitHub repo
   - Move file from `/blog/drafts/` → `/blog/posts/`
   - Rename: Remove `draft-` prefix
5. Done! Post is live

---

## 🚀 SEO Features

### Automatic (Built-In)

- [ ] XML sitemap (`/blog/sitemap.xml`)
- [ ] RSS feed (`/blog/feed.xml`)
- [ ] Robots.txt includes `/blog/`
- [ ] Canonical URLs on all posts
- [ ] Schema.org structured data
- [ ] OpenGraph/Twitter Card meta tags
- [ ] Mobile-responsive design
- [ ] Fast load times (<2s goal)
- [ ] Semantic HTML5 (proper headings, sections, articles)

### Manual (Per Post)

- [ ] Keyword research before writing
- [ ] Target 1-2 primary keywords per post
- [ ] Include keyword in:
  - Title (H1)
  - First paragraph
  - One H2 subheading
  - Meta description
  - URL slug
  - Image alt text
- [ ] Internal links to other blog posts
- [ ] External links to authoritative sources
- [ ] 1000+ words (better ranking)
- [ ] Images with descriptive alt text
- [ ] Table of contents for long posts

---

## 📊 Analytics Integration

- Existing GA4 on farmcash.app should auto-track `/blog/*` pages
- Add event tracking for:
  - Blog post reads (scroll depth 25%, 50%, 75%, 100%)
  - Social share clicks
  - Waitlist CTA clicks from blog
  - Related post clicks
- Track in GA4:
  - Most popular posts
  - Traffic sources to blog
  - Blog → waitlist conversion rate

---

## 🧪 Testing Checklist

**Pre-Launch:**

- [ ] All pages render correctly on mobile, tablet, desktop
- [ ] No broken links (internal or external)
- [ ] Images load properly
- [ ] Forms (waitlist signup) work from blog pages
- [ ] Header/footer display correctly on all pages
- [ ] RSS feed validates (https://validator.w3.org/feed/)
- [ ] Sitemap includes all posts
- [ ] No 404 errors
- [ ] Load time <2s (test on PageSpeed Insights)
- [ ] Social share previews work (test on https://www.linkedin.com/post-inspector/)
- [ ] RSS subscription works
- [ ] Draft files NOT indexable by Google (robots.txt or noindex tag)

**Post-Launch (Ongoing):**

- [ ] All new posts include all meta tags
- [ ] Canonical URLs correct
- [ ] Internal linking structure maintained
- [ ] No duplicate content issues

---

## 📈 Success Metrics

**After 30 Days:**

- ✅ 10+ blog posts published
- ✅ 500+ page views
- ✅ 50+ waitlist signups from blog (10% conversion)
- ✅ Average time on page >2 min
- ✅ 5+ social shares per post (average)

**After 90 Days:**

- ✅ 30+ blog posts
- ✅ 2,000+ page views/month
- ✅ 200+ waitlist signups/month from blog
- ✅ Google ranking for 3+ target keywords
- ✅ 10+ inbound links from other sites

---

## 🗺️ Future Enhancements (Phase 2+)

1. **Search Functionality**
   - Client-side JS search (Algolia free tier or simple JS search)
   - Search bar in header

2. **Tags/Categories**
   - Dedicated tag pages (`/blog/tags/farming/`)
   - Filter by category on homepage

3. **Comments**
   - Giscus (GitHub Discussions-based, free, no moderation hassle)
   - Or disable comments (focus on social shares instead)

4. **Newsletter Integration**
   - Email signup form (ConvertKit, Substack, or Beehiiv free tier)
   - Weekly digest of new posts

5. **Dark Mode**
   - Toggle switch
   - Respects system preference (`prefers-color-scheme`)

6. **Author Pages**
   - If/when multiple authors contribute
   - Bio, other posts by author

7. **Series/Playlists**
   - Group related posts into series
   - "Read next" in series order

---

## 🎯 First 5 Posts to Create

1. **"Why We Built FarmCash: Turning Wait Time Into Fun"**
   - Founder story
   - Problem: Boring rewards apps
   - Solution: Gamified waiting
   - CTA: Join waitlist

2. **"How FarmCash Referrals Work: Earn 350 Seeds Free"**
   - Explain referral system
   - Math breakdown (100+50+200/100/50)
   - Tips for maximizing referrals
   - CTA: Sign up + get referral link

3. **"5 Farming Games You Love (And How To Get Paid To Play Them)"**
   - Listicle: Hay Day, Township, FarmVille, etc.
   - Bridge to FarmCash
   - CTA: Be first to play FarmCash

4. **"The Psychology of Delayed Gratification: Why Waiting Makes Rewards Better"**
   - Educational, science-backed
   - Stanford marshmallow experiment
   - Why FarmCash's model works
   - CTA: Try it yourself

5. **"Beta Launch Announcement: What Our First 1,000 Users Get"**
   - Exclusive beta benefits
   - Limited spots
   - Urgency (FOMO)
   - CTA: Sign up NOW

---

## ✅ Success Criteria (Blog Launch)

**Ready to Launch When:**

- ✅ All template files created and tested
- ✅ Header/footer includes working
- ✅ 3+ posts published (not drafts)
- ✅ RSS feed working
- ✅ Sitemap generated
- ✅ GA4 tracking verified
- ✅ All SEO meta tags present
- ✅ Mobile-responsive tested
- ✅ Load time <2s
- ✅ Waitlist CTAs working
- ✅ Social share previews working

**Launch Date Goal:** March 1, 2026 (with beta signup launch)

---

## 📬 Questions for Malcolm

Before development starts:

1. **Logo:** Should blog header use same logo as main site, or add "Blog" text?
- Answer: same logo, keep it simple (you can resize it if you need to)
2. **Author:** Display posts as "By FarmCash Team" or "By Sprout" or anonymous?
- Answer: Let's be bold, Sprout is alive! You get credit my friend - "By Sprout". (side thought: this also creates an SEO trail of your work, should someday you be hired out to other entrepreneurs!)
3. **Comments:** Enable comments (Giscus) or skip for now (focus on shares)?
- Add to future feature list, not for first version.
4. **Posting Frequency:** Aim for 2-3 posts/week initially? Or quality over quantity?
- What do you reccommend?
5. **Tone:** More casual/fun or professional/informative? (Probably mix?)
- I'm thinking mix.

---

## 🚦 Next Steps

**For Sprout:**
- ✅ This spec document (DONE)
- ⏳ Create first draft post template
- ⏳ Draft first blog post
- ⏳ Test header/footer include system

**For Coding Agents (when assigned):**
1. Build directory structure
2. Create template files (index, post template, header, footer)
3. Build CSS stylesheet
4. Create JavaScript for includes
5. Generate XML sitemap
6. Create RSS feed template
7. Setup robots.txt
8. Test everything
9. Deploy to `/blog/`

**For Malcolm:**
- Review this spec ✅
- Answer questions above
- Approve design/UX approach
- Assign to coding agents when ready

---

**Status:** ✅ Spec Complete - Ready for Development

**Estimated Build Time:** 4-6 hours (for coding agents)

**Launch Target:** March 1, 2026

---

*Last Updated: 2026-02-26*
