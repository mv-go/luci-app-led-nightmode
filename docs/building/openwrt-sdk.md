# OpenWrt SDK build

The CLI/service milestone is validated against the official OpenWrt 25.12.4 SDK for `mediatek/filogic`:

- SDK: `openwrt-sdk-25.12.4-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst`
- SHA-256: `411a2277ca10f909c30275a506aab4dc28a4f1281d7fda4f19faaa2ded6630bb`
- Package architecture: `noarch`
- Runtime dependencies: `libc`, `procd`, and `uci`

The SDK archive and checksum are published in the [OpenWrt 25.12.4 mediatek/filogic downloads](https://downloads.openwrt.org/releases/25.12.4/targets/mediatek/filogic/).

## Build

Place this repository in the SDK package tree, enable it, and run the package target:

```sh
ln -s /path/to/luci-app-led-nightmode package/luci-app-led-nightmode
make defconfig
printf '%s\n' 'CONFIG_PACKAGE_luci-app-led-nightmode=m' >> .config
make defconfig
make package/luci-app-led-nightmode/compile V=sc
```

The output for OpenWrt 25.12 is `bin/packages/aarch64_cortex-a53/luci/luci-app-led-nightmode-0.1.0-r2.apk`. The SDK is an x86_64 Linux build; an ARM64 macOS host must run it in a Linux x86_64 container or virtual machine.

## Validated artifact

The package build was checked with the SDK's `apk-tools 3.0.5`:

- `apk verify --allow-untrusted` reported `OK`;
- metadata reported version `0.1.0-r2` and architecture `noarch`;
- `/etc/config/led-nightmode` is registered as a conffile with mode `0600`;
- the init script, service runner, and CLI have mode `0755`;
- all four installed files matched their repository sources byte for byte after extraction.

The validated `0.1.0-r2` artifact has SHA-256 `ee9f51c4c64088fdcd716e346adbb0d28349d42ed00da66c711fb178db644858`.

The locally exported artifact is kept under ignored `dist/` and is not committed to Git.
