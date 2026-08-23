# luci-app-led-nightmode

## Purpose

Build a universal OpenWrt LED night-mode application. The first test device is a Banana Pi BPI-R3 Mini, but device-specific LED names or assumptions must never enter the general implementation.

## Current milestone

The first milestone is a CLI prototype only. It does not require LuCI, package metadata, an OpenWrt buildroot, UCI, rpcd, or solar scheduling.

The initial read-only inventory is stored in `docs/hardware/bpi-r3-mini-led-inventory.md`.

The milestone is complete only when `led-nightmode night` safely applies a night profile to discovered LEDs and `led-nightmode day` restores the original trigger and state without affecting networking.

## Runtime and design rules

- Target BusyBox `ash` and standard OpenWrt utilities. Do not require Bash, Python, or GNU-only tools on the router.
- Discover LEDs from sysfs at runtime. Do not hard-code LED names or BPI-R3 Mini behaviour.
- Treat `max_brightness > 1` as dimmable; binary LEDs support off and, later, a sparse pulse mode.
- Preserve the original LED trigger and state before changing an LED. Restoration must be idempotent and tolerate missing LEDs.
- Keep filesystem access behind a configurable sysfs root so tests can use fixtures instead of a live router.
- Do not implement astronomical calculations. A later scheduling phase uses `sunwait`.

## Safety and validation

- Do not write to the real router through SSH unless the user explicitly asks for that action.
- Read-only inventory commands are allowed and should precede any router-side implementation test.
- Add tests or fixtures alongside behaviour that depends on sysfs layout, trigger parsing, or state restoration.
- Keep commands in this file accurate. Add build, lint, and test commands only after they exist.

## Commands

- `make check` validates POSIX shell syntax.
- `make test` runs the fixture-backed CLI tests without touching a real router.

## Project memory

WikiLayer holds project decisions, handoffs, constraints, and next steps. The repository holds source code, tests, executable configuration, and release artifacts.
