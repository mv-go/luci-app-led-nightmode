# OpenWrt SDK build

The CLI/service/provider release is validated against the official OpenWrt 25.12.4 SDK for `mediatek/filogic`:

- SDK: `openwrt-sdk-25.12.4-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst`
- SHA-256: `411a2277ca10f909c30275a506aab4dc28a4f1281d7fda4f19faaa2ded6630bb`
- Package architecture: `noarch`
- Base runtime dependencies: `libc`, `procd`, and `uci`
- Quectel provider dependencies: the base package and `picocom`

The SDK archive and checksum are published in the [OpenWrt 25.12.4 mediatek/filogic downloads](https://downloads.openwrt.org/releases/25.12.4/targets/mediatek/filogic/).

## Build

Place this repository in the SDK package tree, enable it, and run the package target:

```sh
ln -s /path/to/luci-app-led-nightmode package/luci-app-led-nightmode
make defconfig
printf '%s\n' 'CONFIG_PACKAGE_luci-app-led-nightmode=m' >> .config
printf '%s\n' 'CONFIG_PACKAGE_led-nightmode-provider-quectel-qnwcfg-ledmode=m' >> .config
make defconfig
make package/luci-app-led-nightmode/compile V=sc
```

The OpenWrt 25.12 outputs are:

- `bin/packages/aarch64_cortex-a53/luci/luci-app-led-nightmode-0.1.0-r3.apk`;
- `bin/packages/aarch64_cortex-a53/luci/led-nightmode-provider-quectel-qnwcfg-ledmode-0.1.0-r3.apk`.

The SDK is an x86_64 Linux build; an ARM64 macOS host must run it in a Linux x86_64 container or virtual machine.

## Validated artifact

Both package builds were checked with the SDK's `apk-tools 3.0.5`:

- `apk verify --allow-untrusted` reported `OK`;
- metadata reported version `0.1.0-r3` and architecture `noarch`;
- `/etc/config/led-nightmode` is registered as a conffile with mode `0600`;
- the init script, two service runners, CLI, and provider driver have mode `0755`;
- every installed runtime file matched its repository source byte for byte after extraction.

Validated SHA-256 values:

- base APK: `0d3e881a1435522b0db37619848c7ff6f2fe8319f4e67feac9b4ff825bb694eb`;
- Quectel provider APK: `aa6754a925e996ece6f96575aae87dd8cfa005f7caa38446c3c7eb7a078cdbb0`.

The locally exported artifact is kept under ignored `dist/` and is not committed to Git.
