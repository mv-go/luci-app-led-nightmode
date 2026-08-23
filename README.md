# LuCI LED Night Mode

`luci-app-led-nightmode` is an OpenWrt application for reducing distracting device LEDs at night while preserving the router's normal behaviour.

The first test device is a Banana Pi BPI-R3 Mini. The project is designed for multiple OpenWrt devices and discovers LEDs dynamically through `/sys/class/leds`.

## Current status

The repository includes the hardware-validated CLI core, a minimal UCI schema, a procd-managed service, and an extensible provider interface for indicators outside the Linux LED class. Release `0.1.0-r3` builds as two `noarch` APKs with the official OpenWrt 25.12.4 `mediatek/filogic` SDK: the universal base package and an optional Quectel QNWCFG provider. A live `day → night → day → night` cycle on the first BPI-R3 Mini switched off all nine sysfs LEDs and its RM520N-GL LTE indicator, restored both classes during the day, and kept LTE/5G and SSH available.

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

config provider 'lte'
	option enabled '0'
	option driver 'quectel-qnwcfg-ledmode'
	# option device '/dev/ttyUSB3'
```

The service accepts only `day` or `night`. Scheduling, rpcd, and the LuCI view remain later milestones.
Until the LuCI view is implemented, the package does not use `luci.mk` or depend on `luci-base`; installing or building the CLI/service scaffold must not pull in an otherwise unused web interface. The first UI milestone will migrate the package definition to `luci.mk`.

Indicators outside `/sys/class/leds` use optional provider packages. The base package does not scan serial ports or assume modem models. The first provider package supports the validated two-field Quectel `QNWCFG ledmode` interface and is enabled only after an explicit device is configured. The driver interface and contribution rules are documented in [`docs/architecture/providers.md`](docs/architecture/providers.md).

## Design direction

- `max_brightness > 1` is only an unverified multi-level interface, not proof of physical dimming. The safe default is off; a nonzero target is an explicit, hardware-calibrated opt-in.
- Binary LEDs should support switching off and, in a later phase, a sparse pulse mode.
- Night state must survive reboot by determining the current phase on startup.
- Fixed-time and sunrise/sunset schedules come after the CLI prototype. The preferred source of solar events is `sunwait`.

## Development safety

Implementation must be compatible with BusyBox `ash` and ordinary OpenWrt utilities. Tests should use a fixture-backed sysfs root whenever possible. Changes to a real router require explicit approval.

## License

Apache-2.0. The intended upstream LuCI project is also Apache-2.0 licensed.
