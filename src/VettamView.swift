// VettamView.swift — Liquid Glass Native SwiftUI Menu Bar Panel
import SwiftUI

public struct VettamView: View {
    @ObservedObject var manager = DisplayManager.shared
    @ObservedObject var hotkeys = HotkeyManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if manager.showingSettings {
                settingsView
            } else {
                mainControlsView
            }
        }
        .padding(14)
        .frame(width: 320, height: 420, alignment: .top)
        .background(.ultraThinMaterial)
    }

    // MARK: - Main Controls View
    private var mainControlsView: some View {
        VStack(spacing: 12) {
            // Header
            headerView

            // Sliders
            VStack(spacing: 8) {
                sliderRow(
                    systemImage: "sun.max",
                    title: "Brightness",
                    valueText: "\(Int(manager.brightness * 100))%",
                    value: $manager.brightness,
                    range: 0.0...1.0
                )

                sliderRow(
                    systemImage: "circle.righthalf.filled",
                    title: "Contrast",
                    valueText: "\(Int(manager.contrast * 100))%",
                    value: $manager.contrast,
                    range: 0.0...1.0
                )

                sliderRow(
                    systemImage: "thermometer.medium",
                    title: "Warmth",
                    valueText: "\(Int(manager.warmth))K",
                    value: $manager.warmth,
                    range: 3000.0...6500.0
                )
            }

            // Segmented Profile Control
            profilePicker

            // Hardware DDC Drawer (USB-C/DP Only)
            if let display = manager.activeDisplay, display.isHardwareDDCActive {
                hardwareSection
            }

            Spacer(minLength: 0)

            // Main Page Action Buttons: Reset Defaults & Quit Vettam + Settings Link
            mainPageActionsView
        }
    }

    // MARK: - Header (Clean Sleep Button with No Default Focus Ring)
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("Vettam")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(manager.activeDisplay?.name ?? "External Display")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(manager.activeDisplay?.isHardwareDDCActive == true ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    Text(manager.activeDisplay?.isHardwareDDCActive == true ? "Hardware DDC (USB-C)" : "Software Gamma (HDMI)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(manager.activeDisplay?.isHardwareDDCActive == true ? Color.green : Color.orange)
                }
            }

            Spacer()

            Button(action: {
                manager.isSleeping.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: manager.isSleeping ? "moon.fill" : "moon")
                        .font(.system(size: 11))
                    Text(manager.isSleeping ? "Wake" : "Sleep")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .focusable(false) // Prevents blue focus ring outline when popover opens!
        }
        .padding(.bottom, 4)
    }

    // MARK: - Sliders
    private func sliderRow(
        systemImage: String,
        title: String,
        valueText: String,
        value: Binding<Float>,
        range: ClosedRange<Float>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(valueText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(value: value, in: range)
                    .controlSize(.mini)
                    .focusable(false)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Profile Picker
    private var profilePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROFILES")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                profileButton(title: "Standard", id: "standard") {
                    manager.brightness = 0.80
                    manager.contrast = 0.50
                    manager.warmth = 6500.0
                    manager.isMonochrome = false
                }

                profileButton(title: "Monochrome", id: "reading") {
                    manager.brightness = 0.60
                    manager.contrast = 0.45
                    manager.warmth = 5500.0
                    manager.isMonochrome = true
                }

                profileButton(title: "Warm Night", id: "warm") {
                    manager.brightness = 0.35
                    manager.contrast = 0.50
                    manager.warmth = 3400.0
                    manager.isMonochrome = false
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func profileButton(title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            manager.activeProfile = id
            action()
        }) {
            Text(title)
                .font(.system(size: 11, weight: manager.activeProfile == id ? .semibold : .medium))
                .foregroundStyle(manager.activeProfile == id ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(manager.activeProfile == id ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Hardware Section
    private var hardwareSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HARDWARE DDC (USB-C)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            sliderRow(
                systemImage: "speaker.wave.2",
                title: "Headphone Jack",
                valueText: "\(Int(manager.headphoneVolume * 100))%",
                value: $manager.headphoneVolume,
                range: 0.0...1.0
            )
        }
    }

    // MARK: - Main Page Actions: Reset & Quit + Settings
    private var mainPageActionsView: some View {
        VStack(spacing: 8) {
            // Hotkey Hint & Settings Link
            HStack {
                Text("Keys: \(hotkeys.downShortcut.displayString) / \(hotkeys.upShortcut.displayString)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    manager.launchAtLoginEnabled = LaunchAtLoginHelper.isEnabled
                    manager.showingSettings = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                        Text("Settings")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            // Direct Reset Defaults & Quit Vettam buttons on Main Screen
            HStack(spacing: 8) {
                Button(action: {
                    manager.brightness = 1.0
                    manager.contrast = 0.5
                    manager.warmth = 6500.0
                    manager.isMonochrome = false
                    manager.isSleeping = false
                    manager.activeProfile = "standard"
                }) {
                    Text("Reset Defaults")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .focusable(false)

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit Vettam")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Apple HIG Settings View
    private var settingsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button("Done") {
                    manager.showingSettings = false
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .focusable(false)
            }
            .padding(.bottom, 2)

            // Section 1: General (Launch at Login)
            VStack(alignment: .leading, spacing: 5) {
                Text("GENERAL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text("Launch at Login")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { manager.launchAtLoginEnabled },
                        set: {
                            manager.launchAtLoginEnabled = $0
                            LaunchAtLoginHelper.isEnabled = $0
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Section 2: Keyboard Shortcuts (Apple Style Keycaps)
            VStack(alignment: .leading, spacing: 5) {
                Text("KEYBOARD SHORTCUTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    shortcutRow(
                        label: "Brightness Down",
                        action: .brightnessDown,
                        comboString: hotkeys.downShortcut.displayString
                    )

                    shortcutRow(
                        label: "Brightness Up",
                        action: .brightnessUp,
                        comboString: hotkeys.upShortcut.displayString
                    )
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Section 3: Display Details
            VStack(alignment: .leading, spacing: 5) {
                Text("ACTIVE DISPLAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    detailRow(title: "Display", value: manager.activeDisplay?.name ?? "External")
                    detailRow(title: "Connection", value: manager.activeDisplay?.transport ?? "Unknown")
                    detailRow(title: "Engine", value: manager.activeDisplay?.isHardwareDDCActive == true ? "Hardware DDC" : "Software Gamma")
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 0)
        }
    }

    private func shortcutRow(label: String, action: ShortcutAction, comboString: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button(action: {
                hotkeys.isListeningFor = action
            }) {
                Text(hotkeys.isListeningFor == action ? "Record..." : comboString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        hotkeys.isListeningFor == action
                            ? Color.accentColor
                            : Color.primary.opacity(0.08)
                    )
                    .foregroundStyle(hotkeys.isListeningFor == action ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}
