#!/bin/bash
echo ""
echo "Setting the icon size of Dock items"
defaults write com.apple.dock tilesize -int 42

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
echo "Add apps to Dock"
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
apps=(
# "/System/Applications/Launchpad.app"
"/Applications/Google Chrome.app"
"/Applications/Spotify.app"
"/Applications/Pocket Casts.app"
# "{'tile-type'='small-spacer-tile';}"
"/Applications/Ghostty.app"
"/Applications/Slack.app"
# "{'tile-type'='small-spacer-tile';}"
"/Applications/Obsidian.app"
"/Applications/ChatGPT.app"
# "/Applications/MacPass.app"
# "/System/Applications/App Store.app"
# "/System/Applications/System Settings.app"
)
for val in "${apps[@]}"; do
  if [[ "$val" =~ .app$ ]] && [[ ! -d "$val" ]]; then
    echo "Skipping $val since not found"
    continue
  else
    defaults write com.apple.dock persistent-apps -array-add "$(dock_item "$val")"
  fi
done
# Check link for options -> https://github.com/yannbertrand/macos-defaults/issues/62
defaults write com.apple.dock 'persistent-others' -array-add $(printf '<dict><key>tile-data</key><dict><key>arrangement</key><integer>0</integer><key>displayas</key><integer>0</integer><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict><key>preferreditemsize</key><integer>-1</integer><key>showas</key><integer>0</integer></dict><key>tile-type</key><string>directory-tile</string></dict>', "$HOME/Downloads")

killall Dock
