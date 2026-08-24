# Contributing

Run `make release-check` before submitting a change. Runtime shell must remain compatible with BusyBox `ash`; hardware-dependent behaviour needs an isolated fixture and must not touch a real router without the owner's explicit approval.

Device compatibility reports should include the exact OpenWrt release and target, device model, package revision, read-only `led-nightmode list` output, and the result of an observed night/day restoration. Do not publish serial numbers, credentials, public addresses, or other secrets. Follow [`docs/compatibility.md`](docs/compatibility.md) when assigning an evidence level.

Indicators outside `/sys/class/leds` belong in optional providers. Follow [`docs/architecture/providers.md`](docs/architecture/providers.md); do not add device detection or model tables to the universal core.

Changes intended for OpenWrt upstream must also follow the current `openwrt/luci` contribution rules: a component-prefixed commit subject, an explanatory commit message, and a `Signed-off-by` line with a real first and last name and a non-noreply email address.
