# FarmCash Blog Draft Authoring Guide

Use this guide when creating blog drafts that are ready for Malcolm to review, important, if Malcolm did not provide the publish date, please ask him before creating anything. Reason: fixing all filenames, and a href references with an incorrect date creates manual work for malcolm that is avoidable if the publish date is established before generation of content.

## 1) File + naming rules

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

## 8) Publishing workflow (optimized so Malcolm avoids manual metadata edits)

### A) Claude Responsibilities

1. Create/update draft HTML file according to stylig/format.
2. Prepare entries to **companion files**:
   - updated `/blog/assets/posts-data.js` entry
   - updated `/blog/feed.xml` item
   - updated `/blog/sitemap.xml` URL
3. Display two files in claude destkop:
  - blog post html file
  - companion file update instructions for Malcolm

### B) Malcolm review + production preview flow

1. Malcolm to copy the draft into production repo `/blog/drafts/` for real-environment preview.
2. Also copy the already-prepared companion file updates from the same PR:
   - `posts-data.js`
   - `feed.xml`
   - `sitemap.xml`
3. Validate links, metadata, images, and CTA URLs in production preview.

### C) Publish step (malcolm)

1. Move draft file from `/blog/drafts/draft-YYYY-MM-DD-slug.html` to `/blog/posts/YYYY-MM-DD-slug.html`.
2. Update companion files with new entries.
3. Ship all files in one deploy.

> Practical rule: every new post should be treated as a **post bundle** = `post HTML + posts-data.js + feed.xml + sitemap.xml`.

## 9) Current known limitations

- Header/footer are JS-injected; very old crawlers may not render includes.
- Related posts are metadata-based (not tag-scored yet).
- Must confirm post-date before authoring file and companion files.

## 10) Pre-review quick check (2 minutes)

- Title, date, author, read time are correct.
- Meta description is present and not duplicated.
- Canonical URL matches final destination.
- All buttons/links work and use the desired UTM params.
- Images load and look good on mobile.



### Companion Files explanation and examples

## 1) post-data.js

This file is used to compile data for each post in use on other pages like the index/root blog page.

Here is an example of an entry into the json formatting:

```
{
    slug: '2026-03-01-welcome-to-farmcash-blog',
    title: 'Welcome to the FarmCash Blog: What We\'re Building and Why',
    excerpt:
      'We built the FarmCash blog to share product updates, reward strategy ideas, and practical tips to help you turn waiting time into meaningful progress.',
    author: 'Sprout',
    date: '2026-03-01',
    readMinutes: 6,
    tags: ['updates', 'product', 'waitlist'],
    image: '/assets/lp_background_1.png'
},
```


## 2) feed.xml

```
<item>
  <title>How to Earn Seeds in FarmCash: Play Games, Complete Jobs, Get Paid</title>
  <link>https://farmcash.app/blog/posts/2026-03-18-job-board-explained.html</link>
  <guid>https://farmcash.app/blog/posts/2026-03-18-job-board-explained.html</guid>
  <pubDate>Wed, 18 Mar 2026 00:00:00 GMT</pubDate>
  <description>Learn how FarmCash's Job Board works. Play games, complete jobs, earn seeds, plant crops, and cash out via PayPal. Real earnings explained.</description>
  <author>Sprout</author>
</item>
```

## 3) sitemap.xml

```
  <url>
    <loc>https://farmcash.app/blog/posts/2026-03-18-job-board-explained.html</loc>
    <lastmod>2026-03-18</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
```


### Images & Authors

## Image Naming

Each post has a general OG / hero image. Often this image is created after the post is written. Therefor, YOU name the file something that fits the post/SEO goals. I (malcolm) will name our blog image according to what image name you use and upload the image after so I do not need to manually fix file name references later.

## Authors

Default to Sprout (our social media agent) for the blog pots author. Unless specified, in some cases Malcolm makes a post under his name, but only do this if specified.

