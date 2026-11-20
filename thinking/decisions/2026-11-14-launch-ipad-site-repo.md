# Launch prep: physical iPad, demo site, public repo

**Date:** 2026-11-14 (morning, before the 7:59 freeze)
**Who decided:** Haylee

- **Physical iPad demo:** the app is installed on Haylee's iPad Pro 11-inch (2nd generation, iPadOS 27), signed with her free Personal Team (TSM76TQF46). The team is passed only on the command line (`DEVELOPMENT_TEAM=... -allowProvisioningUpdates`), so the project files are unchanged. The build lands in build/DeviceData. The free install lasts 7 days. The simulator is the backup.
- **Demo site:** https://pretendthat.app (Haylee bought the domain). It's a static one-pager in the public repo mcartha/pretendthat-site (moved from haymcarthur on 2026-11-20), served by GitHub Pages with the apex A/AAAA records and a www CNAME. It uses Haylee's own screenshots.
- **App repo made public:** github.com/mcartha/pretendthat (moved from haymcarthur on 2026-11-20). The history was scanned first and has no keys. Haylee accepted that her work email is visible on the commits. 21 unpushed commits were pushed at 7:18, and a README with the full libraries-and-services list followed (2b287c5).
- **Deck:** new Nutmeg renders on slides 1, 3 and 5, and Haylee's screenshots on slide 3.
- **Known risk:** the kit art sometimes falls back to built-in pages (once from a network drop, once with no error shown). Bring a hotspot.
