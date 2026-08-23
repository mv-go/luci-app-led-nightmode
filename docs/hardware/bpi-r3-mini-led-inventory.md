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
