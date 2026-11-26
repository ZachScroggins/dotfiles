#!/bin/bash
# scripts/test-mac-vm.sh: test install-mac.sh in a throwaway UTM macOS VM.
# Needs UTM, a macOS 27+ host, and an IPSW (UTM's AppleScript provisioning only works for macOS 27+ guests).
#
#   scripts/test-mac-vm.sh create IPSW   # make VM "dotfiles-test", install macOS, set up user + SSH, snapshot "clean"
#   scripts/test-mac-vm.sh setup         # redo the SSH key / sudo / snapshot step on a running VM
#   scripts/test-mac-vm.sh run [BRANCH]  # restore "clean", boot, run install-mac.sh from BRANCH (default: current branch)
#   scripts/test-mac-vm.sh ssh [CMD]     # shell (or command) in the running VM
#   scripts/test-mac-vm.sh log           # follow ~/install.log in the VM
#   scripts/test-mac-vm.sh stop
#
# Guest account: zach / dotfiles (test only), passwordless sudo, SSH key ~/.ssh/dotfiles-test-vm
# (a dedicated key, created on first use).
set -euo pipefail

VM=dotfiles-test
GUEST_USER=zach
GUEST_PASS=dotfiles
KEY="$HOME/.ssh/dotfiles-test-vm"
repo=$(cd "$(dirname "$0")/.." && pwd)

utm() { osascript -e "tell application \"UTM\"" -e "$1" -e "end tell"; }
vm_status() { utm "get status of virtual machine named \"$VM\"" 2>/dev/null || echo missing; }

wait_status() {   # wait_status started|stopped
  for _ in $(seq 1 120); do [ "$(vm_status)" = "$1" ] && return 0; sleep 5; done
  echo "timeout waiting for VM to be $1" >&2; return 1
}

# The VM's MAC address (from UTM) → its NAT IP via macOS's DHCP lease file.
vm_ip() {
  local mac
  mac=$(osascript -e 'tell application "UTM"' -e "set c to configuration of virtual machine named \"$VM\"" \
    -e 'return address of item 1 of (network interfaces of c)' -e 'end tell' 2>/dev/null) || return 1
  mac=$(printf '%s' "$mac" | tr 'A-F' 'a-f' | sed -E 's/(^|:)0([0-9a-f])/\1\2/g')   # leases drop leading zeros
  awk -v m="1,$mac" '/ip_address=/ {split($0, a, "="); ip = a[2]} /hw_address=/ {split($0, b, "="); if (b[2] == m) print ip}' /var/db/dhcpd_leases | head -n 1
}

VM_IP=
wait_ssh() {
  [ -z "$VM_IP" ] || { echo "$VM_IP"; return 0; }
  local ip
  for _ in $(seq 1 120); do
    ip=$(vm_ip || true)
    if [ -n "$ip" ] && nc -z -G 2 "$ip" 22 2>/dev/null; then echo "$ip"; return 0; fi
    sleep 5
  done
  echo "timeout waiting for SSH" >&2; return 1
}

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i "$KEY")
# shellcheck disable=SC2029  # the command is meant to be built on this side
vssh() { [ -n "$VM_IP" ] || VM_IP=$(wait_ssh); ssh "${SSH_OPTS[@]}" "$GUEST_USER@$VM_IP" "$@"; }

create() {
  local ipsw=$1
  [ -f "$ipsw" ] || { echo "IPSW not found: $ipsw" >&2; exit 1; }
  [ "$(vm_status)" = missing ] || { echo "VM $VM already exists" >&2; exit 1; }
  [ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N '' -C dotfiles-test-vm -f "$KEY"

  echo "==> Creating $VM (8 GB RAM, 4 cores, 160 GB disk)"
  utm "make new virtual machine with properties {backend:apple, configuration:{name:\"$VM\", os:macOS, macRecoveryIpsw:(POSIX file \"$ipsw\"), memory:8192, cpu cores:4, drives:{{guest size:163840}}}}" >/dev/null
  echo "==> Installing macOS (about 10 min)"
  utm "install virtual machine named \"$VM\""
  while true; do
    p=$(utm "set r to query install virtual machine named \"$VM\"
             return (installing of r as text) & \" \" & (progress of r as text)")
    printf '\r    %s' "$p"; case $p in false*) break ;; esac; sleep 10
  done; echo
  echo "==> First boot with provisioning (user $GUEST_USER, auto-login, SSH)"
  utm "start virtual machine named \"$VM\" provisioning {full name:\"Zach Scroggins\", username:\"$GUEST_USER\", password:\"$GUEST_PASS\", automatic login:true, remote login:true}"
  wait_status started
  setup
}

# Key + passwordless sudo + "clean" snapshot. Separate so it can be re-run after a failure.
setup() {
  local ip; ip=$(wait_ssh); echo "    VM at $ip"

  echo "==> Installing SSH key and passwordless sudo"
  local askpass; askpass=$(mktemp); printf '#!/bin/sh\necho %s\n' "$GUEST_PASS" > "$askpass"; chmod 700 "$askpass"
  SSH_ASKPASS=$askpass SSH_ASKPASS_REQUIRE=force DISPLAY=:0 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o PubkeyAuthentication=no "$GUEST_USER@$ip" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat "$KEY.pub")' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys &&
     echo '$GUEST_PASS' | sudo -S sh -c 'echo \"$GUEST_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$GUEST_USER && chmod 440 /etc/sudoers.d/$GUEST_USER'"
  rm -f "$askpass"
  vssh 'sw_vers; sudo -n true && echo "passwordless sudo ok"'

  echo "==> Snapshot \"clean\""
  vssh 'sudo shutdown -h now' || true
  wait_status stopped
  utm "set v to virtual machine named \"$VM\"
       create snapshot v named \"clean\""
  echo "==> Done. Run: scripts/test-mac-vm.sh run"
}

run() {
  local branch=${1:-$(git -C "$repo" branch --show-current)}
  [ "$(vm_status)" = stopped ] || { utm "stop virtual machine named \"$VM\" by force" || true; wait_status stopped; }
  echo "==> Restoring snapshot \"clean\""
  utm "set v to virtual machine named \"$VM\"
       restore (first snapshot of v whose name is \"clean\")"
  utm "start virtual machine named \"$VM\""
  wait_status started
  echo "==> Running install-mac.sh from branch $branch (log: ~/install.log in the VM)"
  vssh "nohup bash -c 'export DOTFILES_BRANCH=$branch; bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/ZachScroggins/dotfiles/$branch/install-mac.sh)\"; echo EXIT=\$?' > ~/install.log 2>&1 &"
  echo "==> Started. Follow with: scripts/test-mac-vm.sh log"
}

case ${1:-} in
  create) create "${2:?IPSW path}" ;;
  setup) setup ;;
  run) run "${2:-}" ;;
  ssh) shift; vssh "$@" ;;
  log) vssh 'tail -n 50 -f ~/install.log' ;;
  stop) utm "stop virtual machine named \"$VM\"" ;;
  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
