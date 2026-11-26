#!/bin/bash
# macos/defaults.sh: macOS settings captured from Zach's MacBook Pro on 2026-11-25.
# Only values that differ from a fresh macOS install are set. Re-runnable.
# To capture a new setting: change it in System Settings, then find it with
#   defaults read > /tmp/before.txt; (change it); defaults read > /tmp/after.txt; diff /tmp/before.txt /tmp/after.txt
set -euo pipefail

echo "==> Applying macOS defaults"

# Dock: auto-hide with no delay, icon size 63, magnify to 77, keep Spaces order fixed
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock tilesize -int 63
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 77
defaults write com.apple.dock mru-spaces -bool false

# Finder: path bar, status bar, new windows open Documents
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder NewWindowTarget -string "PfDo"

# Global: dark mode, show all file extensions, fast key repeat
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 25

# Trackpad: tap to click (built-in and Bluetooth trackpads, and the login screen)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Screenshots: no window shadow
defaults write com.apple.screencapture disable-shadow -bool true

killall Dock Finder SystemUIServer 2>/dev/null || true
echo "==> macOS defaults applied (some need a logout to take effect)"
