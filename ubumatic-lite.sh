#!/bin/bash
# Ubumatic Lite - a small, modern take on Ubumatic for current Ubuntu releases.
# Copyright (C) 2012-2026 Piotr Miros
# License: GPLv3 (see the header of ubumatic.sh)
#
# Differences from the original: runs as a normal user and lets sudo ask for the
# password itself (nothing is stored), does not replace sources.list, does not
# download or run anything from third-party servers, supports --dry-run.

set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
declare -a ACTIONS=()

usage() {
	cat <<'EOF'
Usage: ubumatic-lite.sh [options] [actions]

Options:
  -n, --dry-run   only print the commands
  -y, --yes       do not ask for confirmation, answer yes to every question
  -h, --help      show this help

Actions (without any action the script asks about each one):
  --upgrade       install the latest updates
  --codecs        audio/video codecs and DVD support (ubuntu-restricted-extras)
  --archivers     7-Zip and RAR support
  --fonts         Microsoft core fonts
  --repair        repair broken packages
  --clean         remove unused packages and the package cache
  --all           all of the above
EOF
}

die() {
	echo "ubumatic-lite: $*" >&2
	exit 1
}

run() {
	if ((DRY_RUN)); then
		printf '[dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

as_root() {
	if ((EUID == 0)); then
		run "$@"
	else
		run sudo "$@"
	fi
}

ask() {
	local answer
	((ASSUME_YES)) && return 0
	read -r -p "$1 [y/N] " answer
	[[ $answer == [Yy] || $answer == [Yy][Ee][Ss] ]]
}

check_system() {
	local id=
	if [[ -r /etc/os-release ]]; then
		# shellcheck disable=SC1091
		id=$(. /etc/os-release && echo "${ID:-}")
	fi
	[[ $id == ubuntu ]] || die "this script supports Ubuntu only (found: ${id:-unknown})"
	command -v apt-get >/dev/null 2>&1 || die "apt-get not found"
	if ((EUID != 0 && DRY_RUN == 0)); then
		command -v sudo >/dev/null 2>&1 || die "sudo not found, run the script as root"
	fi
}

action_upgrade() {
	as_root apt-get update
	as_root apt-get -y upgrade
	as_root apt-get -y dist-upgrade
}

action_codecs() {
	as_root apt-get update
	as_root apt-get -y install ubuntu-restricted-extras libdvd-pkg
}

action_archivers() {
	as_root apt-get -y install p7zip-full unrar
}

action_fonts() {
	as_root apt-get -y install ttf-mscorefonts-installer
}

action_repair() {
	as_root dpkg --configure -a
	as_root apt-get -f -y install
}

action_clean() {
	as_root apt-get -y autoremove --purge
	as_root apt-get clean
}

describe() {
	case $1 in
		upgrade) echo 'Install the latest updates' ;;
		codecs) echo 'Install audio/video codecs and DVD support' ;;
		archivers) echo 'Install 7-Zip and RAR support' ;;
		fonts) echo 'Install Microsoft core fonts' ;;
		repair) echo 'Repair broken packages' ;;
		clean) echo 'Remove unused packages and the package cache' ;;
	esac
}

parse_args() {
	while (($#)); do
		case $1 in
			-n | --dry-run) DRY_RUN=1 ;;
			-y | --yes) ASSUME_YES=1 ;;
			-h | --help)
				usage
				exit 0
				;;
			--upgrade | --codecs | --archivers | --fonts | --repair | --clean)
				ACTIONS+=("${1#--}")
				;;
			--all) ACTIONS+=(upgrade codecs archivers fonts repair clean) ;;
			*) die "unknown option: $1 (try --help)" ;;
		esac
		shift
	done
}

choose_actions_interactively() {
	local name
	for name in upgrade codecs archivers fonts repair clean; do
		if ask "$(describe "$name")?"; then
			ACTIONS+=("$name")
		fi
	done
}

main() {
	parse_args "$@"
	check_system
	if ((${#ACTIONS[@]} == 0)); then
		choose_actions_interactively
	fi
	local name
	for name in "${ACTIONS[@]}"; do
		echo "==> $(describe "$name")"
		"action_$name"
	done
	echo 'Done.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	main "$@"
fi
