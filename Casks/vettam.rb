cask "vettam" do
  version "1.0.0"
  sha256 "487cceb28576feb188500165ca6f15d85a45264b21d2a16dd09dc87ff3b402b7"

  url "https://github.com/rdndas/vettam/releases/download/v#{version}/Vettam-#{version}.dmg"
  name "Vettam"
  desc "Lightweight, zero-overlay macOS menu bar monitor controller"
  homepage "https://github.com/rdndas/vettam"

  app "Vettam.app"

  postflight do
    system_command "xattr",
                   args: ["-cr", "#{appdir}/Vettam.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.vettam.app.plist",
  ]
end
