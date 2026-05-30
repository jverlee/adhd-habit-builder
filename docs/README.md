# `docs/` — GitHub Pages site

This folder is served as a Jekyll site at GitHub Pages and is **completely independent of the iOS app**. Xcode never reads anything in here.

## Enabling Pages (one‑time)

1. Push the repo to GitHub.
2. Repo → **Settings** → **Pages**.
3. Source: **Deploy from a branch**.
4. Branch: **`main`**, folder: **`/docs`**. Save.
5. Wait ~1 minute. URL will appear at the top of the Pages settings page. It will look like `https://<your-github-username>.github.io/<repo-name>/`.
6. Paste that URL (with `/privacy/` appended for the policy) into App Store Connect → App Information → Privacy Policy URL.

## Local preview (optional)

You don't need this — GitHub builds the site on every push. But if you want to preview locally:

```bash
cd docs
bundle install
bundle exec jekyll serve
# open http://localhost:4000
```

You need Ruby + Bundler installed. `gem install bundler` if you don't have it.

## Editing

- `index.md` — landing page (renders the `home` layout).
- `privacy.md` — privacy policy (kept in sync with the App Store privacy URL).
- `_config.yml` — site title, plugins, defaults.
- `_layouts/default.html` — shared shell: nav, footer, Tailwind setup.
- `_layouts/home.html` — landing page hero, features grid, privacy callout, CTA.
- `_layouts/page.html` — typographic article layout (used by `privacy.md`).

Styling is plain Tailwind via the Play CDN (loaded in `_layouts/default.html`) — no build step, no Node, no theme gem. Edit the Tailwind config block inline in `default.html` to change brand colors or fonts.
