# RPixel (macOS)

<img src="https://github.com/tamayaren/RPixel/blob/main/readmeAssets/Screenshot.png" alt="Reference" width="400"/>
<hr></hr>

**RPixel** removes the ugly black / dark outlines that show up around transparent sprites in **Roblox**, game engines, and graphics software when textures are scaled, filtered (bilinear/trilinear), or mipmapped.

This is the native **Swift for macOS** edition with full **Finder right-click Quick Action** integration, a modern **macOS desktop app**, and a fast **CLI tool**.

<img src="https://github.com/tamayaren/RPixel/blob/main/Icon.png" alt="Reference" width="400"/>

---

## Quick Install

To install RPixel, simply double-click **`Install.command`** in Finder, or run the following in Terminal:

```bash
./install.sh
```

This will automatically:
1. Build `RPixel.app` and install it into `/Applications`.
2. Install the **Finder Quick Action** into `~/Library/Services/` so it appears immediately on right-click.
3. Configure the `RPixel` (and `rpixel`) command-line tool in your PATH (`/usr/local/bin/RPixel`).

---

## How to Use

### 1. Finder Right-Click (Quick Action)
Right-click any PNG file (or multiple selected PNGs or folders) in Finder:
- Select **Quick Actions** ➔ **Fix Alpha with RPixel** (or right-click ➔ **Services** ➔ **Fix Alpha with RPixel**).
- RPixel fixes the alpha bleeding in milliseconds and posts a macOS notification banner when complete.

### 2. Desktop Application (`RPixel.app`)
Open **RPixel.app** from your `/Applications` folder:
- **Drag & Drop**: Drop PNG files or folders directly into the drop zone.
- **Finder Action Status**: Check whether the right-click action is installed with 1-click Install/Uninstall buttons.
- **Debug Mode**: Toggle visible dilated colors (alpha = 255) to visually inspect how edge colors expand into transparent regions.
- **Dock Icon**: You can also drag images directly onto the RPixel icon in your Dock!

### 3. Command Line Interface (`RPixel` / `rpixel`)
Run directly from your terminal:

```bash
# Fix individual images
RPixel sprite1.png sprite2.png

# Fix all PNGs in a folder (recursively)
RPixel ./textures/

# Debug mode: view dilated colors (sets alpha = 255)
RPixel -d character.png

# Manage Finder Quick Action installation
RPixel --install
RPixel --uninstall

# Show help
RPixel --help
```

---

## How It Works

When a game engine or GPU samples textures using bilinear interpolation, pixels near transparent boundaries blend with adjacent transparent pixels. If transparent pixels have an RGB value of `(0, 0, 0, 0)` (black with zero alpha), the linear interpolation creates dark gray/black fringes around sprites.

RPixel uses a parallelized **Jump Flooding Algorithm (JFA + 1)** to calculate the nearest border pixel color for every transparent pixel in linear time (`~6ms` for standard sprites and `<45ms` for 1024×1024 textures). The colors are dilated into the transparent pixels while keeping the alpha channel at `0`. When filtered by the GPU, the interpolated colors blend seamlessly with the sprite borders, completely eliminating the black outline.

---

## Building from Source

Requirements:
- macOS 13.0 or later
- Swift 5.9+ (Command Line Tools or Xcode)

```bash
# Build release binaries
swift build -c release

# Run automated tests
swift run RPixelTests

# Package RPixel.app bundle
./Scripts/build_app.sh
```

---

## Want Windows alternative?

If you want a Windows alternative, please see [xSwezan's Pixfix.](https://github.com/xSwezan/Pixfix)