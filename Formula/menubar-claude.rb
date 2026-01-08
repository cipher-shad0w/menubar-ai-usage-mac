class MenubarClaude < Formula
  desc "macOS menu bar app for monitoring Claude AI usage"
  homepage "https://github.com/cipher-shad0w/menubar-ai-usage-mac"
  url "https://github.com/cipher-shad0w/menubar-ai-usage-mac/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "fd66d1b64b9efab315be7a0f3b41d726f17b03b8d85f4c8e0ae810724c503161"
  license "MIT"

  depends_on "uv"
  depends_on xcode: ["14.0", :build]

  def install
    # Build the app using xcodebuild
    system "xcodebuild",
           "-project", "menubar-claude/menubar-claude.xcodeproj",
           "-scheme", "menubar-claude",
           "-configuration", "Release",
           "-derivedDataPath", "build",
           "SYMROOT=build",
           "CONFIGURATION_BUILD_DIR=build/Release",
           "CODE_SIGN_IDENTITY=",
           "CODE_SIGNING_REQUIRED=NO",
           "CODE_SIGNING_ALLOWED=NO"

    # Install the app
    prefix.install "build/Release/menubar-claude.app"

    # Create symlink in /Applications
    (prefix/"Applications").mkpath
    ln_s prefix/"menubar-claude.app", "#{prefix}/Applications/menubar-claude.app"
  end

  def caveats
    <<~EOS
      menubar-claude has been installed to:
        #{prefix}/menubar-claude.app

      To run the app:
        open #{prefix}/menubar-claude.app

      Or add it to your login items in System Settings.

      Requirements:
        - You must be logged into Claude AI (claude.ai) in one of these browsers:
          Chrome, Firefox, Brave, Edge, Opera, Chromium, or Vivaldi
        - uv is required and has been installed as a dependency
    EOS
  end

  test do
    # Test that uv is available
    assert_match "uv", shell_output("uv --version")
  end
end
