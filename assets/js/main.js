(() => {
  const labels = document.body.dataset;
  const themeToggle = document.getElementById('theme-toggle');
  if (themeToggle) {
    themeToggle.hidden = false;
    themeToggle.addEventListener('click', () => {
      const html = document.documentElement;
      const dark = html.dataset.theme ? html.dataset.theme === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
      html.dataset.theme = dark ? 'light' : 'dark';
      try { localStorage.setItem('pref-theme', html.dataset.theme); } catch (error) {}
    });
  }

  const topLink = document.querySelector('.top-link');
  if (topLink) {
    const update = () => { topLink.hidden = window.scrollY < window.innerHeight; };
    window.addEventListener('scroll', update, { passive: true });
    update();
  }

  if (labels.copyEnabled !== 'true') return;
  document.querySelectorAll('.post-content pre > code').forEach(code => {
    const button = document.createElement('button');
    const copy = labels.copyLabel;
    button.type = 'button';
    button.className = 'copy-code';
    button.textContent = copy;
    button.setAttribute('aria-live', 'polite');
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        button.textContent = labels.copiedLabel;
      } catch (error) {
        button.textContent = labels.copyFailedLabel;
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(code);
        selection.removeAllRanges();
        selection.addRange(range);
      }
      setTimeout(() => { button.textContent = copy; }, 2000);
    });
    code.parentElement.appendChild(button);
  });
})();
