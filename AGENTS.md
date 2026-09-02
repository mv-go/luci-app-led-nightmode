# luci-app-led-nightmode

## Purpose

Build a universal OpenWrt LED night-mode application. The first test device is a Banana Pi BPI-R3 Mini, but device-specific LED names or assumptions must never enter the general implementation.

## Current milestone

The hardware CLI, package/UCI/procd, optional non-sysfs provider, scheduling, rpcd/ACL, and native LuCI milestones are complete. Published release `v0.5.1` carries package revision `0.5.1-r1`, separating the headless `led-nightmode` runtime, UI-only `luci-app-led-nightmode`, and optional provider into three non-overlapping APKs. The official OpenWrt 25.12.4 SDK builds all three, and an isolated `apk-tools` 3 transaction verifies the upgrade from monolithic `0.5.0-r8` while preserving UCI. The published `r8` package remains the live-hardware baseline: on the first BPI-R3 Mini, forced-Night reboot and physical unplug/replug both kept all managed indicators off, restored the original solar configuration afterward, and preserved connectivity. The split release is not yet a live-router claim. A second physical OpenWrt device is deferred, so no multi-device validation is claimed. The next milestone is two linked upstream Draft PRs for `openwrt/packages` and `openwrt/luci`.

The initial inventory and live round-trip result are stored in `docs/hardware/bpi-r3-mini-led-inventory.md`. The service/UCI boundary is documented in `docs/architecture/service-and-uci.md`.

## Runtime and design rules

- Target BusyBox `ash` and standard OpenWrt utilities. Do not require Bash, Python, or GNU-only tools on the router.
- Discover LEDs from sysfs at runtime. Do not hard-code LED names or BPI-R3 Mini behaviour.
- Do not infer physical dimming from `max_brightness > 1`: some drivers treat every nonzero value as fully on. The safe default switches all LEDs off; a nonzero multi-level target requires explicit opt-in after hardware calibration. Binary LEDs may gain a sparse pulse mode later.
- Preserve the original LED trigger and state before changing an LED. Restoration must be idempotent and tolerate missing LEDs.
- Keep filesystem access behind a configurable sysfs root so tests can use fixtures instead of a live router.
- Do not implement astronomical calculations. Solar scheduling uses `sunwait`.
- Keep package defaults write-safe: a fresh install must not change LEDs until the UCI service is explicitly enabled.
- Keep device-specific non-sysfs commands in optional provider drivers. Providers require explicit endpoints, read-only capability probes, serialized reversible visual tests, saved-state restoration, and fixture-backed lifecycle tests; the sysfs core must not scan serial ports or infer modem models.
- Keep the installed CLI at `/usr/sbin/led-nightmode`; its package source is `core/root/usr/sbin/led-nightmode`, while `bin/led-nightmode` is only a local convenience wrapper.

## Safety and validation

- Do not write to the real router through SSH unless the user explicitly asks for that action.
- Read-only inventory commands are allowed and should precede any router-side implementation test.
- Add tests or fixtures alongside behaviour that depends on sysfs layout, trigger parsing, or state restoration.
- Keep commands in this file accurate. Add build, lint, and test commands only after they exist.

## Commands

- `make check` validates POSIX shell syntax for the CLI, init script, core/provider runners, provider driver, and tests.
- `make test` runs fixture-backed CLI, service, and provider lifecycle tests without touching a real router.

## Project memory

WikiLayer holds project decisions, handoffs, constraints, and next steps. The repository holds source code, tests, executable configuration, and release artifacts.
