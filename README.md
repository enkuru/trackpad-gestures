# Trackpad Gestures

A small menu bar app that adds these trackpad gestures:

| Gesture | Action |
|---|---|
| Tap with three fingers side by side | Middle click at the pointer |
| Rest one finger, tap another to its left | Volume down |
| Rest one finger, tap another to its right | Volume up |
| Rest two fingers, tap a third between them | Mute / unmute |

The resting fingers must already be down for about a tenth of a second before the tap, so ordinary two- and three-finger taps don't trigger the volume gestures. The tap must also land within 4 cm of each resting finger, so a tap out near the edge doesn't count.

All gestures are ignored for a second after you press a key, so a hand brushing the trackpad while you type doesn't change the volume.

Works on macOS 14 or later, on Apple silicon and Intel Macs, with the built-in trackpad or a Magic Trackpad. A Magic Mouse is ignored.

## Install

1. Download `TrackpadGestures-<version>.zip` from the [latest release](../../releases/latest) and unzip it.
2. Move **TrackpadGestures.app** to your Applications folder and open it.
3. macOS blocks it the first time, because the app isn't notarized by Apple. Click **Done**.
4. Open System Settings → Privacy & Security, scroll down to the message about TrackpadGestures and click **Open Anyway**. Confirm with your password, then click **Open**.
5. When the app asks for **Accessibility** permission, turn on *TrackpadGestures* in System Settings → Privacy & Security → Accessibility. It needs this to send the click and the volume keys.

A hand icon appears in the menu bar. To start the app automatically, choose **Open at Login** from that icon.

If you're comfortable with Terminal, this command replaces steps 3 and 4:

```bash
xattr -dr com.apple.quarantine /Applications/TrackpadGestures.app
```

### macOS setting that clashes

System Settings → Trackpad → Point & Click → **Look up & data detectors**: if it is set to *Tap with three fingers*, a three-finger tap also opens Look Up. Set it to *Force Click with One Finger*.

## Updating

Quit the app from its menu, replace it in Applications with the new version, and open it (steps 3 and 4 again). Every version looks like a new app to macOS, so the old Accessibility permission stops working: remove *TrackpadGestures* from the Accessibility list with **–**, then grant it again when asked.

## Uninstall

Turn off **Open at Login**, quit from the menu, delete the app and remove it from the Accessibility list.

## Build from source

Needs Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./install.sh   # build, copy to ~/Applications and open
./release.sh   # build and zip into dist/ for a release
```

Both produce one app for Apple silicon and Intel, signed ad hoc.

### Tuning

The timing and distance thresholds are in `GestureTuning` in `Sources/GestureCore/GestureRecognizer.swift`. To watch what the app sees:

```bash
log stream --predicate 'subsystem == "io.github.enkuru.TrackpadGestures"'
```

### Tests

With Xcode installed, run `swift test`. With only the Command Line Tools, the Swift Testing library needs its paths spelled out:

```bash
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
```

## How it works

Raw touches come from macOS's private MultitouchSupport framework, the same source MiddleClick, Jitouch and BetterTouchTool use. `GestureCore` turns the touch frames into gestures. The app sends the middle click as a mouse event and the volume changes as the keyboard's media keys, so the normal volume overlay appears. Because the framework is private, a macOS update could break the app.

## License

MIT
