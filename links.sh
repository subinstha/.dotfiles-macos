#!/bin/sh

# creates symlinks for dotfiles with files in this repo

# git
ln -s ~/.dotfiles-macos/git/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles-macos/git/.gitignore_global ~/.gitignore_global

# ssh
ln -s ~/.dotfiles-macos/ssh/config ~/.ssh/config

# zsh
ln -s ~/.dotfiles-macos/zsh/.zsh_aliases ~/.zsh_aliases
ln -s ~/.dotfiles-macos/zsh/.zsh_install ~/.zsh_install
ln -s ~/.dotfiles-macos/zsh/.zsh_precmd ~/.zsh_precmd
ln -s ~/.dotfiles-macos/zsh/starship.toml ~/.config/starship.toml
ln -s ~/.dotfiles-macos/zsh/.zshrc ~/.zshrc

# Tmux
ln -s ~/.dotfiles-macos/tmux/.tmux.conf ~/.tmux.conf


# sketchybar
ln -s ~/.dotfiles-macos/sketchybar ~/.config/sketchybar

# nvim
ln -s ~/.dotfiles-macos/nvim ~/.config/nvim

# kitty
mkdir -p ~/.config/kitty
ln -s ~/.dotfiles-macos/kitty/kitty.conf ~/.config/kitty/kitty.conf

# claude code
~/.dotfiles-macos/.claude/link-claude.sh

# gitconfig
git config --global core.excludesfile ~/.gitignore_global
