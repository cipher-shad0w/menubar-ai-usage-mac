# Menubar Claude

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" alt="Platform: macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Python-3.11+-blue.svg" alt="Python 3.11+">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT">
</p>

A native macOS menu bar application that monitors your Claude AI API usage in real-time. Track your 5-hour and 7-day usage windows directly from your menu bar without leaving your workflow.

## Features

- 🚀 **Real-time Monitoring** - Displays Claude usage percentage directly in your menu bar
- 📊 **Dual Window Tracking** - Monitor both 5-hour and 7-day usage windows
- 🔒 **Secure** - Uses browser cookies for authentication (no API keys required)
- 🎨 **Native macOS UI** - Clean SwiftUI interface that follows system appearance
- 🔄 **Auto-refresh** - Updates usage data every 30 seconds
- 🌈 **Color-coded Status** - Visual indicators for usage levels (green, yellow, orange, red)
- 🦊 **Multi-browser Support** - Works with Chrome, Firefox, Brave, Safari, Edge, Opera, Chromium, and Vivaldi
- ⚡ **Lightweight** - Minimal resource usage with efficient background updates

## Screenshots

The app displays your current Claude usage percentage in the menu bar and provides detailed information in a dropdown panel including:
- Current utilization percentage for both windows
- Messages sent and remaining
- ETA until usage resets
- Color-coded status indicators

## Requirements

- macOS 13.0 (Ventura) or later
- [uv](https://docs.astral.sh/uv/) - Fast Python package installer
- Active Claude AI account logged into one of the supported browsers

## Installation

### Homebrew (Recommended)

```bash
brew tap cipher-shad0w/homebrew-menubar-claude
brew install --cask menubar-claude
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/cipher-shad0w/menubar-ai-usage-mac.git
cd waybar-ai-usage-mac
```

2. Install `uv` if not already installed:
```bash
brew install uv
```

3. Build the app:
```bash
cd menubar-claude
xcodebuild -project menubar-claude.xcodeproj \
           -scheme menubar-claude \
           -configuration Release \
           -derivedDataPath build
```

4. Copy the app to your Applications folder:
```bash
cp -r build/Build/Products/Release/menubar-claude.app /Applications/
```

5. Launch the app:
```bash
open /Applications/menubar-claude.app
```

## Usage

1. **First Launch**: Make sure you're logged into Claude AI (claude.ai) in one of the supported browsers
2. The app will automatically appear in your menu bar showing your current usage percentage
3. Click on the menu bar item to view detailed usage information
4. The app will refresh automatically every 30 seconds

### Understanding Usage Windows

- **5-Hour Window**: Rate limit window that resets every 5 hours
- **7-Day Window**: Rolling 7-day usage limit

The menu bar displays the percentage of the primary window (7-day if ≥80%, otherwise 5-hour).

### Status Colors

- 🟢 **Green** (0-60%): Normal usage
- 🟡 **Yellow** (60-80%): Moderate usage
- 🟠 **Orange** (80-95%): High usage
- 🔴 **Red** (95-100%): Critical usage

## Architecture

The app consists of two main components:

1. **SwiftUI macOS App** - Native menu bar interface built with Swift
2. **Python Backend** - Fetches usage data from Claude API using browser cookies

### Project Structure

```
menubar-claude/
├── menubar-claude/
│   ├── menubar_claudeApp.swift      # Main app entry point
│   ├── Models/                       # Data models
│   │   ├── ClaudeUsageModels.swift
│   │   └── SupportedBrowser.swift
│   ├── ViewModels/                   # Business logic
│   │   └── ClaudeUsageViewModel.swift
│   ├── Views/                        # UI components
│   │   └── ClaudeUsageView.swift
│   └── Resources/                    # Python scripts
│       ├── claude.py
│       ├── common.py
│       └── pyproject.toml
└── menubar-claude.xcodeproj/         # Xcode project files
```

## Configuration

The app automatically detects and uses cookies from your browsers. No manual configuration is required.

### Python Dependencies

The Python backend uses:
- `browser-cookie3>=0.20.1` - For reading browser cookies
- `curl-cffi>=0.13.0` - For making authenticated requests to Claude API

These are automatically installed via `uv` when the app launches.

## Troubleshooting

### "No valid cookies found" Error

- Make sure you're logged into Claude AI in one of the supported browsers
- Try refreshing the Claude AI page in your browser
- Clear browser cache and log in again

### "403 Forbidden" Error

- Update `browser-cookie3`: `uv pip install --upgrade browser-cookie3`
- Refresh the Claude AI page in your browser
- Try switching to a different browser

### App Not Showing Usage

- Check that you have an active Claude AI subscription
- Ensure you're in an organization (check the `lastActiveOrg` cookie)
- Try manually refreshing by reopening the dropdown

### Permission Issues

If the app can't access browser cookies, you may need to grant permissions in:
**System Settings** → **Privacy & Security** → **Full Disk Access**

## Development

### Building from Source

1. Clone the repository
2. Open `menubar-claude.xcodeproj` in Xcode
3. Ensure `uv` is installed: `brew install uv`
4. Build and run the project (⌘R)

### Testing Python Scripts

You can test the Python backend independently:

```bash
cd menubar-claude/menubar-claude/Resources
uv run python claude.py --json
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Based on the [waybar-ai-usage](https://github.com/NihilDigit/waybar-ai-usage) project
- Built with SwiftUI and Python
- Uses `curl-cffi` for authenticated API requests
- Uses `browser-cookie3` for cookie extraction

## Related Projects

- [waybar-ai-usage](https://github.com/cipher-shad0w/waybar-ai-usage) - Linux/Waybar version for monitoring Claude and ChatGPT usage

## Roadmap

- [ ] Notification system for high usage alerts
- [ ] Usage history graphs
- [ ] Add as login item
- [ ] Custom refresh intervals

## Support

If you encounter any issues or have questions:
- Open an [issue](https://github.com/cipher-shad0w/menubar-ai-usage-mac/issues)
- Check existing issues for solutions

---

Made with ❤️ for the Claude AI community
