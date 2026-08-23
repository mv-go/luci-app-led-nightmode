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
- `mt76-phy0` and `mt76-phy1` are dimmable, but their observed brightness is zero while their throughput triggers are active. The prototype must preserve the active trigger before applying a brightness profile.
- No timer parameter files are present in the observed state. Pulse support must therefore be capability-driven and not assumed from the presence of the `timer` trigger alone.
- The six LEDs using `netdev` expose writable trigger-specific settings such as `device_name`, `interval`, `link`, `rx`, and `tx`. Ethernet LEDs also expose writable link-speed selectors. These values must be captured before switching to `none` and restored after re-selecting `netdev`.
