cask "vettam" do
  version "1.0.0"
  sha256 "a421663d033b0e5f447960d578d3c722827406e5d6e04d3df3ebad78c0fbd950"

  url "https://github.com/rdndas/vettam/releases/download/v#{version}/Vettam-#{version}.dmg"
  name "Vettam"
  desc "Lightweight, zero-overlay macOS menu bar monitor controller"
  homepage "https://github.com/rdndas/vettam"

  depends_on macos: :tahoe

  app "Vettam.app"

  postflight do
    system_command "xattr",
                   args: ["-cr", "#{appdir}/Vettam.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.vettam.app.plist",
  ]
end
