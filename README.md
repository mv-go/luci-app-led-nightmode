# LuCI LED Night Mode

`luci-app-led-nightmode` is an OpenWrt application for reducing distracting device LEDs at night while preserving the router's normal behaviour.

The first test device is a Banana Pi BPI-R3 Mini. The project is designed for multiple OpenWrt devices and discovers LEDs dynamically through `/sys/class/leds`.

## Current status

The repository includes the hardware-validated CLI core, a minimal UCI schema, and a procd service scaffold. A live `night`/`day` round trip has completed successfully on a BPI-R3 Mini: SSH remained available and the final LED configuration matched the initial snapshot exactly. Package `0.1.0-r1` also builds successfully as a `noarch` APK with the official OpenWrt 25.12.4 `mediatek/filogic` SDK.

## CLI core

Build a standalone CLI prototype with these commands:

- `led-nightmode list`
- `led-nightmode status`
- `led-nightmode night`
- `led-nightmode day`

`night` applies a safe night profile to discovered LEDs. `day` restores each affected LED's original trigger and state.

## Local usage

The CLI defaults to the real sysfs and `/var/run`, so local development should always provide fixture paths:

```sh
LED_SYSFS_ROOT=/path/to/fixture/sys/class/leds \
LED_STATE_DIR=/path/to/fixture/state \
LED_SYSFS_EMULATE=1 \
./bin/led-nightmode list
```

Run all local checks with:

```sh
make test
```

GNU Make uses `GNUmakefile` for local checks. When OpenWrt invokes the package with `TOPDIR` set, `GNUmakefile` delegates to the root `Makefile`, which is the OpenWrt package definition. The current CLI/service milestone uses ordinary `package.mk` and can be added to an SDK as a package source.

The exact SDK validation procedure and artifact checks are documented in [`docs/building/openwrt-sdk.md`](docs/building/openwrt-sdk.md).

## Service configuration

The installed package provides `/etc/config/led-nightmode` with a safe disabled default:

```text
config core 'main'
	option enabled '0'
	option phase 'day'
	option night_brightness '0'
```

The service accepts only `day` or `night`. Scheduling, rpcd, and the LuCI view remain later milestones.
Until the LuCI view is implemented, the package does not use `luci.mk` or depend on `luci-base`; installing or building the CLI/service scaffold must not pull in an otherwise unused web interface. The first UI milestone will migrate the package definition to `luci.mk`.

## Design direction

- `max_brightness > 1` is only an unverified multi-level interface, not proof of physical dimming. The safe default is off; a nonzero target is an explicit, hardware-calibrated opt-in.
- Binary LEDs should support switching off and, in a later phase, a sparse pulse mode.
- Night state must survive reboot by determining the current phase on startup.
- Fixed-time and sunrise/sunset schedules come after the CLI prototype. The preferred source of solar events is `sunwait`.

## Development safety

Implementation must be compatible with BusyBox `ash` and ordinary OpenWrt utilities. Tests should use a fixture-backed sysfs root whenever possible. Changes to a real router require explicit approval.

## License

Apache-2.0. The intended upstream LuCI project is also Apache-2.0 licensed.
