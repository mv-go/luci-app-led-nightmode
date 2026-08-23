# Non-sysfs LED providers

The Linux LED class remains the universal core. Indicators controlled by a modem, storage device, board controller, or another subsystem are supported through optional provider drivers. Device-specific commands must not enter the sysfs CLI or its service runner.

## Provider contract

Installed drivers are executable files under `/usr/libexec/led-nightmode/providers`. A driver name is a safe identifier containing only letters, digits, `_`, and `-`. The generic provider runner passes these environment variables:

- `LED_PROVIDER_DEVICE`: the explicitly configured device or transport endpoint;
- `LED_PROVIDER_INSTANCE`: the named UCI provider section;
- `LED_PROVIDER_STATE_DIR`: persistent private state for that instance.

A driver implements four commands:

| Command | Behaviour |
| --- | --- |
| `probe` | Perform a read-only capability check and fail unless the configured endpoint speaks the expected protocol. |
| `status` | Report the current hardware state and whether saved state exists. |
| `night` | Save the original state once, apply the night state, and verify the result. Repeated calls must not replace the original state. |
| `day` | Restore and verify the saved state, then remove it. Missing state is a successful no-op. |

Provider state defaults to `/etc/led-nightmode/state/providers/<instance>` because hardware outside sysfs may retain settings across a reboot or power loss. The driver must retain state after any failed write or failed restoration.

The service never searches serial ports or guesses a device from its marketing name. A user or future LuCI view explicitly enables a driver and endpoint after `probe` succeeds. Unknown hardware remains untouched.

## Packaging and contributions

Provider drivers are separate OpenWrt packages. The base `luci-app-led-nightmode` package has no serial-terminal dependency. The first optional package, `led-nightmode-provider-quectel-qnwcfg-ledmode`, adds `picocom` and a driver for the two-field `AT+QNWCFG="ledmode"` response whose second field supports an all-lights-off state.

Adding hardware support means adding a provider driver, fixture-backed lifecycle tests, package metadata, and at least one documented hardware/firmware validation. A new driver should be used when command syntax or restoration semantics differ. Extending a central model-name table is not part of the architecture.

## First validated provider

The `quectel-qnwcfg-ledmode` driver is explicitly configured with an AT port. It queries and saves both numeric fields returned by `AT+QNWCFG="ledmode"`, preserves the first field, changes the second field to `1` at night, and restores the exact original pair during the day. It rejects single-field or otherwise unexpected responses.

The initial target is a Quectel RM520N-GL running firmware `RM520NGLAAR03A04M4G_01.202.01.202`. Its secondary AT port is `/dev/ttyUSB3` on the first BPI-R3 Mini, but that path belongs only in that router's UCI configuration and is not a driver default.
