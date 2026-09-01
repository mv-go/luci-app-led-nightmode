# Changelog

This project uses semantic versions for application releases. OpenWrt's `PKG_RELEASE` suffix is incremented when packaging or installed files change without a new application version.

## 0.5.1-r1 - 2026-09-02

- Split the universal runtime into a headless `led-nightmode` package.
- Keep `luci-app-led-nightmode` UI-only with a dependency on the core package.
- Make the optional Quectel provider depend on `led-nightmode` instead of LuCI.
- Preserve the existing UCI path, service name, runtime paths, safe defaults, and provider contract.
- Move the live `rpcd` lifecycle reload to the core package so headless installations initialize their own RPC entry point.
- Verify a transactional `apk-tools` 3 upgrade from monolithic `0.5.0-r8`, including preserved UCI configuration and non-overlapping package ownership.
- Add reproducible, provider-free staging for separate `openwrt/packages` and `openwrt/luci` contributions.

## OpenWrt package revision 0.5.0-r8 - 2026-09-02

- Fixed boot-time LED trigger ordering by starting LED Night Mode after OpenWrt's stock `led` init script and migrating enabled legacy autostart links during package upgrade.
- Verified both APKs with the official OpenWrt 25.12.4 SDK and upgraded the first live router without changing its UCI configuration.
- Confirmed the corrected startup order in a forced-Night reboot: all nine sysfs LEDs remained at trigger `none` and brightness `0` after boot, while the modem provider retried until its endpoint became ready.
- Confirmed the original physical unplug/replug path at Night on the first live router.

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

Known limitations:

- Physical behaviour is live-validated on one OpenWrt device; multi-device validation is not claimed.
- The BPI-R3 Mini's hard-wired PWR indicator has no software control path.
- Indicators outside the Linux LED class require an explicit provider. The bundled Quectel provider is scoped to the validated two-field command response and does not imply support for every modem or firmware.
- A reported `max_brightness > 1` does not prove physical dimming; the safe default remains fully off.
