# OpenWrt SDK build

The CLI/service/LuCI/provider release candidate is built against the official OpenWrt 25.12.4 SDK for `mediatek/filogic`:

- SDK: `openwrt-sdk-25.12.4-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst`
- SHA-256: `411a2277ca10f909c30275a506aab4dc28a4f1281d7fda4f19faaa2ded6630bb`
- Package architecture: `noarch`
- Base runtime dependencies: `libc`, `luci-base`, `jshn`, `procd`, `rpcd`, `sunwait`, and `uci`
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

The OpenWrt 25.12 outputs use these filenames under `bin/packages/aarch64_cortex-a53/<feed>/`; the feed directory depends on how the package source was linked into the SDK:

- `luci-app-led-nightmode-0.5.0-r7.apk`;
- `led-nightmode-provider-quectel-qnwcfg-ledmode-0.5.0-r7.apk`.

The SDK is an x86_64 Linux build; an ARM64 macOS host must run it in a Linux x86_64 container or virtual machine.

Some minimal SDK environments retain `CONFIG_LUCI_JSMIN=y` without shipping the host-side `jsmin` executable. In that case, build this package with `CONFIG_LUCI_JSMIN=` on both the clean and compile invocations. This produces the supported unminified LuCI assets and avoids incomplete `.js.o` temporary files:

```sh
make package/luci-app-led-nightmode/clean CONFIG_LUCI_JSMIN=
make package/luci-app-led-nightmode/compile V=sc CONFIG_LUCI_JSMIN=
```

## Validated artifact

Both `0.5.0-r7` package builds were checked with the SDK's `apk-tools 3.0.5`:

- `apk verify --allow-untrusted` reported `OK`;
- metadata reported version `0.5.0-r7` and architecture `noarch`;
- `/etc/config/led-nightmode` is registered as a conffile with mode `0600` and contains no device-specific provider default;
- the init script, UCI migration, shared service executable, two service runners, CLI, and provider driver have mode `0755`; the schedule and rpcd entry points are package symlinks to the shared executable; the ACL, LuCI menu, JavaScript view, and timezone-coordinate module have mode `0644`;
- the package contains no `.js.o` temporary files;
- every installed runtime file matched its repository source byte for byte after extraction.

Validated SHA-256 values:

- base APK: `48bda130edd8b53c56166d1296e4c5a595bb06b0263dcc4e2945ae5a7c94d82d`;
- Quectel provider APK: `07601c8b282dc99b5500fdd4b3e49df6cab1e4e0599d8aabf9739b6564233206`.

The locally exported artifact is kept under ignored `dist/` and is not committed to Git.
