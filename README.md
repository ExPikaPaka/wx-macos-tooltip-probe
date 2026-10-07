# wx macOS tooltip probe

OrcaSlicer's UV editor draws its tool strip with `UVToolButton`, a bare `wxWindow`
subclass that paints itself and calls `SetToolTip()` in its constructor. Those
tooltips do not appear on macOS, while the same build shows them on Windows.

This builds that shape of widget beside controls whose tooltips are known to work,
then asks AppKit two questions on a real Mac:

- does the widget's `NSView` carry the tooltip at all (`[NSView toolTip]`)
- does a tooltip window actually appear when the cursor rests on it

The first separates a tooltip that was never registered from one that is
registered but never shown; the second needs no accessibility grant, so it runs
unattended on a CI runner.

Run it from the Actions tab, or locally on a Mac:

```sh
brew install wxwidgets
cmake -S . -B build && cmake --build build -j && ./build/probe
```
