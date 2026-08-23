# Service and UCI architecture

The service layer wraps the hardware-validated CLI without adding scheduling, RPC, or LuCI behaviour. OpenWrt package metadata lives in `Makefile`, installed files live under `root/`, and local developer targets live in `GNUmakefile`.

The package intentionally uses ordinary OpenWrt `package.mk` and has no `luci-base` dependency at this milestone because it installs no LuCI view. The first web-interface milestone should migrate the definition to `luci.mk` and add the runtime dependency together with its actual consumer.

## UCI schema

The package owns one `core` section named `main` in `/etc/config/led-nightmode`:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `0` | Whether procd should run an instance. The safe package default performs no LED writes. |
| `phase` | `day` or `night` | `day` | Profile maintained by the service instance. |
| `night_brightness` | non-negative integer | `0` | Target requested for LEDs whose `max_brightness` is greater than 1. Zero is the safe default; a nonzero value is an explicit opt-in after hardware calibration. Binary LEDs always use 0. |

Fixed-time and solar schedule fields are intentionally absent. They require a separate scheduler contract and should not change the core profile schema.

## Lifecycle

`/etc/init.d/led-nightmode` validates the UCI section and registers a foreground runner with procd. Configuration changes trigger a service reload. A disabled section creates no process and writes no LED state.

The runner applies the configured phase once and stays in the foreground. A night instance restores the saved day state when procd stops it, including during disable or reload. A day instance leaves the LEDs restored while remaining observable by procd. The existing CLI state directory remains the only recovery record; restoration failures retain that state for another attempt.

procd line-buffers captured service stdout by preloading `libsetlbf`. BusyBox `ash` builtins must therefore not own sysfs output descriptors: on the first test platform, builtin `printf` could apply a trigger change and still return status 1 under that preload. The CLI sends scalar values through external `cat`, so the reported status belongs to the actual sysfs write.

## Deferred interfaces

The following remain outside this milestone:

- fixed-time and sunrise/sunset scheduling;
- boot-time phase calculation;
- rpcd methods and ACLs;
- LuCI JavaScript views;
- per-LED overrides and binary pulse mode.
