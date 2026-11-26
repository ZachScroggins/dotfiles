#!/bin/bash
# scripts/test-linux.sh: run install-cli.sh in throwaway Docker containers.
#   scripts/test-linux.sh                 # all distros, as root (native package path)
#   scripts/test-linux.sh debian alpine   # some of them
#   scripts/test-linux.sh brew            # Debian as a sudo user (Homebrew path, ~10 min)
# Logs: /tmp/dotfiles-test/<name>.log. Needs Docker Desktop running.
set -uo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
logs=/tmp/dotfiles-test; mkdir -p "$logs"
declare_image() {
  case $1 in
    debian) echo "debian:trixie" ;; ubuntu) echo "ubuntu:24.04" ;; fedora) echo "fedora:latest" ;;
    alpine) echo "alpine:latest" ;; arch) echo "archlinux:latest" ;; brew) echo "debian:trixie" ;;
    *) return 1 ;;
  esac
}
run() {
  local name=$1 img; img=$(declare_image "$name") || { echo "unknown: $name"; return 1; }
  local args=(--rm -v "$repo:/dotfiles:ro") cmd='sh /dotfiles/install-cli.sh && sh /dotfiles/scripts/verify.sh'
  case $name in
    # no arm64 Arch image; under emulation pacman's sandbox fails, so disable it (test only)
    arch) args+=(--platform linux/amd64 --security-opt seccomp=unconfined)
          cmd="sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf && $cmd" ;;
    brew) cmd="apt-get update -q >/dev/null && apt-get install -y -q sudo >/dev/null &&
               useradd -m -s /bin/bash zach && echo 'zach ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/zach &&
               su - zach -c 'sh /dotfiles/install-cli.sh && sh /dotfiles/scripts/verify.sh'" ;;
  esac
  docker run "${args[@]}" "$img" sh -c "$cmd" > "$logs/$name.log" 2>&1
  local rc=$?
  printf '%-7s exit=%s  missing: %s\n' "$name" "$rc" "$(rg '^MISS' "$logs/$name.log" | awk '{printf "%s ", $2}')"
}
targets=("$@"); [ ${#targets[@]} -gt 0 ] || targets=(debian ubuntu fedora alpine arch)
for t in "${targets[@]}"; do run "$t" & done
wait
