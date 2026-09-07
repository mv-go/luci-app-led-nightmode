# Upstream package CI failure analysis

The [packages workflow run 33624051808](https://github.com/openwrt/packages/actions/runs/33624051808) tested runtime head `f9d0cf4a1d2519f264852d567741f6c2f5dc0912` and completed on September 7, 2026. Five architecture jobs passed and five failed. All five failed-job logs contain the built `led-nightmode-0.5.1-r1.apk`; their failures occurred in `Test via Docker container`, not in compiling or packaging led-nightmode.

| Architecture | Result and failing boundary | Job |
| --- | --- | --- |
| arm_cortex-a15_neon-vfpv4 | Snapshot kmod index fetch failed before package tests | [Log](https://github.com/openwrt/packages/actions/runs/33624051808/job/101736003082) |
| mips_24kc | Snapshot kmod index fetch failed before package tests | [Log](https://github.com/openwrt/packages/actions/runs/33624051808/job/101736003128) |
| x86_64 | Snapshot kmod index fetch failed before package tests | [Log](https://github.com/openwrt/packages/actions/runs/33624051808/job/101736003185) |
| i386_pentium-mmx | led-nightmode generic tests passed; sunwait version detection failed | [Log](https://github.com/openwrt/packages/actions/runs/33624051808/job/101736003157) |
| aarch64_generic | led-nightmode generic tests passed; sunwait version detection failed | [Log](https://github.com/openwrt/packages/actions/runs/33624051808/job/101736003186) |
| arm_cortex-a9_vfpv3-d16, mipsel_24kc, powerpc_464fp, powerpc_8548, riscv64_generic | Complete jobs passed | [Matrix](https://github.com/openwrt/packages/actions/runs/33624051808) |

## Snapshot repository failures

The first three jobs failed with `wget: exited with error 8`, an unavailable `packages.adb`, and `1 unavailable, 0 stale` while updating the container's repositories. The affected index paths were:

```text
snapshots/targets/armsr/armv7/kmods/6.12.91-1-ccc7e43f4b5bd9dc1c03e464730d7e62/packages.adb
snapshots/targets/malta/be/kmods/6.18.33-1-b6a8a9252df4dd8332daf96f7cf4b276/packages.adb
snapshots/targets/x86/64/kmods/6.18.33-1-70e27cfe28d8cb55760256504e7c02fe/packages.adb
```

This is test-environment repository availability, not an observed led-nightmode failure. An updated, matching snapshot image/index set and a rerun are needed to complete runtime package tests on those architectures. Changing the shell runtime cannot repair a missing kmod repository. A passing build alone must not be reported as a passing complete job.

## Sunwait version mismatch

The i386 and aarch64 jobs installed led-nightmode, checked its executables and symlinks, and passed its version override. They subsequently tested the dependency sunwait and failed with `No executables in the package provided version 0.9.1`. The binary was executable, stripped, linked correctly, and free of hardcoded build paths.

The [0.9.1 source](https://github.com/risacher/sunwait/blob/0.9.1/sunwait.c#L6) stores its version as floating-point `0.91`; `print_version()` formats it with `%f`, yielding `Sunwait Version 0.910000.`. That does not match the feed's package version `0.9.1`. The correct follow-up belongs to sunwait's version reporting or its package-specific version test, while continuing to validate the installed package. Do not weaken led-nightmode's generic test or remove its solar dependency to hide this failure.

No upstream rerun, sunwait patch, or maintainer comment was submitted in this analysis. The closed packages PR remains closed and the dependent LuCI PR remains Draft. A future maintainer response should distinguish this CI triage from the [restoration/lifecycle audit](../architecture/led-subsystem-audit.md); green packaging does not resolve those separate code findings.
