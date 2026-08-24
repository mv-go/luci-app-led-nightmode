# Service and UCI architecture

The service layer wraps the hardware-validated CLI and keeps sysfs and optional provider indicators on one schedule. OpenWrt package metadata lives in `Makefile`, installed files live under `root/`, and local developer targets live in `GNUmakefile`.

The package uses OpenWrt `luci.mk` and depends on `luci-base` because it installs a native LuCI view and its rpcd/ACL boundary.

## UCI schema

The package owns one `core` section named `main` in `/etc/config/led-nightmode`:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `0` | Whether procd should run an instance. The safe package default performs no LED writes. |
| `phase` | `day` or `night` | `day` | Profile maintained by the service instance. |
| `night_brightness` | non-negative integer | `0` | Raw target requested for LEDs whose `max_brightness` is greater than 1 and clamped independently to each reported maximum. Zero is the safe default; a nonzero value is an explicit advanced opt-in after hardware calibration. Binary LEDs always use 0, and `max_brightness > 1` does not prove physical dimming. |

Fixed-time and solar fields remain absent from the core profile schema; the scheduler has its own contract.

The separate `schedule` section named `schedule` selects how the effective phase is resolved. Its name is intentionally distinct from the core section because UCI section identifiers are unique within a package:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `mode` | `manual`, `fixed`, or `sun` | `manual` | Manual uses `core.phase`; fixed uses local wall-clock boundaries; sun delegates the phase calculation to `sunwait`. |
| `night_start` | zero-padded `HH:MM` | `23:00` | Start of the daily fixed night interval, inclusive. |
| `day_start` | zero-padded `HH:MM` | `07:00` | End of the daily fixed night interval, exclusive. It must differ from `night_start`. |
| `latitude` | decimal `-90..90` | none | Required only for sun mode. Positive values are north. |
| `longitude` | decimal `-180..180` | none | Required only for sun mode. Positive values are east. |
| `twilight` | `daylight`, `civil`, `nautical`, or `astronomical` | `daylight` | `sunwait` threshold used by sun mode. |

One fixed interval may either cross midnight, such as `23:00` to `07:00`, or remain within one calendar day. All times use the router's configured local timezone. Polling the local clock instead of caching an epoch means timezone and daylight-saving changes are picked up without rewriting the schedule.

An install-time UCI migration adds the named schedule section when upgrading a pre-scheduling configuration. It never replaces an existing schedule or changes the enabled flag or current manual phase. The init script also supplies complete `23:00` and `07:00` fallbacks without embedding colon-containing values in the `uci_validate_section` schema.

Optional non-sysfs indicators use named `provider` sections:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `0` | Whether this provider instance may change hardware. |
| `driver` | safe identifier | none | Executable driver name below `/usr/libexec/led-nightmode/providers`. |
| `device` | string | none | Explicit transport endpoint interpreted by the selected driver. |

Fresh installations contain no provider section: the base package cannot safely guess a modem driver or transport endpoint. A missing or disabled provider performs no probe and no write. Users add an explicit provider instance after installing the matching driver package; provider-specific commands and dependencies live in separate packages under the [provider contract](providers.md). Existing provider sections are preserved during upgrades.

## Lifecycle

`/etc/init.d/led-nightmode` validates the UCI sections and registers foreground runners with procd. Configuration changes trigger a service reload. A disabled core section creates no processes and writes no LED state.

The runner resolves and applies the effective phase before entering its foreground loop. Fixed mode rechecks every 15 seconds and sun mode every 60 seconds; the checks sleep between invocations and do not busy-loop. A night instance restores the saved day state when procd stops it, including during disable or reload. A day instance leaves the LEDs restored while remaining observable by procd. The existing CLI state directory remains the only recovery record; restoration failures retain that state for another attempt. `/var/run/led-nightmode/phase` publishes the successfully applied core phase for status consumers and is removed when the service stops.

Each enabled provider gets an independent procd instance. The generic provider runner resolves a safe driver name only inside its fixed driver directory, calculates the phase through the same schedule resolver, and invokes `day` on normal stop. Provider instances receive a 20-second procd termination window so an in-flight hardware command and saved-state restoration can finish before a reload starts the replacement instance. A provider failure does not erase its saved state. Persistent provider state handles devices, such as modems, whose LED setting survives a reboot. procd retries transient initial failures after 30 seconds; an already running instance retains its last successfully applied phase when a later schedule lookup fails.

`sunwait poll` returns distinct exit codes for day and night. The resolver converts signed decimal coordinates from UCI to the cardinal-suffix form expected by `sunwait`; it does not implement astronomical calculations itself.

## rpcd and ACL boundary

The base package registers `luci.led-nightmode` as an rpcd exec object. Its methods are deliberately narrower than shell or unrestricted UCI access:

| Method | ACL | Behaviour |
| --- | --- | --- |
| `status` | read | Reports whether the service is enabled and running, the configured mode, the applied runtime phase, and the currently resolved desired phase. |
| `leds` | read | Returns runtime-discovered sysfs LED names, current values, reported maxima, triggers, and the conservative binary/unverified-multilevel classification used by LuCI. |
| `resolve` | read | Validates the stored schedule and returns the phase it selects now without changing hardware. |
| `drivers` | read | Lists safe identifiers for installed executable provider drivers; it does not probe hardware or scan endpoints. |
| `probe` | write | Runs one installed provider's read-only `probe` command with an explicit safe driver name and endpoint. It does not scan devices. |
| `test` | write | Runs one installed provider's explicit visual round trip. The driver temporarily changes the indicator and must restore its exact initial state. |
| `set_manual` | write | Atomically selects manual scheduling, stores a validated `day` or `night` phase, commits UCI, and reloads the service. |
| `reload` | write | Reloads the validated service after ordinary UCI changes. |

The ACL grants read sessions only status/inventory/phase-resolution methods and read access to the `led-nightmode` UCI package. Provider probes, visual tests, and every state-changing method require the write grant. Driver names remain fixed-directory identifiers, device strings are passed only as environment values, and no RPC input is evaluated as a command.

`status` also returns the router's `system.@system[0].zonename`. LuCI uses a bundled compact map generated from IANA tzdb `zone1970.tab` to prefill representative coordinates when solar mode has no saved location. This is an explicitly approximate local hint and makes no runtime network request. An optional browser Geolocation action can replace it with user-approved coordinates in a secure LuCI session; the values stay in the unsaved form until the normal Save & Apply flow stores them.

procd line-buffers captured service stdout by preloading `libsetlbf`. BusyBox `ash` builtins must therefore not own sysfs output descriptors: on the first test platform, builtin `printf` could apply a trigger change and still return status 1 under that preload. The CLI sends scalar values through external `cat`, so the reported status belongs to the actual sysfs write.

## Deferred interfaces

The following remain outside this milestone:

- per-LED overrides and binary pulse mode.
