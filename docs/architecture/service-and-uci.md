# Service and UCI architecture

The service layer wraps the hardware-validated CLI and keeps sysfs and optional provider indicators on one schedule. OpenWrt package metadata lives in `Makefile`, installed files live under `root/`, and local developer targets live in `GNUmakefile`.

The package intentionally uses ordinary OpenWrt `package.mk` and has no `luci-base` dependency at this milestone because it installs no LuCI view. The first web-interface milestone should migrate the definition to `luci.mk` and add the runtime dependency together with its actual consumer.

## UCI schema

The package owns one `core` section named `main` in `/etc/config/led-nightmode`:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `0` | Whether procd should run an instance. The safe package default performs no LED writes. |
| `phase` | `day` or `night` | `day` | Profile maintained by the service instance. |
| `night_brightness` | non-negative integer | `0` | Target requested for LEDs whose `max_brightness` is greater than 1. Zero is the safe default; a nonzero value is an explicit opt-in after hardware calibration. Binary LEDs always use 0. |

Fixed-time and solar fields remain absent from the core profile schema; the scheduler has its own contract.

The separate `schedule` section named `main` selects how the effective phase is resolved:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `mode` | `manual`, `fixed`, or `sun` | `manual` | Manual uses `core.phase`; fixed uses local wall-clock boundaries; sun delegates the phase calculation to `sunwait`. |
| `night_start` | zero-padded `HH:MM` | `23:00` | Start of the daily fixed night interval, inclusive. |
| `day_start` | zero-padded `HH:MM` | `07:00` | End of the daily fixed night interval, exclusive. It must differ from `night_start`. |
| `latitude` | decimal `-90..90` | none | Required only for sun mode. Positive values are north. |
| `longitude` | decimal `-180..180` | none | Required only for sun mode. Positive values are east. |
| `twilight` | `daylight`, `civil`, `nautical`, or `astronomical` | `daylight` | `sunwait` threshold used by sun mode. |

One fixed interval may either cross midnight, such as `23:00` to `07:00`, or remain within one calendar day. All times use the router's configured local timezone. Polling the local clock instead of caching an epoch means timezone and daylight-saving changes are picked up without rewriting the schedule.

Optional non-sysfs indicators use named `provider` sections:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `0` | Whether this provider instance may change hardware. |
| `driver` | safe identifier | none | Executable driver name below `/usr/libexec/led-nightmode/providers`. |
| `device` | string | none | Explicit transport endpoint interpreted by the selected driver. |

The package ships a disabled `lte` example. A missing or disabled provider performs no probe and no write. Provider-specific commands and dependencies live in separate packages under the [provider contract](providers.md).

## Lifecycle

`/etc/init.d/led-nightmode` validates the UCI sections and registers foreground runners with procd. Configuration changes trigger a service reload. A disabled core section creates no processes and writes no LED state.

The runner resolves and applies the effective phase before entering its foreground loop. Fixed mode rechecks every 15 seconds and sun mode every 60 seconds; the checks sleep between invocations and do not busy-loop. A night instance restores the saved day state when procd stops it, including during disable or reload. A day instance leaves the LEDs restored while remaining observable by procd. The existing CLI state directory remains the only recovery record; restoration failures retain that state for another attempt. `/var/run/led-nightmode/phase` publishes the successfully applied core phase for status consumers and is removed when the service stops.

Each enabled provider gets an independent procd instance. The generic provider runner resolves a safe driver name only inside its fixed driver directory, calculates the phase through the same schedule resolver, and invokes `day` on normal stop. A provider failure does not erase its saved state. Persistent provider state handles devices, such as modems, whose LED setting survives a reboot. procd retries transient initial failures after 30 seconds; an already running instance retains its last successfully applied phase when a later schedule lookup fails.

`sunwait poll` returns distinct exit codes for day and night. The resolver converts signed decimal coordinates from UCI to the cardinal-suffix form expected by `sunwait`; it does not implement astronomical calculations itself.

procd line-buffers captured service stdout by preloading `libsetlbf`. BusyBox `ash` builtins must therefore not own sysfs output descriptors: on the first test platform, builtin `printf` could apply a trigger change and still return status 1 under that preload. The CLI sends scalar values through external `cat`, so the reported status belongs to the actual sysfs write.

## Deferred interfaces

The following remain outside this milestone:

- rpcd methods and ACLs;
- LuCI JavaScript views;
- per-LED overrides and binary pulse mode.
