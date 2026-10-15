#!/bin/sh

# installs the launchd job that runs scripts/ai-warmup every morning

label=com.subin.ai-warmup
src=~/.dotfiles-macos/launchd/$label.plist
dest=~/Library/LaunchAgents/$label.plist

# launchd skips symlinked plists at login, so copy it
mkdir -p ~/Library/LaunchAgents
cp "$src" "$dest"

launchctl bootout "gui/$(id -u)/$label" 2> /dev/null
launchctl bootstrap "gui/$(id -u)" "$dest"

echo "Loaded $label"
echo "To wake a sleeping mac for the first run:"
echo "  sudo pmset repeat wakeorpoweron MTWRFSU 04:59:00"
echo "To let the script schedule wakes for the later runs:"
echo "  echo '$USER ALL=(root) NOPASSWD: /usr/bin/pmset schedule wake *' | sudo tee /etc/sudoers.d/ai-warmup"
