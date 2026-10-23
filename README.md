# Vettam

A lightweight, native macOS menu bar app written in Swift to control external monitors (specifically tuned for the MSI Modern MD271UL on Apple Silicon) with **zero window overlays**.

*Named after the Malayalam word for light (വെട്ടം).*

---

## The HDMI vs. USB-C Reality (Why DDC/CI Might Not Work Over HDMI)

On Apple Silicon Macs (M1/M2/M3/M4), the built-in HDMI port routes through an internal DisplayPort-to-HDMI converter chip. While monitor identification (EDID) passes through, **DDC/CI command packets (VCP commands for physical backlight and hardware contrast) are blocked or return NULL replies over HDMI on macOS**.

### How Vettam Handles This Without Window Overlays

Most third-party monitor dimmer apps solve the HDMI limitation by creating **semi-transparent black window overlays** over your screens. 

#### Why Window Overlays Are Problematic:
- They appear in screenshots, screen recordings, and screen-sharing calls (making your recordings artificially dark).
- They can cause mouse cursor lag and click-through bugs.
- They wash out contrast and black levels instead of providing true luminance attenuation.
- They break when switching macOS Spaces or entering native full-screen video.

#### Vettam's Zero-Overlay Approach:

| Capability | Hardware DDC/CI (USB-C / DP) | Vettam Software Gamma (HDMI) | Typical Dimmer Apps (Window Overlays) |
|---|---|---|---|
| **Dimming Mechanism** | Direct monitor hardware scaler | **GPU Hardware Lookup Table (`CGSetDisplayTransferByTable`)** | Semi-transparent black `NSWindow` overlay |
| **Window Overlays** | None | **Zero (Native GPU color pipeline)** | Yes (Sticky desktop overlay) |
| **Screenshots & Recordings** | Clean & natural | **Clean & natural (Bypasses capture pipeline)** | Captured screenshots appear dark/dimmed |
| **Mouse & Cursor** | Native 120Hz/60Hz | **Native 120Hz/60Hz** | Often lags or shows cursor artifacts |
| **Connection Path** | USB-C (DisplayPort Alt Mode) | Built-in HDMI or HDMI adapters | Any connection |

- **When connected via HDMI**: Vettam automatically operates in **Software Gamma Mode**. It manipulates the GPU's native ColorSync gamma transfer curves directly inside the macOS graphics compositor. You get smooth, responsive brightness, contrast, and color warmth control with **zero window overlays**.
- **When connected via USB-C (DisplayPort Alt Mode)**: Vettam automatically detects hardware DDC/CI support and unlocks direct hardware communication with the monitor's internal scaler, allowing you to control the physical LED backlight.

---

## Features

- **Icon & Identity:**
  - Status bar icon is rendered as a clean vector template, seamlessly inverting between Dark and Light Mode.
  - Pure English UI and system integration.
- **Hybrid Display Engine:**
  - **Zero-Overlay GPU Gamma Control:** Works immediately over HDMI via macOS GPU lookup tables (`CGSetDisplayTransferByTable`).
  - **Direct Hardware DDC/CI Control:** Automatically activates when connected via USB-C (DP Alt Mode) or DisplayPort, with scaler bus pacing (50ms) and EEPROM write coalescing (120ms debounce).
- **Display Controls:**
  - **Brightness:** 0% to 100% with a safety floor (never blacks out the screen).
  - **Contrast:** S-curve dynamic range stretching/flattening.
  - **Color Warmth:** 6500K daylight down to 3000K warm candlelight.
  - **Reading / Monochrome Mode:** Grayscale luminance curve mapping for an e-ink style reading experience.
  - **Display Sleep:** One-click display blanking without putting your Mac to sleep.
- **Customizable Multi-Modifier Shortcuts:**
  - Default: `⌘ + ⌃ + ⇧ + ↑` (Brightness Up) and `⌘ + ⌃ + ⇧ + ↓` (Brightness Down).
  - Click to re-record with any key or modifier combination.
- **Launch at Login:**
  - Uses modern Apple `SMAppService` framework.

---

## Installation & Setup

### Option 1: Download the Installer (Recommended)

1. Go to the [Releases](https://github.com/rdndas/vettam/releases) page.
2. Download the latest installer package: **`Vettam-1.0.0-installer.pkg`** (or the portable **`.zip`**).
3. Double-click the `.pkg` file and follow the standard macOS setup wizard. It will automatically place **`Vettam.app`** directly into your **`/Applications`** folder.
4. Launch **Vettam** from Launchpad or Spotlight (`⌘ + Space` $\rightarrow$ `Vettam`). Look for the icon in your top menu bar!

> [!NOTE]
> **First Launch on macOS (Gatekeeper):**
> Because Vettam is an independent open-source tool built outside the Mac App Store, macOS Gatekeeper may prompt you on first launch. If prompted:
> - Right-click (or Control-click) `Vettam.app` in `/Applications` and select **Open**, then click **Open** in the dialog.
> - Alternatively, go to **System Settings $\rightarrow$ Privacy & Security**, scroll down, and click **Open Anyway**.

---

### Option 2: Build from Source

Requirements: macOS 12+ and Swift compiler (`swiftc` via Command Line Tools or Xcode).

```bash
git clone https://github.com/rdndas/vettam.git
cd vettam
./build.sh
open Vettam.app
```
