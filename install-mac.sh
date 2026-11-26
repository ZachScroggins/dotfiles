#!/bin/bash
# install-mac.sh: full setup of a fresh Mac to match Zach's MacBook Pro.
#
#   bash install-mac.sh [--no-defaults]
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/ZachScroggins/dotfiles/main/install-mac.sh)"
#
#   1. Homebrew + Xcode Command Line Tools, clone this repo to ~/dotfiles
#   2. install-cli.sh --dev: Brewfile.core + Brewfile.dev, dotfiles (chezmoi), zsh
#   3. Node LTS (fnm) and Rust (rustup), needed by the npm/cargo lines below
#   4. Brewfile.mac: casks, fonts, VS Code extensions, cargo/uv/npm packages
#   5. macos/defaults.sh: Dock, Finder, keyboard, trackpad settings
# Safe to re-run. Written for macOS's bash 3.2.
set -euo pipefail

REPO_URL=${DOTFILES_REPO:-https://github.com/ZachScroggins/dotfiles.git}
DOTFILES_DIR=${DOTFILES_DIR:-$HOME/dotfiles}
DOTFILES_BRANCH=${DOTFILES_BRANCH:-}   # clone a branch other than the default (testing)
APPLY_DEFAULTS=1
for arg in "$@"; do
  case $arg in
    --no-defaults) APPLY_DEFAULTS=0 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }

[ "$(uname -s)" = Darwin ] || { echo "install-mac.sh is for macOS; use install-cli.sh" >&2; exit 1; }

# 1. Homebrew (its installer also installs the Command Line Tools, which bring git)
sudo -v
# keep the sudo timestamp fresh: cask installers ask for it mid-run
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
if ! [ -x /opt/homebrew/bin/brew ]; then
  info "Installing Homebrew"
  NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv bash)"

script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "$script_dir" ] && [ -f "$script_dir/.chezmoiroot" ]; then
  DOTFILES_DIR=$script_dir
elif ! [ -d "$DOTFILES_DIR/.git" ]; then
  info "Cloning $REPO_URL to $DOTFILES_DIR"
  git clone ${DOTFILES_BRANCH:+--branch "$DOTFILES_BRANCH"} "$REPO_URL" "$DOTFILES_DIR"
fi

# 2. Terminal layer, shared with Linux
sh "$DOTFILES_DIR/install-cli.sh" --dev --dir "$DOTFILES_DIR"
eval "$(brew shellenv bash)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# 3. Node and Rust for the npm/cargo entries in Brewfile.mac
if command -v fnm >/dev/null; then
  eval "$(fnm env --shell bash)"
  fnm ls 2>/dev/null | rg -q 'default' || { info "Installing Node LTS with fnm"; fnm install --lts && fnm default lts-latest; }
  eval "$(fnm env --shell bash)"
fi
if ! command -v cargo >/dev/null; then
  info "Installing Rust with rustup"
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# 4. GUI apps, fonts, VS Code extensions, language packages
info "brew bundle: Brewfile.mac"
HOMEBREW_NO_ENV_HINTS=1 brew bundle --file="$DOTFILES_DIR/packages/Brewfile.mac" || warn "some Brewfile.mac entries failed (see above)"

# 5. macOS settings
if [ "$APPLY_DEFAULTS" -eq 1 ]; then
  bash "$DOTFILES_DIR/macos/defaults.sh"
fi

echo
info "Done. By hand:"
cat <<'EOF'
  - Sign in: App Store (Xcode isn't in the Brewfiles), iCloud, 1Password/browsers
  - gh auth login; add an SSH key to GitHub
  - Open Tailscale, Proton VPN, Docker Desktop, Raycast once to grant permissions
  - Log out and back in so the Dock/keyboard settings fully apply
EOF
