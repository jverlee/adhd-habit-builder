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

- `index.md` — landing page.
- `privacy.md` — privacy policy (kept in sync with the App Store privacy URL).
- `_config.yml` — site title, theme, plugins.

The theme is `pages-themes/cayman` via remote_theme — no local theme files needed. Swap it for any GitHub Pages‑supported theme by changing one line in `_config.yml`.
