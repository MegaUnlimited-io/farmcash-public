(function () {
  const POSTS = (window.BLOG_POSTS || []).slice().sort((a, b) => b.date.localeCompare(a.date));
  const POSTS_PER_PAGE = 10;

  async function loadIncludes() {
    await Promise.all([
      injectHtml('/blog/assets/header.html', 'header-placeholder'),
      injectHtml('/blog/assets/footer.html', 'footer-placeholder')
    ]);
  }

  async function injectHtml(path, id) {
    const el = document.getElementById(id);
    if (!el) return;
    const html = await fetch(path).then((res) => res.text());
    el.innerHTML = html;
  }

  function formatDate(dateISO) {
    return new Date(`${dateISO}T00:00:00`).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  }

  function renderIndexCards() {
    const root = document.getElementById('blog-grid');
    if (!root) return;

    const page = Number(new URLSearchParams(window.location.search).get('page') || '1');
    const start = (page - 1) * POSTS_PER_PAGE;
    const pagePosts = POSTS.slice(start, start + POSTS_PER_PAGE);

    root.innerHTML = pagePosts
      .map(
        (post) => `
      <article class="blog-card">
        <img src="${post.image}" loading="lazy" alt="${post.title}">
        <div class="blog-card-body">
          <h2><a href="/blog/posts/${post.slug}.html">${post.title}</a></h2>
          <p class="blog-meta">By ${post.author} · <time datetime="${post.date}">${formatDate(post.date)}</time> · ${post.readMinutes} min read</p>
          <p>${post.excerpt.slice(0, 150)}...</p>
          <a class="blog-btn" href="/blog/posts/${post.slug}.html">Read More</a>
        </div>
      </article>`
      )
      .join('');

    renderPagination(page);
  }

  function renderPagination(page) {
    const wrap = document.getElementById('blog-pagination');
    if (!wrap) return;
    const pages = Math.ceil(POSTS.length / POSTS_PER_PAGE);
    if (pages <= 1) {
      wrap.innerHTML = '';
      return;
    }

    wrap.innerHTML = Array.from({ length: pages }, (_, i) => i + 1)
      .map((p) => `<button ${p === page ? "aria-current='page'" : ''} data-page="${p}">${p}</button>`)
      .join('');

    wrap.querySelectorAll('button').forEach((button) => {
      button.addEventListener('click', () => {
        const next = Number(button.dataset.page);
        const url = new URL(window.location.href);
        url.searchParams.set('page', String(next));
        window.location.href = url.toString();
      });
    });
  }

  function enableShareButtons() {
    const url = encodeURIComponent(window.location.href);
    const title = encodeURIComponent(document.title);

    const tw = document.getElementById('share-x');
    const fb = document.getElementById('share-facebook');
    const cp = document.getElementById('share-copy');
    if (tw) tw.href = `https://twitter.com/intent/tweet?url=${url}&text=${title}`;
    if (fb) fb.href = `https://www.facebook.com/sharer/sharer.php?u=${url}`;
    if (cp) {
      cp.addEventListener('click', async () => {
        await navigator.clipboard.writeText(window.location.href);
        cp.textContent = 'Copied!';
      });
    }
  }

  function renderRelatedPosts() {
    const box = document.getElementById('related-posts');
    if (!box) return;
    const slug = document.body.dataset.postSlug;
    const related = POSTS.filter((p) => p.slug !== slug).slice(0, 3);
    box.innerHTML = related
      .map((p) => `<li><a href="/blog/posts/${p.slug}.html">${p.title}</a> <small>(${formatDate(p.date)})</small></li>`)
      .join('');
  }

  function maybeBuildToc() {
    const content = document.querySelector('.js-post-content');
    const toc = document.getElementById('table-of-contents');
    if (!content || !toc) return;

    const words = (content.textContent || '').trim().split(/\s+/).filter(Boolean).length;
    if (words < 1000) {
      toc.hidden = true;
      return;
    }

    const headings = [...content.querySelectorAll('h2, h3')];
    const list = toc.querySelector('ol');
    list.innerHTML = '';

    headings.forEach((heading, i) => {
      const id = heading.id || `section-${i + 1}`;
      heading.id = id;
      const li = document.createElement('li');
      li.innerHTML = `<a href="#${id}">${heading.textContent}</a>`;
      list.appendChild(li);
    });
  }

  function setAuthorSocials() {
    const x = document.getElementById('author-x');
    const bluesky = document.getElementById('author-bluesky');
    if (x) x.href = window.SPROUT_SOCIALS?.x || '#';
    if (bluesky) bluesky.href = window.SPROUT_SOCIALS?.bluesky || '#';
  }

  document.addEventListener('DOMContentLoaded', async () => {
    await loadIncludes();
    renderIndexCards();
    enableShareButtons();
    renderRelatedPosts();
    maybeBuildToc();
    setAuthorSocials();
  });
})();
