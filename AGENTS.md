# luci-app-led-nightmode

## Purpose

Build a universal OpenWrt LED night-mode application. The first test device is a Banana Pi BPI-R3 Mini, but device-specific LED names or assumptions must never enter the general implementation.

## Current milestone

The hardware-validated CLI milestone is complete. The current milestone adds the OpenWrt package layout, a minimal UCI schema, and a procd-managed service around the CLI core. It excludes scheduling, rpcd, and the LuCI view.

The initial inventory and live round-trip result are stored in `docs/hardware/bpi-r3-mini-led-inventory.md`. The service/UCI boundary is documented in `docs/architecture/service-and-uci.md`.

## Runtime and design rules

- Target BusyBox `ash` and standard OpenWrt utilities. Do not require Bash, Python, or GNU-only tools on the router.
- Discover LEDs from sysfs at runtime. Do not hard-code LED names or BPI-R3 Mini behaviour.
- Do not infer physical dimming from `max_brightness > 1`: some drivers treat every nonzero value as fully on. The safe default switches all LEDs off; a nonzero multi-level target requires explicit opt-in after hardware calibration. Binary LEDs may gain a sparse pulse mode later.
- Preserve the original LED trigger and state before changing an LED. Restoration must be idempotent and tolerate missing LEDs.
- Keep filesystem access behind a configurable sysfs root so tests can use fixtures instead of a live router.
- Do not implement astronomical calculations. A later scheduling phase uses `sunwait`.
- Keep package defaults write-safe: a fresh install must not change LEDs until the UCI service is explicitly enabled.
- Keep the installed CLI at `root/usr/sbin/led-nightmode`; `bin/led-nightmode` is only a local convenience wrapper.

## Safety and validation

- Do not write to the real router through SSH unless the user explicitly asks for that action.
- Read-only inventory commands are allowed and should precede any router-side implementation test.
- Add tests or fixtures alongside behaviour that depends on sysfs layout, trigger parsing, or state restoration.
- Keep commands in this file accurate. Add build, lint, and test commands only after they exist.

## Commands

- `make check` validates POSIX shell syntax for the CLI, init script, service runner, and tests.
- `make test` runs fixture-backed CLI and service lifecycle tests without touching a real router.

## Project memory

WikiLayer holds project decisions, handoffs, constraints, and next steps. The repository holds source code, tests, executable configuration, and release artifacts.
