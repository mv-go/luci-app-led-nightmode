# OpenWrt SDK build

The CLI/service/provider release is validated against the official OpenWrt 25.12.4 SDK for `mediatek/filogic`:

- SDK: `openwrt-sdk-25.12.4-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst`
- SHA-256: `411a2277ca10f909c30275a506aab4dc28a4f1281d7fda4f19faaa2ded6630bb`
- Package architecture: `noarch`
- Base runtime dependencies: `libc`, `procd`, `sunwait`, and `uci`
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

- `bin/packages/aarch64_cortex-a53/base/luci-app-led-nightmode-0.2.0-r1.apk`;
- `bin/packages/aarch64_cortex-a53/base/led-nightmode-provider-quectel-qnwcfg-ledmode-0.2.0-r1.apk`.

The SDK is an x86_64 Linux build; an ARM64 macOS host must run it in a Linux x86_64 container or virtual machine.

## Validated artifact

Both package builds were checked with the SDK's `apk-tools 3.0.5`:

- `apk verify --allow-untrusted` reported `OK`;
- metadata reported version `0.2.0-r1` and architecture `noarch`;
- `/etc/config/led-nightmode` is registered as a conffile with mode `0600`;
- the init script, schedule resolver, two service runners, CLI, and provider driver have mode `0755`;
- every installed runtime file matched its repository source byte for byte after extraction.

Validated SHA-256 values:

- base APK: `deed91a7cce4033a2652da03178cec35976301421e5cb17239003b53063c0a43`;
- Quectel provider APK: `31cb0de8ed102bff764dddcedeb342d6288e506a262feadd0ce576c771f5f9eb`.

The locally exported artifact is kept under ignored `dist/` and is not committed to Git.
