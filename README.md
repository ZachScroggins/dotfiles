# dotfiles

Zach's Mac and terminal setup: config files (managed by [chezmoi](https://www.chezmoi.io)), the software list (Brewfiles) and two setup scripts.

## Set up a machine

| Machine | Command | What you get |
|---|---|---|
| New Mac | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/ZachScroggins/dotfiles/main/install-mac.sh)"` | Everything: CLI tools, dev toolchains, GUI apps, fonts, VS Code extensions, dotfiles, macOS settings |
| Any Unix terminal (Linux, Pi, server, BSD) | `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZachScroggins/dotfiles/main/install-cli.sh)"` | zsh as login shell, the CLI tools in `Brewfile.core`, terminal dotfiles |

Both clone this repo to `~/dotfiles` (or use the checkout they're run from) and are safe to re-run. Files they replace are copied to `~/.dotfiles-backup/<time>/` first. The one-liners need the repo to be public; for a private repo, clone it first and run the script from the clone.

`install-cli.sh` options: `--dev` (also `Brewfile.dev`; Homebrew only), `--no-brew` (force native packages), `--no-shell` (keep the login shell), `--dir DIR`, `--repo URL`.
`install-mac.sh` options: `--no-defaults` (skip `macos/defaults.sh`).

## How install-cli.sh picks a package source

1. **Homebrew**, when it can run: macOS, or Linux with glibc on x86_64/aarch64 as a non-root user with sudo. Installs `packages/Brewfile.core`.
2. **Native package manager** otherwise (Alpine/musl, root-only servers, 32-bit ARM, FreeBSD, `--no-brew`): apt, dnf, pacman, apk, zypper, xbps or pkg, with the names in `packages/native.txt`.
3. **curl installers / GitHub release binaries** into `~/.local/bin` for tools the distro lacks: chezmoi, starship, zoxide, fnm, uv, lazygit, eza, tealdeer, superfile, ast-grep, fastfetch, and Neovim when the distro's is older than 0.11 (LazyVim needs 0.11+).

zsh, git and curl always come from the native package manager. Tools that can't be installed are listed at the end.

## Layout

```
install-mac.sh        full Mac: Homebrew → install-cli.sh --dev → Node/Rust → Brewfile.mac → macos/defaults.sh
install-cli.sh        any Unix: zsh + CLI tools + dotfiles + login shell (POSIX sh)
packages/
  Brewfile.core       CLI tools for every machine
  Brewfile.dev        heavier toolchains (Mac; Linux with --dev)
  Brewfile.mac        casks, fonts, VS Code extensions, cargo/uv/npm packages
  native.txt          Brewfile.core → apt/dnf/pacman/apk/zypper/xbps/pkg names
home/                 chezmoi source (.chezmoiroot points here)
  .chezmoiignore      macOS-only files skipped on other systems
  dot_zshrc.tmpl …    templates: identical output on macOS, guarded versions on Linux
macos/defaults.sh     Dock/Finder/keyboard/trackpad settings
scripts/test-linux.sh run install-cli.sh in Docker (debian ubuntu fedora alpine arch brew)
```

## Everyday use

- Edit a managed file: `chezmoi edit ~/.zshrc` (edits the source), then `chezmoi apply`. If you edited the live file directly: `chezmoi re-add ~/.zshrc`.
- Track a new file: `chezmoi add ~/.config/foo/config.toml`.
- See what would change: `chezmoi diff`.
- Add a CLI tool everywhere: add it to `packages/Brewfile.core` and a row to `packages/native.txt`.
- Mac-only app: add it to `packages/Brewfile.mac`.

## Tested (2026-11-25)

`scripts/test-linux.sh` passes on Debian 13, Ubuntu 24.04, Fedora 45, Alpine and Arch (as root, native path) and on Debian 13 as a sudo user (Homebrew path, all 30 formulae). Known gaps on the native path: `tokei` on Ubuntu 24.04 and `unar` on Alpine (no package and no prebuilt binary). `install-mac.sh` still needs a run in a macOS VM (UTM).

Project notes and board live in the Obsidian vault at `01 PROJECTS/Dotfiles/`.
