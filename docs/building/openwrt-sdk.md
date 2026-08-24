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

## GitHub workflow validation

The manual [OpenWrt SDK run 32731204783](https://github.com/mv-go/luci-app-led-nightmode/actions/runs/32731204783) completed successfully for commit `25d39a28bdc0af7256140bdbf7e0e8ab1fdd80ab`. Its downloaded artifact contained exactly the two candidate APKs and no SDK dependency packages or build logs.

SHA-256 values of the GitHub-uploaded APKs:

- base APK: `97070522987be9d1d994d4c2a348a7b542a70d8c904e2fe203bf89623343483e`;
- Quectel provider APK: `a943e338c1b60e2c55c98b7680d2e88f986bf5e3f4b0d035c8111ef62ef4d626`.

These hashes identify the remote workflow outputs; the independent local SDK outputs above have their own hashes because APK build metadata is not byte-for-byte reproducible between the two build environments.

## Upstream snapshot validation

The universal application was staged as `applications/luci-app-led-nightmode` against LuCI `master` commit `5cb5db64213d712d1ca325dd895b4e1cd2340d50`. The staged tree uses LuCI's relative `../../luci.mk`, contains the generic sysfs core and provider interface, and deliberately excludes the device-specific Quectel provider package.

The [Upstream LuCI run 32741903478](https://github.com/mv-go/luci-app-led-nightmode/actions/runs/32741903478) completed successfully. It performed current LuCI JavaScript and JSON lint, regenerated and compared the translation template, then built the staged application with the official OpenWrt snapshot SDK for `aarch64_cortex-a53`. The snapshot toolchain reported GCC 14.4.0 and produced one `noarch` package:

- `luci-app-led-nightmode-0.5.0-r7.apk`;
- SHA-256 `0c33bae9722512bdd277ca557d8b6ad17f5623332c0e488e17092497a70b214e`.

The package build metadata recorded the expected dependencies on `luci-base`, `jshn`, `procd`, `rpcd`, `sunwait`, and `uci`. The downloaded workflow artifact also contains the package build logs; no provider APK is present in the upstream artifact.
