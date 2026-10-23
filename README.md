# വെട്ടം (Vettam)

A lightweight, native macOS menu bar app written in Swift to control external displays (specifically tuned for the MSI Modern MD271UL on Apple Silicon) with **zero window overlays**.

---

## Features

- **Icon & Identity:**
  - Status bar icon is rendered as a vector template of the Malayalam letter **വെ** (*Ve* for *Vettam* / Light), seamlessly inverting between Dark and Light Mode.
  - Named **വെട്ടം (Vettam)**.
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

## Launching Vettam

```bash
open Vettam.app
```

Look for the **വെ** icon in your macOS top menu bar!
