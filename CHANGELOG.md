# Changelog

This project uses semantic versions for application releases. OpenWrt's `PKG_RELEASE` suffix is incremented when packaging or installed files change without a new application version.

## 0.5.0 - 2026-08-24

- Reworked LuCI into a simple default Settings flow with technical controls under Advanced.
- Added manual, fixed-time, and `sunwait`-based sunrise/sunset scheduling.
- Added timezone-assisted approximate solar coordinates and optional browser geolocation.
- Added safe calibrated brightness controls without treating `max_brightness > 1` as proof of physical dimming.
- Added optional provider discovery, read-only connection probes, and reversible visual tests.
- Added the separately packaged Quectel QNWCFG `ledmode` provider with exact saved-state restoration and retry after transient endpoint failures.
- Added native rpcd/ACL integration, upgrade-safe UCI defaults, and fixture-backed core, service, schedule, LuCI, init, and provider tests.
- Removed device-specific provider defaults from the universal package and made an empty Linux LED class a safe no-op.
- Added a compatibility evidence matrix, release gate, translation template, and GitHub CI/SDK workflows.
