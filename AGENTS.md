# Agent notes for this repo

Project notes and board live in the Obsidian vault at `/Users/zach/Library/Mobile Documents/iCloud~md~obsidian/Documents/My Vault/01 PROJECTS/Dotfiles/`; read its `INDEX.md` first. Before writing anything in the vault, read `<vault>/AGENTS.md` and follow it. If you change any vault file (including the board), add a Log entry in `<vault>/05 LOG/`.

## Rules

- Never run `chezmoi apply`, `install-cli.sh` or `install-mac.sh` against Zach's real home on his Mac unless he asks. Test with `chezmoi diff`, `chezmoi apply --destination /tmp/...`, `scripts/test-linux.sh` (Docker) or a UTM VM.
- On macOS, templates in `home/` must render byte-identical to Zach's live files. Check with `chezmoi diff` (with a temp `--config`/`--persistent-state` if chezmoi isn't initialized here).
- `install-cli.sh` is POSIX sh (dash, busybox ash, macOS sh) and must not need `rg`, bash or GNU tools; lint with `shellcheck -s sh`. `install-mac.sh` targets bash 3.2.
- `~/Brewfile` (from `brewbackup`) is Zach's machine-wide dump; don't edit it. The split files in `packages/` must together cover every entry in it.
- Commit on a feature branch; Zach reviews and merges.
