#!/bin/sh
# install-cli.sh: terminal setup for any Unix-like OS (macOS, Debian/Ubuntu,
# Fedora, Arch, Alpine, openSUSE, Void, FreeBSD). Installs zsh and makes it the
# login shell, installs the CLI tools in packages/Brewfile.core and applies the
# dotfiles in home/ with chezmoi.
#
#   sh install-cli.sh [--dev] [--no-brew] [--no-shell] [--repo URL] [--dir DIR]
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZachScroggins/dotfiles/main/install-cli.sh)"
#
# Package source, in order of preference:
#   1. Homebrew: macOS, and Linux with glibc on x86_64/aarch64 as a non-root user
#   2. the native package manager, using the names in packages/native.txt
#   3. official curl installers / GitHub release binaries into ~/.local/bin
# Existing files that chezmoi replaces are copied to ~/.dotfiles-backup/<time>/.
# Safe to re-run.
set -eu

REPO_URL=${DOTFILES_REPO:-https://github.com/ZachScroggins/dotfiles.git}
DOTFILES_DIR=${DOTFILES_DIR:-$HOME/dotfiles}
WITH_DEV=0
BREW_MODE=auto
SET_SHELL=1

usage() { sed -n '2,17p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case $1 in
    --dev) WITH_DEV=1 ;;
    --no-brew) BREW_MODE=no ;;
    --no-shell) SET_SHELL=0 ;;
    --repo) REPO_URL=$2; shift ;;
    --dir) DOTFILES_DIR=$2; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------- helpers ----
if [ -t 1 ]; then B=$(printf '\033[1;34m'); Y=$(printf '\033[1;33m'); RD=$(printf '\033[1;31m'); N=$(printf '\033[0m'); else B='' Y='' RD='' N=''; fi
info() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
warn() { printf '%s!! %s%s\n' "$Y" "$*" "$N" >&2; }
die()  { printf '%sxx %s%s\n' "$RD" "$*" "$N" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

SKIPPED=""
skip() { SKIPPED="$SKIPPED $1"; }

OS=$(uname -s)
ARCH=$(uname -m)
USER_NAME=$(id -un)
mkdir -p "$HOME/.local/bin"
PATH="$HOME/.local/bin:$PATH"; export PATH

if [ "$(id -u)" -eq 0 ]; then SUDO=
elif have sudo; then SUDO=sudo
elif have doas; then SUDO=doas
else SUDO=; warn "no sudo or doas: system packages and chsh may fail"
fi
as_root() { if [ -n "$SUDO" ]; then $SUDO "$@"; else "$@"; fi; }

# ------------------------------------------------------- package managers ----
PM=none
case $OS in
  Darwin) PM=brew ;;
  *) for c in apt-get:apt dnf:dnf pacman:pacman zypper:zypper apk:apk xbps-install:xbps pkg:pkg; do
       if have "${c%%:*}"; then PM=${c#*:}; break; fi
     done ;;
esac

pm_refresh() {
  case $PM in
    apt) as_root apt-get update -q ;;
    pacman) as_root pacman -Syu --noconfirm ;;   # full upgrade: Arch forbids partial upgrades
    apk) as_root apk update -q ;;
    zypper) as_root zypper -q refresh ;;
    xbps) as_root xbps-install -Syu xbps && as_root xbps-install -yu ;;
    pkg) as_root env ASSUME_ALWAYS_YES=yes pkg update -q ;;
    *) : ;;
  esac
}

pm_install() {
  case $PM in
    apt) as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "$@" ;;
    dnf) as_root dnf install -y -q "$@" ;;
    pacman) as_root pacman -S --needed --noconfirm "$@" ;;
    apk) as_root apk add -q "$@" ;;
    zypper) as_root zypper -q -n install "$@" ;;
    xbps) as_root xbps-install -y "$@" ;;
    pkg) as_root env ASSUME_ALWAYS_YES=yes pkg install -y "$@" ;;
    *) return 1 ;;
  esac
}

pm_has() {
  case $PM in
    apt) [ -n "$(apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: *//p' | sed '/(none)/d')" ] ;;
    dnf) dnf -q info "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
    apk) [ -n "$(apk search -qx "$1" 2>/dev/null)" ] ;;
    zypper) zypper -q -n search -x "$1" >/dev/null 2>&1 ;;
    xbps) xbps-query -R "$1" >/dev/null 2>&1 ;;
    pkg) [ -n "$(pkg rquery %n "$1" 2>/dev/null)" ] ;;
    *) return 1 ;;
  esac
}

# Install the packages that exist in this distro's repos; warn about the rest.
install_available() {
  ok=
  for p in "$@"; do
    if pm_has "$p"; then ok="$ok $p"; else warn "not in $PM repos: $p"; fi
  done
  [ -n "$ok" ] || return 0
  # shellcheck disable=SC2086  # word splitting is intended
  pm_install $ok || for p in $ok; do pm_install "$p" || warn "failed to install $p"; done
}

# --------------------------------------------------------------- homebrew ----
load_brew() {
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$b" ]; then eval "$("$b" shellenv bash)"; return 0; fi
  done
  return 1
}

use_brew() {
  [ "$BREW_MODE" = no ] && return 1
  [ "$OS" = Darwin ] && return 0
  load_brew && return 0
  [ "$OS" = Linux ] || { info "Homebrew doesn't run on $OS; using $PM"; return 1; }
  [ "$(id -u)" -ne 0 ] || { info "running as root (Homebrew refuses root); using $PM"; return 1; }
  case $ARCH in x86_64|aarch64|arm64) ;; *) info "no Homebrew bottles for $ARCH; using $PM"; return 1 ;; esac
  getconf GNU_LIBC_VERSION >/dev/null 2>&1 || { info "no glibc (musl?); Homebrew needs glibc, using $PM"; return 1; }
  [ -n "$SUDO" ] || [ -w /home/linuxbrew ] || { info "no sudo to create /home/linuxbrew; using $PM"; return 1; }
  return 0
}

install_brew() {
  load_brew && return 0
  info "Installing Homebrew"
  [ -z "$SUDO" ] || $SUDO -v   # cache credentials; the installer runs sudo non-interactively
  NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew || die "Homebrew installed but brew not found"
}

brew_bundle() {
  info "brew bundle: $(basename "$1")"
  HOMEBREW_NO_ENV_HINTS=1 brew bundle --file="$1" || warn "some entries in $(basename "$1") failed (see above)"
}

# ------------------------------------------------------- curl fallbacks -----
latest_tag() {   # latest_tag owner/repo -> v1.2.3
  u=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") || return 1
  printf '%s\n' "${u##*/}"
}

is_glibc() { getconf GNU_LIBC_VERSION >/dev/null 2>&1; }

tarball_to_bin() {   # tarball_to_bin URL BINARY_NAME
  t=$(mktemp -d)
  curl -fsSL "$1" | tar -xz -C "$t" || { rm -rf "$t"; return 1; }
  f=$(find "$t" -type f -name "$2" | head -n 1)
  [ -n "$f" ] || { rm -rf "$t"; return 1; }
  install -m 755 "$f" "$HOME/.local/bin/$2"
  rm -rf "$t"
}

fallback() {   # official installers / release binaries into ~/.local/bin
  [ "$OS" = Linux ] || [ "$1" = starship ] || [ "$1" = chezmoi ] || return 1
  info "curl install: $1"
  case $1 in
    chezmoi) sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" ;;
    starship) curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" ;;
    zoxide) curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh ;;
    uv) curl -fsSL https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh ;;
    fnm)
      have bash && have unzip || return 1
      curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/share/fnm" --skip-shell &&
        ln -sf "$HOME/.local/share/fnm/fnm" "$HOME/.local/bin/fnm" ;;
    lazygit)
      case $ARCH in x86_64) a=x86_64 ;; aarch64|arm64) a=arm64 ;; armv6*|armv7*) a=armv6 ;; *) return 1 ;; esac
      v=$(latest_tag jesseduffield/lazygit) || return 1
      tarball_to_bin "https://github.com/jesseduffield/lazygit/releases/download/$v/lazygit_${v#v}_Linux_$a.tar.gz" lazygit ;;
    eza)
      if is_glibc; then
        case $ARCH in x86_64) a=x86_64-unknown-linux-gnu ;; aarch64|arm64) a=aarch64-unknown-linux-gnu ;; armv7*) a=arm-unknown-linux-gnueabihf ;; *) return 1 ;; esac
      else
        case $ARCH in x86_64) a=x86_64-unknown-linux-musl ;; *) return 1 ;; esac
      fi
      tarball_to_bin "https://github.com/eza-community/eza/releases/latest/download/eza_$a.tar.gz" eza ;;
    tealdeer)   # static musl binaries
      case $ARCH in x86_64) a=x86_64-musl ;; aarch64|arm64) a=aarch64-musl ;; armv7*) a=armv7-musleabihf ;; armv6*) a=arm-musleabihf ;; *) return 1 ;; esac
      curl -fsSL -o "$HOME/.local/bin/tldr" "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-$a" &&
        chmod 755 "$HOME/.local/bin/tldr" ;;
    superfile)
      case $ARCH in x86_64) a=amd64 ;; aarch64|arm64) a=arm64 ;; *) return 1 ;; esac
      v=$(latest_tag yorukot/superfile) || return 1
      tarball_to_bin "https://github.com/yorukot/superfile/releases/download/$v/superfile-linux-$v-$a.tar.gz" spf ;;
    ast-grep)
      have unzip || return 1
      if is_glibc; then l=gnu; else l=musl; fi
      case $ARCH in x86_64) a=x86_64 ;; aarch64|arm64) a=aarch64 ;; *) return 1 ;; esac
      t=$(mktemp -d)
      curl -fsSL -o "$t/a.zip" "https://github.com/ast-grep/ast-grep/releases/latest/download/app-$a-unknown-linux-$l.zip" &&
        unzip -q -o "$t/a.zip" -d "$t" && install -m 755 "$t/ast-grep" "$HOME/.local/bin/ast-grep"
      r=$?; rm -rf "$t"; return $r ;;
    fastfetch)   # glibc builds
      is_glibc || return 1
      case $ARCH in x86_64) a=amd64 ;; aarch64|arm64) a=aarch64 ;; armv7*) a=armv7l ;; *) return 1 ;; esac
      tarball_to_bin "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$a.tar.gz" fastfetch ;;
    neovim)   # official builds are glibc-only
      is_glibc || return 1
      case $ARCH in x86_64) a=x86_64 ;; aarch64|arm64) a=arm64 ;; *) return 1 ;; esac
      d="$HOME/.local/opt"; mkdir -p "$d"; rm -rf "$d/nvim-linux-$a"
      curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$a.tar.gz" | tar -xz -C "$d" &&
        ln -sf "$d/nvim-linux-$a/bin/nvim" "$HOME/.local/bin/nvim" ;;
    *) return 1 ;;
  esac
}

# LazyVim needs Neovim >= 0.11; older distros (e.g. Debian 13) ship 0.10.
nvim_too_old() {
  have nvim || return 1
  v=$(nvim --version 2>/dev/null | sed -n '1s/^NVIM v\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
  # shellcheck disable=SC2086  # split "0 10" into major/minor
  set -- $v
  [ "${1:-0}" -eq 0 ] && [ "${2:-0}" -lt 11 ]
}

install_native_tools() {
  list="$DOTFILES_DIR/packages/native.txt"
  pkgs= ; want=
  while read -r name cmd apt dnf pacman apk zypper xbps pkg _; do
    case $name in ''|'#'*) continue ;; esac
    case $PM in apt) p=$apt ;; dnf) p=$dnf ;; pacman) p=$pacman ;; apk) p=$apk ;; zypper) p=$zypper ;; xbps) p=$xbps ;; pkg) p=$pkg ;; *) p=- ;; esac
    [ "$p" = - ] || pkgs="$pkgs $p"
    want="$want $name:$cmd"
  done < "$list"
  info "Installing CLI tools with $PM"
  # shellcheck disable=SC2086
  install_available $pkgs

  # Debian/Ubuntu name fd `fdfind`
  if ! have fd && have fdfind; then ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
  if nvim_too_old; then info "distro Neovim is older than 0.11 (LazyVim needs 0.11+)"; fallback neovim || warn "couldn't install a newer Neovim"; fi

  for pair in $want; do
    name=${pair%%:*}; cmd=${pair#*:}
    [ "$cmd" = - ] && continue
    have "$cmd" && continue
    fallback "$name" || skip "$name"
  done
}

# -------------------------------------------------------------- dotfiles ----
fetch_repo() {
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || script_dir=
  if [ -n "$script_dir" ] && [ -f "$script_dir/.chezmoiroot" ]; then
    DOTFILES_DIR=$script_dir
  elif [ -d "$DOTFILES_DIR/.git" ]; then
    info "Updating $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only || warn "git pull failed; using the current checkout"
  else
    info "Cloning $REPO_URL to $DOTFILES_DIR"
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
}

apply_dotfiles() {
  have chezmoi || die "chezmoi is missing; can't apply dotfiles"
  info "Applying dotfiles from $DOTFILES_DIR"
  chezmoi init --source "$DOTFILES_DIR"
  BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
  chezmoi managed --include=files | while IFS= read -r f; do
    t="$HOME/$f"
    if [ -f "$t" ] && [ ! -L "$t" ] && ! chezmoi cat "$t" 2>/dev/null | cmp -s - "$t"; then
      mkdir -p "$BACKUP/$(dirname "$f")" && cp -p "$t" "$BACKUP/$f"
    fi
  done
  chezmoi apply --force
  [ -d "$BACKUP" ] && info "Replaced files backed up to $BACKUP" || true
}

set_login_shell() {
  # prefer a zsh path already listed in /etc/shells (Fedora's PATH finds /usr/sbin/zsh first)
  zsh_path=$(awk '/\/zsh$/ { print; exit }' /etc/shells 2>/dev/null)
  [ -n "$zsh_path" ] && [ -x "$zsh_path" ] || zsh_path=$(command -v zsh) ||
    { warn "zsh not found; login shell unchanged"; return 0; }
  case $OS in
    Darwin) cur=$(dscl . -read "/Users/$USER_NAME" UserShell 2>/dev/null | awk '{print $2}') ;;
    *) cur=$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f7)
       [ -n "$cur" ] || cur=$(awk -F: -v u="$USER_NAME" '$1 == u { print $7 }' /etc/passwd) ;;
  esac
  case $cur in */zsh) info "Login shell is already zsh ($cur)"; return 0 ;; esac
  info "Setting login shell to $zsh_path (was ${cur:-unknown})"
  if ! awk -v s="$zsh_path" '$0 == s { f = 1 } END { exit !f }' /etc/shells 2>/dev/null; then
    printf '%s\n' "$zsh_path" | as_root tee -a /etc/shells >/dev/null || true
  fi
  if [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; then
    as_root chsh -s "$zsh_path" "$USER_NAME" 2>/dev/null ||
      as_root usermod -s "$zsh_path" "$USER_NAME" 2>/dev/null ||
      warn "couldn't change the login shell; run: chsh -s $zsh_path"
  else
    chsh -s "$zsh_path" || warn "couldn't change the login shell; run: chsh -s $zsh_path"
  fi
}

# ------------------------------------------------------------------ main ----
info "$OS $ARCH, user $USER_NAME, package manager: $PM"
[ "$PM" != none ] || die "no supported package manager found"
[ -z "$SUDO" ] || [ "$SUDO" != sudo ] || sudo -v || die "sudo failed"

if [ "$OS" = Darwin ]; then
  install_brew   # also installs the Xcode Command Line Tools (git)
else
  info "Installing base packages (zsh, git, curl, ...)"
  pm_refresh
  case $PM in
    apt) base="zsh git curl ca-certificates file procps unzip bash tar gzip xz-utils" ;;
    dnf) base="zsh git curl ca-certificates file procps-ng unzip bash tar gzip xz shadow-utils" ;;
    pacman) base="zsh git curl ca-certificates file procps-ng unzip bash tar gzip xz" ;;
    apk) base="zsh git curl ca-certificates file procps unzip bash tar xz shadow" ;;
    zypper) base="zsh git curl ca-certificates file procps unzip bash tar gzip xz shadow" ;;
    xbps) base="zsh git curl ca-certificates file procps-ng unzip bash tar xz" ;;
    pkg) base="zsh git curl ca_root_nss unzip bash" ;;
  esac
  # shellcheck disable=SC2086
  install_available $base
fi

fetch_repo

if use_brew; then
  if [ "$OS" != Darwin ]; then
    info "Installing build tools for Homebrew"
    case $PM in
      apt) install_available build-essential ;;
      dnf) install_available gcc gcc-c++ make ;;
      pacman) install_available base-devel ;;
      zypper) install_available gcc gcc-c++ make ;;
    esac
  fi
  install_brew
  brew_bundle "$DOTFILES_DIR/packages/Brewfile.core"
  [ "$WITH_DEV" -eq 0 ] || brew_bundle "$DOTFILES_DIR/packages/Brewfile.dev"
  # compinit refuses group-writable completion dirs ("insecure directories")
  chmod -R go-w "$(brew --prefix)/share/zsh" 2>/dev/null || true
else
  install_native_tools
  [ "$WITH_DEV" -eq 0 ] || warn "--dev needs Homebrew; Brewfile.dev skipped"
fi

have chezmoi || fallback chezmoi || die "couldn't install chezmoi"
apply_dotfiles
[ "$SET_SHELL" -eq 0 ] || set_login_shell

echo
info "Done."
[ -z "$SKIPPED" ] || warn "Not installed (no package or installer for $PM/$ARCH):$SKIPPED"
info "Start a new login shell to use it: exec zsh -l"
