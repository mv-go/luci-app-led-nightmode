# LuCI LED Night Mode

`luci-app-led-nightmode` is an OpenWrt application for reducing distracting device LEDs at night while preserving the router's normal behaviour.

The first test device is a Banana Pi BPI-R3 Mini. The project is designed for multiple OpenWrt devices and discovers LEDs dynamically through `/sys/class/leds`.

## Current status

The repository includes the hardware-validated CLI core, a UCI/procd service, fixed-time and sunrise/sunset scheduling, an rpcd/ACL interface, a native LuCI view, and an extensible provider interface for indicators outside the Linux LED class. Release `0.5.0-r7` keeps the normal LuCI workflow focused on enablement, current state, and scheduling while moving calibrated brightness, exact solar parameters, provider configuration and tests, LED capability inventory, and technical status under Advanced. It also removes the first device's provider and serial-port hints from fresh installations and treats an empty Linux LED class as a safe no-op. `r7` is fixture-tested, SDK-validated, installed, and live core/provider-validated on the first BPI-R3 Mini; the owner also confirmed its authenticated LuCI view. No multi-device validation is claimed yet.

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

Before a release candidate or pull request, run `make release-check`. Contribution expectations are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md).

GNU Make uses `GNUmakefile` for local checks. When OpenWrt invokes the package with `TOPDIR` set, `GNUmakefile` delegates to the root `Makefile`, which is the OpenWrt LuCI package definition and can be added to an SDK as a package source.

The exact SDK validation procedure and artifact checks are documented in [`docs/building/openwrt-sdk.md`](docs/building/openwrt-sdk.md).

## Service configuration

The installed package provides `/etc/config/led-nightmode` with a safe disabled default:

```text
config core 'main'
	option enabled '0'
	option phase 'day'
	option night_brightness '0'

config schedule 'schedule'
	option mode 'manual'
	option night_start '23:00'
	option day_start '07:00'
	option twilight 'daylight'
	# option latitude '41.7151'
	# option longitude '44.8271'
```

`mode` selects `manual`, `fixed`, or `sun`. Manual mode maintains the core `phase`. Fixed mode uses one daily local-time interval from `night_start` to `day_start`, including intervals that cross midnight. Sun mode obtains the current phase from `sunwait` with explicit decimal coordinates and one of its standard twilight definitions. Both the sysfs core and enabled providers recalculate the phase while running and immediately calculate it again after a service or router restart.

The `luci.led-nightmode` rpcd object exposes status, router timezone name, discovered sysfs LED capabilities, installed provider drivers, and phase resolution to read-authorized LuCI sessions. Manual phase changes, service reloads, explicit provider probes, and reversible indicator tests require write authorization. The RPC layer does not expose arbitrary commands or accept provider paths outside the fixed driver directory.

The LuCI page under **Services → LED Night Mode** shows the applied and scheduled state, provides immediate persistent day/night controls, edits manual, fixed-time, and solar schedules, and configures optional external-indicator providers. Empty solar coordinates are approximated locally from the router's IANA timezone, while an HTTPS-only browser-location button can refine them without an IP-geolocation service. The page separates a read-only provider connection probe from an explicit visual test that temporarily changes and restores the physical indicator. It also explains per-LED reported brightness ranges instead of implying a universal `0–255` scale.

Indicators outside `/sys/class/leds` use optional provider packages. The base package does not scan serial ports, assume modem models, or create a provider section on a fresh installation. After installing a provider package, add an external indicator in LuCI and explicitly select its driver and endpoint. The first provider package supports the validated two-field Quectel `QNWCFG ledmode` interface. The driver interface and contribution rules are documented in [`docs/architecture/providers.md`](docs/architecture/providers.md).

Validated and unvalidated scope is tracked in [`docs/compatibility.md`](docs/compatibility.md). Release gates and the upstream preparation path are in [`docs/releasing.md`](docs/releasing.md).

## Design direction

- `max_brightness > 1` is only an unverified multi-level interface, not proof of physical dimming. The safe default is off; a nonzero target is an explicit, hardware-calibrated opt-in.
- Binary LEDs should support switching off and, in a later phase, a sparse pulse mode.
- Night state survives reboot by determining the current phase on startup.
- Fixed-time scheduling follows the router's local time. Sunrise/sunset scheduling delegates astronomical calculations to `sunwait`.

## Development safety

Implementation must be compatible with BusyBox `ash` and ordinary OpenWrt utilities. Tests should use a fixture-backed sysfs root whenever possible. Changes to a real router require explicit approval.

## License

Apache-2.0. The intended upstream LuCI project is also Apache-2.0 licensed.
