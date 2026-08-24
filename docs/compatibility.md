# Compatibility

Compatibility is recorded as evidence, not inferred from a router name, CPU architecture, or an LED driver's reported brightness range. A device that is not listed below may still work, but it is not yet claimed as validated.

## Evidence levels

| Level | Meaning |
| --- | --- |
| Design-compatible | The device exposes standard Linux LED class files or uses an explicit optional provider. No hardware test has been recorded. |
| Fixture-tested | The relevant sysfs or provider lifecycle is covered by an isolated test fixture. |
| SDK-built | Both packages build and verify in an official OpenWrt SDK. This proves packaging, not physical LED behaviour. |
| Live core-validated | A night/day round trip preserved and restored the physical router's sysfs LED state. |
| Live provider-validated | Probe, visible change, and exact restoration were observed on the stated hardware and firmware. |

## OpenWrt and package matrix

| OpenWrt | Target / architecture | Package | Evidence | Notes |
| --- | --- | --- | --- | --- |
| 25.12.4 | `mediatek/filogic`, `aarch64_cortex-a53` | `0.5.0-r7` | SDK-built; live core/provider-validated | Installed and round-trip validated on the first live router. |
| Other releases and targets | Any | `0.5.0-r7` | Not yet validated | The packages are architecture-independent, but that alone is not a compatibility claim. |

## Device matrix

| Device | OpenWrt | Linux LED class | External indicators | Evidence | Remaining check |
| --- | --- | --- | --- | --- | --- |
| Banana Pi BPI-R3 Mini | 25.12.4 | Nine discovered LEDs; seven binary and two physically binary despite reporting 255 levels | Quectel-managed LTE indicator; hard-wired PWR is not software-controllable | Core and provider live-validated through `0.5.0-r7`; the owner confirmed the authenticated LuCI view; detailed inventory is in [`hardware/bpi-r3-mini-led-inventory.md`](hardware/bpi-r3-mini-led-inventory.md) | Validate another physical OpenWrt device before making multi-device claims. |
| Empty LED-class fixture | Host-side fixture | Zero LEDs | None | Fixture-tested as a safe no-op in `r7` | A real provider-only or virtual OpenWrt target is still desirable. |

## Sysfs behaviour matrix

| Behaviour | Evidence |
| --- | --- |
| Binary LED, arbitrary name | Fixture-tested night/day round trip. |
| `max_brightness > 1` | Fixture-tested with safe default off and explicit calibrated nonzero target. Physical dimming is never inferred. |
| Active trigger with writable trigger-specific attributes | Fixture-tested save and restore. |
| Read-only trigger attribute | Fixture-tested skip when saving and safe handling while restoring. |
| LED disappears before restore | Fixture-tested failure with saved state retained for a later retry. |
| No LEDs in `/sys/class/leds` | Fixture-tested successful no-op, allowing provider-only or virtual systems to remain usable. |
| LED outside Linux LED class | Unsupported by the core; requires a separately installed provider. |

## Provider matrix

| Driver | Hardware / firmware | Transport | Evidence | Scope |
| --- | --- | --- | --- | --- |
| `quectel-qnwcfg-ledmode` | Quectel RM520N-GL, `RM520NGLAAR03A04M4G_01.202.01.202` | Explicit AT port configured by the user | Fixture lifecycle plus live probe, visible off/on test, scheduled transition, and exact restoration through `r7` | Only the validated two-field `AT+QNWCFG="ledmode"` response. Other Quectel models or firmware are not implied. |

## Qualifying another device

1. Record the exact OpenWrt release, target, device model, and package revision.
2. Run the read-only LED inventory first and record names, `max_brightness`, current brightness, and active triggers.
3. Confirm that the default configuration remains disabled after installation.
4. With recovery access available, perform one explicit night/day round trip and verify every original trigger and brightness value is restored.
5. Treat any nonzero brightness target as a separate physical calibration; never infer dimming from sysfs metadata.
6. For an external indicator, run the provider's read-only probe, then its explicit reversible visual test, and record the exact hardware and firmware.
7. Add the evidence to this matrix and add a fixture whenever a new sysfs shape or provider behaviour is discovered.

The base package never scans serial ports or selects a hardware provider. A fresh install contains no provider section; users add one explicitly in LuCI after installing a provider package.
