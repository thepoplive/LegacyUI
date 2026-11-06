# LegacyUI

Liquid Glass inspired system interface redesign for iOS 8.

## Features

- **Lock Screen**: Complete visual redesign with adaptive clock and notifications
- **Dock**: Floating Liquid Glass capsule design
- **Control Center**: Modern glass-inspired interface
- **Volume HUD**: Compact floating glass pill

## Requirements

- iOS 8.0 - 8.4.1
- A jailbroken device
- MobileSubstrate
- PreferenceLoader

## Building

This project uses GitHub Actions for building. On each push to main, the workflow will:
1. Build the tweak using the iOS 10.3 SDK
2. Package as a .deb file
3. Upload artifacts

## Installation

1. Build the project (via GitHub Actions or locally on macOS)
2. Transfer the .deb to your device
3. Install via dpkg: `dpkg -i LegacyUI_*.deb`
4. Respring

## Settings

Configure through Settings > LegacyUI

## License

MIT