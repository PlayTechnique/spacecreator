cask "spacecreator" do
  version "2025-11-28-9"
  sha256 "6dab0270e5c71302d1fe813664c4be032f67c4b0fc295e22f58ab3b5bb88b09e"

  url "https://github.com/PlayTechnique/spacecreator/releases/download/v#{version}/SpaceCreator.zip"
  name "SpaceCreator"
  desc "Create desktop spaces with a keyboard shortcut"
  homepage "https://github.com/PlayTechnique/spacecreator"

  depends_on macos: ">= :ventura"

  app "SpaceCreator.app"

  preflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{staged_path}/SpaceCreator.app"]
  end

  postflight do
    system_command "osascript", args: [
      "-e", 'tell application "System Events" to make login item at end with properties {path:"/Applications/SpaceCreator.app", hidden:false}'
    ]
  end

  uninstall_postflight do
    system_command "osascript", args: [
      "-e", 'tell application "System Events" to delete login item "SpaceCreator"'
    ]
  end

  caveats <<~EOS
    SpaceCreator requires accessibility permissions to create spaces.

    After installation, you may need to:
    1. Open System Settings > Privacy & Security > Accessibility
    2. Enable SpaceCreator in the list

    The app has been added to your login items and will start automatically.
  EOS
end
