#!/bin/sh
# run inside container after install: report tools, shell and rendered zshrc health
u=$(id -un)
echo "LOGIN SHELL: $(awk -F: -v u="$u" '$1==u{print $7}' /etc/passwd)"
zsh -l -i -c '
for c in zsh git chezmoi rg fd fzf eza nvim vim tmux btop htop lazygit gh starship zoxide fnm uv tldr tokei tree wget unar fastfetch spf ast-grep yt-dlp; do
  if (( $+commands[$c] )); then printf "ok   %-10s %s\n" $c ${commands[$c]}; else printf "MISS %s\n" $c; fi
done
if (( $+commands[7z] || $+commands[7zz] )); then echo "ok   7-zip"; else echo "MISS 7-zip"; fi
nvim --version | head -1
echo "autosuggest loaded: ${+functions[_zsh_autosuggest_start]}  syntax-hl: ${+ZSH_HIGHLIGHT_VERSION}"
echo "prompt: ${PROMPT[1,40]}"
' 2>&1
for f in ~/.zshrc ~/.zshenv ~/.config/starship.toml ~/.config/nvim/init.lua ~/.tmux.conf ~/.gitconfig; do
  if [ -f "$f" ]; then echo "ok   file $f"; else echo "MISS file $f"; fi
done
