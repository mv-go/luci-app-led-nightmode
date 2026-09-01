# BPI-R3 Mini LED inventory

This is a read-only snapshot of `/sys/class/leds` from the first test router. The CLI must discover the same properties at runtime rather than treating this list as a device-specific configuration.

## Observed LEDs

| LED | Max brightness | Current brightness | Active trigger | Timer parameters |
| --- | ---: | ---: | --- | --- |
| `blue:wlan-1` | 1 | 1 | `netdev` | absent |
| `blue:wlan-2` | 1 | 0 | `netdev` | absent |
| `green:status` | 1 | 1 | `none` | absent |
| `mdio-bus:0e:green:lan` | 1 | 0 | `netdev` | absent |
| `mdio-bus:0e:yellow:lan` | 1 | 0 | `netdev` | absent |
| `mdio-bus:0f:green:wan` | 1 | 0 | `netdev` | absent |
| `mdio-bus:0f:yellow:wan` | 1 | 0 | `netdev` | absent |
| `mt76-phy0` | 255 | 0 | `phy0tpt` | absent |
| `mt76-phy1` | 255 | 0 | `phy1tpt` | absent |

## Available triggers

Every observed LED reports this trigger set:

`none`, `timer`, `heartbeat`, `default-on`, `netdev`, `pattern`, `mmc0`, `phy0rx`, `phy0tx`, `phy0assoc`, `phy0radio`, `phy0tpt`, `phy1rx`, `phy1tx`, `phy1assoc`, `phy1radio`, `phy1tpt`.

## Implications for the CLI prototype

- Seven LEDs are binary and need a state-preserving off profile.
- `mt76-phy0` and `mt76-phy1` expose `max_brightness=255`, but this does not make them physically dimmable. The mt7915 driver maps zero to off and every nonzero value to on in [`mt7915_led_set_brightness()`](https://github.com/torvalds/linux/blob/master/drivers/net/wireless/mediatek/mt76/mt7915/init.c). The prototype must preserve their active throughput trigger before applying a brightness profile.
- No timer parameter files are present in the observed state. Pulse support must therefore be capability-driven and not assumed from the presence of the `timer` trigger alone.
- The six LEDs using `netdev` expose writable trigger-specific settings such as `device_name`, `interval`, `link`, `rx`, and `tx`. Ethernet LEDs also expose writable link-speed selectors. These values must be captured before switching to `none` and restored after re-selecting `netdev`.

## Live round-trip validation

An explicitly approved live test applied `night` to all nine LEDs and then restored them with `day`. SSH remained available throughout. The seven binary LEDs used brightness 0, while the two mt76 LEDs used brightness 1. Visual observation showed that the mt76 LEDs remained fully lit: on this driver, 1 and 255 have the same physical result. The safe default is therefore 0 for every LED; a nonzero value for an unverified multi-level interface requires explicit calibration and opt-in.

The Ethernet LED driver rejected rewriting `interval` when the value was already 50. Restoration now skips trigger attributes whose current value already matches the saved value. A retry restored the remaining link-speed, RX, and TX selectors, removed the saved state, and produced a final snapshot identical to the initial snapshot.

## Installed package lifecycle validation

Package `0.1.0-r2` completed two procd-managed live cycles: `day → night → day` and `day → night → stop`. In both cycles all nine LEDs reported brightness 0 with trigger `none` during the night phase. SSH remained available, the service reported no errors, and restoration removed the saved state. A stable snapshot containing active triggers and trigger-specific parameters had the same SHA-256 before the second night phase and after service stop.

The preceding `0.1.0-r1` package exposed a BusyBox/procd interaction. Capturing service stdout makes procd preload `/lib/libsetlbf.so`; an `ash` builtin `printf` redirected to a sysfs trigger then changed the trigger but returned status 1. The CLI treated that status as a failed trigger selection and skipped the brightness write, leaving `green:status` on. The scalar writer now pipes through external `cat`, whose exit status represents the sysfs write correctly under the same preload.

## Front-panel LEDs outside sysfs

Visual validation found two front-panel indicators that are not represented in `/sys/class/leds`:

- `PWR` is hard-wired to the board's 3.3 V rail (`LED11` in the BPI-R3 Mini V1.0 schematic). It has no GPIO or software control path and therefore remains lit during the sysfs night profile.
- `LTE` is driven by the M.2 modem's `LED_WWAN#`/network-status output (`LTE_NET_STU` in the board schematic). It is not a SoC LED and cannot be discovered through the Linux LED class.

The first router contains a Quectel RM520N-GL with firmware `RM520NGLAAR03A04M4G_01.202.01.202`. A live query returned `AT+QNWCFG="ledmode"` as `0,0`. Setting it to `0,1` switched the modem's network-light output to the firmware's all-lights-off mode while ModemManager remained connected over LTE/5G and `wwan0` retained its address.

This command is device- and firmware-specific. The generic CLI does not send it merely because an LTE interface exists. Release `0.1.0-r3` adds the separately packaged `quectel-qnwcfg-ledmode` provider, which requires an explicit AT port, rejects unsupported response shapes, saves the original pair in persistent state, applies the second-field all-lights-off value, verifies writes, and restores the exact pair during the day.

The installed `r3` packages completed a live `night → day → night` provider cycle. The LTE indicator changed from `0,1` to the saved `0,0` during the day and back to `0,1` at night. All nine sysfs LEDs restored their original triggers during the day and returned to brightness 0 at night. ModemManager remained connected with LTE and 5G NR access, `wwan0` stayed up with the same address, and the service logged no restoration or provider errors. `PWR` remains outside software control.

## Scheduling and RPC live validation

Release `0.4.0-r4` was installed over `0.1.0-r3`. Its UCI migration preserved the enabled core, manual night phase, brightness, and LTE provider while adding a complete named schedule section. Manual RPC actions completed a `night → day → night` round trip; day restored the original sysfs triggers and modem mode `0,0`, and night returned all nine sysfs LEDs to brightness 0 and the modem to `0,1`. The read-only provider probe reported the installed driver and supported two-field response.

A fixed interval crossing the next local minute changed the effective phase from night to day on the runner's own 15-second poll without a reload at the boundary. Solar mode delegated to the installed `sunwait`: Tbilisi coordinates resolved to day, while a control location that was currently after dark resolved to night and switched both the sysfs and modem providers. The final configuration was restored to manual night with `23:00` and `07:00` defaults and no stored coordinates.

Live upgrade testing found and fixed three release-boundary defects before `r4`: colon-containing UCI validation defaults, rpcd JSON without a trailing newline, and a provider reload race caused by the default procd termination timeout. Three consecutive `r4` reloads each finished with one provider instance and modem mode `0,1`, with no SIGKILL or restoration error. ModemManager remained connected with LTE and 5G NR throughout. Installed runtime files matched the repository byte for byte. The native LuCI view remains locally browser-validated; live browser interaction stopped at the router login because the test browser had no authenticated session.

Release `0.5.0-r2` was installed over `r4` through an intermediate `r1` build. The upgrade preserved the complete UCI configuration and persistent provider state. The new `status` timezone field, `leds` inventory, read-only probe, and reversible visual test were verified live. The visual test completed exact `0,0 → 0,1 → 0,0` and `0,1 → 0,0 → 0,1` round trips without replacing managed night state; ModemManager remained connected with LTE and 5G NR.

Manual, fixed, and solar live checks restored sysfs triggers during day and returned all nine LEDs to brightness 0 at night. Tbilisi coordinates resolved to day, while a control longitude resolved to night. One initial solar provider attempt encountered temporary AT-port contention and exposed a 30-second procd respawn delay. Release `r2` keeps the provider runner alive and retries transient application failures in-process. Fixture coverage reproduces the first-attempt failure, and repeated live reloads with `r2` ended with one provider process, modem mode `0,1`, and no SIGKILL or restoration error. The final router configuration is manual night with `23:00` and `07:00` defaults and no stored coordinates.

The first authenticated live LuCI load of `r2` exposed that the bundled timezone-coordinate helper returned a plain object, while the LuCI loader requires every required module to return a `baseclass` subclass constructor. Release `0.5.0-r3` exports the helper through `baseclass.extend()`, adds a regression assertion for this loader contract, and passes both local rendered QA and the live router's module-loading stage without the previous TypeError.

Release `0.5.0-r6` reorganizes LuCI into a simple Settings tab and an Advanced tab without changing the UCI or runtime contracts. The package upgrade preserved the router's saved solar schedule, exact coordinates, civil twilight, and enabled LTE provider. After restart the schedule resolved to Day, sysfs LEDs restored their normal triggers, the provider reported `0,0`, and ModemManager remained connected with LTE and 5G NR. The installed view matched the SDK artifact and repository byte for byte. Full rendered QA passed locally; authenticated visual confirmation on the live LuCI session remains the final UI check.

Release `0.5.0-r7` was installed over `r6` from the two APKs produced by the green GitHub SDK workflow. The package manager preserved `/etc/config/led-nightmode` byte for byte and placed the new write-safe universal default in `led-nightmode.apk-new`; the restored configuration remains enabled in solar mode with coordinates `41.6759, 44.8330`, civil twilight, and the explicit LTE provider. Both packages report `0.5.0-r7`, and the installed minified LuCI assets match the downloaded APK contents byte for byte.

An explicit manual `day → night → day` service round trip switched all nine sysfs LEDs to brightness 0 with trigger `none`, changed the modem response from `0,0` to `0,1`, and restored the normal sysfs triggers and modem response `0,0`. ModemManager continued to expose the Quectel RM520N-GL, and `wwan0` remained up with the same address. The exact pre-test UCI SHA-256 returned after restoring solar mode, the service reported a valid effective Day phase, and both provider and core processes remained running. Live access uses the SSH host alias `router`, which selects the dedicated key; connecting directly as `root@router.bpi.home.arpa` bypasses that alias and does not select the key. The owner subsequently confirmed the authenticated installed LuCI view visually.

Later cold starts performed after the solar schedule had entered Night reproduced a boot-order defect in `r7`: LuCI reported the effective Night phase and Off target while the sysfs indicators continued blinking. The package init priority was 95, so it applied the night profile before OpenWrt's stock `led` init script at priority 96 restored the normal triggers.

Candidate `0.5.0-r8` moves LED Night Mode to priority 97 and migrates an enabled legacy `S95led-nightmode` link during upgrade. Both official-SDK APKs were installed over `r7`; the package manager preserved `/etc/config/led-nightmode` at its exact pre-upgrade SHA-256, and autostart moved from `S95` to `S97`. With the schedule temporarily forced to Night, a software reboot logged the stock `S96led` setup first and the night profile immediately afterward. Once startup completed, all nine sysfs LEDs reported trigger `none`, brightness `0`, and managed state `yes`. The modem endpoint initially rejected two writes while booting, then the existing retry loop applied `0,1`; the router retained working IP connectivity throughout.

After validation, the exact original solar configuration was restored with SHA-256 `3126314b1cb3a25addc8fb64c0920351cce3acbe266279c262a730dd62ba1e7b`. The schedule resolved to Day, normal sysfs triggers returned, the modem reported `0,0`, and both managed processes remained running. This verifies the corrected OpenWrt init sequence on real hardware. The owner subsequently confirmed the expected result after a physical unplug/replug at Night, completing validation of the original power-loss path.
