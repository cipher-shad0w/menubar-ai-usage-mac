cask "menubar-claude" do
  version "0.1.0"
  sha256 "d07c19d1f4adf0119b89295ea0597fc1bfb463a7b15de60e1b514c8517ec0b56"

  url "https://github.com/cipher-shad0w/menubar-ai-usage-mac/releases/download/v#{version}/menubar-claude.zip"
  name "Menubar Claude"
  desc "macOS menu bar app for monitoring Claude AI usage"
  homepage "https://github.com/cipher-shad0w/menubar-ai-usage-mac"

  depends_on formula: "uv"

  app "menubar-claude.app"

  zap trash: [
    "~/Library/Preferences/com.menubar-claude.plist",
    "~/Library/Caches/com.menubar-claude",
  ]
end
