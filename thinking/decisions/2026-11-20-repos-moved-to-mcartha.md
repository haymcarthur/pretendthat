# Repos moved to the mcartha GitHub account

**Date:** 2026-11-20
**Who decided:** Haylee

- Both repos moved from `haymcarthur` to `mcartha`:
  - App: https://github.com/mcartha/pretendthat
  - Site: https://github.com/mcartha/pretendthat-site (serves https://pretendthat.app through GitHub Pages)
- Notes that named the old repos now point to the new ones (open-questions.md, decisions/2026-11-14-launch-ipad-site-repo.md). The app and site code had no GitHub repo URLs in them, so no code changed.
- Local Mac paths like `/Users/haymcarthur/...` are the Mac's user folder, not GitHub, so they stay as they are.
- **Still to do on the Mac (local session):** find the local clones (the old notes say /Users/haymcarthur/PretendThat, but that folder isn't on the MacBook Air: `find ~ -maxdepth 4 -iname "pretendthat*" -type d -not -path "*/node_modules/*"`), then in each run `git remote set-url origin https://github.com/mcartha/<repo>` and `git pull`. GitHub redirects the old URLs, but don't rely on it.
- **Pages:** the app repo (mcartha/pretendthat) has Pages off, which is correct. Check **mcartha/pretendthat-site** → Settings → Pages: it should deploy from branch `main` / root with custom domain pretendthat.app and HTTPS enforced. If the transfer dropped it, set it back (the CNAME file is already in the repo).
