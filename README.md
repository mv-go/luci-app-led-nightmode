# LuCI LED Night Mode

`luci-app-led-nightmode` is an OpenWrt application for reducing distracting device LEDs at night while preserving the router's normal behaviour.

The first test device is a Banana Pi BPI-R3 Mini. The project is designed for multiple OpenWrt devices and discovers LEDs dynamically through `/sys/class/leds`.

## Current status

The repository includes the first CLI prototype and fixture-backed tests. A live `night`/`day` round trip has completed successfully on a BPI-R3 Mini: SSH remained available and the final LED configuration matched the initial snapshot exactly.

## First milestone

Build a standalone CLI prototype with these commands:

- `led-nightmode list`
- `led-nightmode status`
- `led-nightmode night`
- `led-nightmode day`

`night` must apply a safe night profile to discovered LEDs. `day` must restore each affected LED's original trigger and state. This milestone deliberately excludes LuCI, package build integration, UCI, rpcd, and time-based scheduling.

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

## Design direction

- Dimmable LEDs (`max_brightness > 1`) should use real brightness reduction.
- Binary LEDs should support switching off and, in a later phase, a sparse pulse mode.
- Night state must survive reboot by determining the current phase on startup.
- Fixed-time and sunrise/sunset schedules come after the CLI prototype. The preferred source of solar events is `sunwait`.

## Development safety

Implementation must be compatible with BusyBox `ash` and ordinary OpenWrt utilities. Tests should use a fixture-backed sysfs root whenever possible. Changes to a real router require explicit approval.

## License

Apache-2.0. The intended upstream LuCI project is also Apache-2.0 licensed.
