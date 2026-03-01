# FarmCash Blog Draft Authoring Guide

Use this guide when creating blog drafts that are ready for Malcolm to review in `/blog/drafts/` and later move to `/blog/posts/`.

## 1) File + naming rules

- Draft location: `/blog/drafts/`
- Draft filename: `draft-YYYY-MM-DD-slug.html`
  - Example: `draft-2026-03-05-referral-seed-strategy.html`
- Published filename: `YYYY-MM-DD-slug.html` (remove `draft-`)
- Slug rules:
  - lowercase
  - hyphen-separated
  - short + keyword-focused (no spaces/underscores/special chars)

## 2) Copy the correct starting template

- Always start from `/blog/drafts/draft-YYYY-MM-DD-slug.html`.
- Keep these includes/scripts in place (do not delete):
  - `#header-placeholder`
  - `#footer-placeholder`
  - `/blog/assets/posts-data.js`
  - `/blog/assets/blog.js`
- Keep draft privacy meta in `<head>`:
  - `<meta name="robots" content="noindex,nofollow,noarchive,nosnippet" />`

## 3) Styling + formatting rules

- **No inline CSS** and no custom `<style>` blocks in post files.
- Blog styles come from `/blog/assets/blog.css`.
- Use semantic HTML only:
  - One `<h1>` per post (title)
  - Section headers as `<h2>`, sub-sections as `<h3>`
  - Body paragraphs with `<p>`
  - Lists with `<ul>/<ol>` + `<li>`
  - Links with `<a>` and meaningful anchor text
- Recommended content layout:
  1. Intro paragraph (problem + promise)
  2. 2–4 sections (`<h2>`)
  3. Optional sub-sections (`<h3>`)
  4. Clear CTA near end

## 4) Required metadata checklist (per post)

In `<head>` (replace placeholders):

- `<title>`: `Post Title | FarmCash Blog`
- `<meta name="description">`: 140–160 chars
- `<link rel="canonical">`: final post URL
- OpenGraph:
  - `og:type=article`
  - `og:title`
  - `og:description`
  - `og:url`
  - `og:image`
- Twitter:
  - `twitter:card=summary_large_image`
- JSON-LD (`BlogPosting`) with:
  - `headline`
  - `datePublished`
  - `dateModified`
  - `author.name` (Sprout)
  - `description`
  - `mainEntityOfPage`

## 5) Content quality + SEO best practices

- Target 1 primary keyword + 1 supporting keyword.
- Include primary keyword in:
  - title (H1)
  - first paragraph
  - at least one H2
  - meta description
  - slug
- Add 1–3 internal links (other blog posts or key pages).
- Add 1–2 credible external links (where useful).
- Recommended length:
  - Standard posts: 700–1200 words
  - Deep-dive posts: 1200+ words
- If content is 1000+ words, TOC auto-appears from H2/H3 headings.

## 6) Images (post + social)

### Primary image recommendation

Use one image for both article visual + social preview to keep workflow simple.

- Recommended aspect ratio: **16:9**
- Recommended size: **1600x900** (good quality, fast enough)
- Minimum size: **1200x675**
- Format: `.jpg` or `.png` (optimize for web)
- Keep text on image minimal and readable on mobile.

### Where to use it

- In `posts-data.js` as `image` for homepage card.
- In post `<head>` as `og:image`.
- Optionally once in body content with meaningful `alt` text.

## 7) Related posts: how it works

- Related posts are generated automatically from `window.BLOG_POSTS` in `/blog/assets/posts-data.js`.
- To make related posts work correctly:
  1. Add each new post object to `BLOG_POSTS`.
  2. Ensure `slug`, `title`, `date`, `excerpt`, and `image` are accurate.
  3. Keep post `slug` identical to the HTML filename (without `.html`).

## 8) Publishing workflow (your agreed process)

1. Write draft in separate/private repo.
2. Copy approved draft to `/blog/drafts/` for production-like final preview.
3. Review links, metadata, image paths, and CTA URLs.
4. Publish by moving file to `/blog/posts/` and removing `draft-` prefix.
5. Update `/blog/assets/posts-data.js`.
6. Update `/blog/feed.xml` and `/blog/sitemap.xml`.

## 9) Current known limitations

- Header/footer are JS-injected; very old crawlers may not render includes.
- Related posts are metadata-based (not tag-scored yet).
- No auth on `/blog/drafts/`; rely on `noindex` + robots disallow (good for crawl control, not true access control).

## 10) Pre-review quick check (2 minutes)

- Title, date, author, read time are correct.
- Meta description is present and not duplicated.
- Canonical URL matches final destination.
- All buttons/links work and use the desired UTM params.
- Images load and look good on mobile.
- Draft still has `noindex,nofollow` meta.
