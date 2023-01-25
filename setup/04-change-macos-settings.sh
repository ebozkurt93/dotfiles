#!/bin/bash

# Fonts
echo ""
echo "Install custom fonts?"
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  ./install-fonts.sh || (echo "Installing fonts failed, exiting..." && exit)
fi

# Custom binaries
echo ""
echo "Install custom binaries?"
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  ./install-mirror.sh || (echo "Installing mirror failed, exiting..." && exit)
  ./install-cheatsh.sh || (echo "Installing cheat.sh failed, exiting..." && exit)
  ./install-wally.sh || (echo "Installing wally failed, exiting..." && exit)
  # ./install-rclone.sh || (echo "Installing rclone failed, exiting..." && exit)
fi

# Keyboard
echo ""
echo "Disabling press-and-hold for special keys in favor of key repeat"
# defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 10 # normal minimum is 15 (225 ms)

echo ""
echo "Setting a blazingly fast keyboard repeat rate"
# defaults write -g KeyRepeat -int 0
defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)

echo ""
echo "Disable auto-correct"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Mouse & Trackpad
echo ""
echo "Setting trackpad & mouse speed to a reasonable number"
defaults write -g com.apple.trackpad.scaling 2
defaults write -g com.apple.mouse.scaling 2.5

# Screen
echo ""
echo "Requiring password immediately after sleep or screen saver begins"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Screenshots
echo ""
echo "Change screenshot save location to Desktop"
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

echo ""
echo "Setting screenshot format to PNG"
defaults write com.apple.screencapture type -string "png"

# Finder
echo ""
echo "Show hidden files in Finder by default"
defaults write com.apple.finder AppleShowAllFiles TRUE

echo ""
echo "Show status bar in Finder by default"
defaults write com.apple.finder ShowStatusBar -bool true

echo ""
echo "Show path bar in Finder by default"
defaults write com.apple.finder ShowPathbar -bool true

# Dock
echo ""
echo "Setting the icon size of Dock items"
defaults write com.apple.dock tilesize -int 48

echo ""
echo "Set Dock to auto-hide and remove the auto-hiding delay"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

echo ""
echo "Move Dock to left"
defaults write com.apple.dock orientation left

dock_item() {
  if [[ "$1" == *"{"* ]]; then
    echo "$1"
  else
    printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>', "$1"
  fi
}

echo ""
echo "Wipe all (default) app icons from the Dock and add some sensible defaults? (y/n)"
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
  apps=(
  "/System/Applications/Launchpad.app"
  "/Applications/Safari.app"
  "/System/Applications/Utilities/Terminal.app"
  "/System/Applications/App Store.app"
  "/System/Applications/System Settings.app"
  )
  for val in "${apps[@]}"; do
    defaults write com.apple.dock persistent-apps -array-add "$(dock_item "$val")"
  done
fi

# todo: remove the killall here
killall Dock

# Safari
echo ""
echo "Privacy: Don't send search queries to Apple"
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

echo ""
echo "Enabling Safari's debug menu"
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

echo ""
echo "Enabling the Develop menu and the Web Inspector in Safari"
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
