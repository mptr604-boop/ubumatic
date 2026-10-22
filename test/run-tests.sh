#!/bin/bash
# Dry-run tests for ubumatic.sh. System commands (sudo, apt-get, zenity, xterm,
# wget, ...) are replaced by stubs that only log their arguments, so nothing on
# the machine is changed and no Ubuntu 10.04/12.04 is required.
# shellcheck disable=SC2016 # stub bodies are written as literal scripts
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT=$ROOT/ubumatic.sh
WORK=$(mktemp -d)
STUBS=$WORK/bin
LOG=$WORK/calls.log
ZENITY_ARGS=$WORK/zenity.args
mkdir -p "$STUBS"
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0

make_stub() {
	local name=$1 body=$2
	printf '#!/bin/bash\n%s\n' "$body" >"$STUBS/$name"
	chmod +x "$STUBS/$name"
}

log_stub() {
	make_stub "$1" "echo \"$1 \$*\" >> \"$LOG\"; ${2:-:}"
}

setup_stubs() {
	for name in apt-get apt-key add-apt-repository dpkg gconftool-2 gsettings gpg mount umount \
		grub-install grub-mkconfig mpd nano reboot x-www-browser fdisk; do
		log_stub "$name"
	done
	log_stub fuser 'exit 1'
	log_stub wget 'exit ${WGET_RC:-0}'
	make_stub clear ':'
	make_stub xrandr 'echo "   1920x1080     60.00*+"'
	make_stub uname 'echo x86_64'
	make_stub lsb_release 'case "$*" in *-cs*) echo "${STUB_CODENAME:-precise}";; *-is*) echo Ubuntu;; *-ds*) echo "Ubuntu 12.04.5 LTS";; esac'
	make_stub totem ':'
	make_stub xterm 'echo "xterm $*" >> "'"$LOG"'"; while [[ $# -gt 0 && $1 != -e ]]; do shift; done; shift; "$@"'
	make_stub sudo '
case "$1" in
	-K) exit 0;;
	-Sv)
		read -r pw
		if [[ -n ${STUB_SUDO_PASSWORD:-} && $pw != "$STUB_SUDO_PASSWORD" ]]; then echo "[sudo] password for x: Sorry" >&2; exit 1; fi
		exit 0;;
esac
read -r pw
echo "sudo[pw=$pw] $*" >> "'"$LOG"'"
[[ "$*" == *fuser* ]] && exit 1
exit 0'
	make_stub zenity '
printf "%s\n" "$@" >> "'"$ZENITY_ARGS"'"
echo "zenity $*" >> "'"$LOG"'"
case "$*" in
	*--list*) printf "%s\n" "${SELECTION:-}"; exit "${SELECTION_RC:-0}";;
	*--entry*) printf "%s\n" "${ENTRY:-secret}";;
	*--progress*) cat >/dev/null;;
esac
exit 0'
}

reset_logs() {
	: >"$LOG"
	: >"$ZENITY_ARGS"
}

assert_log() {
	local description=$1 pattern=$2
	if grep -qE -- "$pattern" "$LOG"; then
		passed=$((passed + 1))
		echo "ok   - $description"
	else
		failed=$((failed + 1))
		echo "FAIL - $description (pattern: $pattern)"
	fi
}

assert_no_log() {
	local description=$1 pattern=$2
	if grep -qE -- "$pattern" "$LOG"; then
		failed=$((failed + 1))
		echo "FAIL - $description (unexpected: $pattern)"
	else
		passed=$((passed + 1))
		echo "ok   - $description"
	fi
}

assert_output() {
	local description=$1 output=$2 pattern=$3
	if grep -qE -- "$pattern" <<<"$output"; then
		passed=$((passed + 1))
		echo "ok   - $description"
	else
		failed=$((failed + 1))
		echo "FAIL - $description (pattern: $pattern)"
	fi
}

run_script() {
	PATH="$STUBS:$PATH" bash "$SCRIPT" "$@" </dev/null
}

setup_stubs

# ---------------------------------------------------------------- GUI mode --
reset_logs
SELECTION='1:2:3:4:5:6:9' STUB_CODENAME=precise LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: 3:4:5:6 is collapsed into ubuntu-restricted-extras' 'apt-get -y --force-yes install ubuntu-restricted-extras'
assert_log 'GUI: Windows codecs matching architecture' 'install w64codecs'
assert_log 'GUI: icedtea plugin on precise' 'install icedtea-7-plugin'
assert_log 'GUI: Ubuntu Tweak PPA and package' 'add-apt-repository ppa:tualatrix/ppa'
assert_log 'GUI: ubuntu-tweak package' 'install ubuntu-tweak'
assert_log 'GUI: sources.list is written through sudo' 'CONTENT=deb http://archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse'
assert_log 'GUI: extras repository added on precise' 'deb http://extras.ubuntu.com/ubuntu precise main'
assert_log 'GUI: apt update, upgrade run in xterm' 'apt-get update'
assert_log 'GUI: broken packages are repaired afterwards' 'apt-get -fy --force-yes install'
assert_log 'GUI: password is piped to sudo' 'sudo\[pw=\] '

reset_logs
SELECTION='2' STUB_CODENAME=lucid LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: upgrade-only runs upgrade and dist-upgrade' 'apt-get -y --force-yes dist-upgrade'
assert_no_log 'GUI: upgrade-only does not touch sources.list' 'CONTENT='

reset_logs
SELECTION='1' STUB_CODENAME=lucid LANG=en_US.UTF-8 run_script >/dev/null
assert_no_log 'GUI: no extras repository on lucid' 'extras.ubuntu.com'

reset_logs
SELECTION='1:2:3' STUB_CODENAME=lucid LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: lucid codecs include libavcodec-extra-52' 'install libavcodec-extra-52'
assert_no_log 'GUI: lucid has no fluendo codec' 'fluendo'

reset_logs
SELECTION='' STUB_CODENAME=precise LANG=en_US.UTF-8 run_script >/dev/null
assert_no_log 'GUI: empty selection does nothing' 'apt-get'

reset_logs
SELECTION='' SELECTION_RC=1 STUB_CODENAME=precise LANG=en_US.UTF-8 run_script >/dev/null
assert_no_log 'GUI: cancel does nothing' 'apt-get'

reset_logs
SELECTION='1:2' WGET_RC=4 STUB_CODENAME=precise LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: no internet shows an error' '--error.*Internet connection failure'
assert_no_log 'GUI: no internet stops before changing the system' 'apt-get'

reset_logs
SELECTION='1' STUB_CODENAME=quantal LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: quantal uses quantal sources' 'quantal-updates'
assert_log 'GUI: quantal is treated as precise (extras)' 'extras.ubuntu.com/ubuntu quantal main'

reset_logs
SELECTION='1' STUB_CODENAME=trusty LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: unsupported release is rejected' "doesn't support this operating system"

reset_logs
SELECTION='1' STUB_SUDO_PASSWORD=right ENTRY=wrong STUB_CODENAME=precise LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: wrong password is reported' '--error.*Password incorrect'

reset_logs
SELECTION='2' STUB_SUDO_PASSWORD=right ENTRY=right STUB_CODENAME=precise LANG=en_US.UTF-8 run_script >/dev/null
assert_log 'GUI: password is passed on to sudo' 'sudo\[pw=right\] '

reset_logs
SELECTION='1' STUB_CODENAME=precise LANG=pl_PL.UTF-8 run_script >/dev/null
assert_log 'GUI: Polish window shows Polish options' 'Ustaw polskie napisy w odtwarzaczu Totem'
assert_log 'GUI: Polish architecture label' '64 bitowe'

reset_logs
SELECTION='7' STUB_CODENAME=precise LANG=pl_PL.UTF-8 run_script >/dev/null
assert_log 'GUI: Totem subtitles configured (precise)' 'gsettings set org.gnome.totem subtitle-encoding WINDOWS-1250'

reset_logs
SELECTION='7' STUB_CODENAME=lucid LANG=pl_PL.UTF-8 run_script >/dev/null
assert_log 'GUI: Totem subtitles configured (lucid)' 'gconftool-2 -t str -s /apps/totem/subtitle_encoding WINDOWS-1250'

# ----------------------------------------------------------------- CLI mode --
reset_logs
output=$(STUB_CODENAME=precise LANG=en_US.UTF-8 run_script --help)
assert_output 'CLI: --help lists options' "$output" '--kernelnew'
assert_output 'CLI: --help has the warning' "$output" 'WARNING'

output=$(STUB_CODENAME=precise LANG=pl_PL.UTF-8 run_script --help)
assert_output 'CLI: Polish --help lists mplayer' "$output" '--mplayer'

output=$(STUB_CODENAME=precise LANG=en_US.UTF-8 run_script --upgrade)
assert_output 'CLI: root-only option refuses a normal user' "$output" 'Run script as a root'

output=$(STUB_CODENAME=precise LANG=en_US.UTF-8 run_script --nonsense)
assert_output 'CLI: unknown option' "$output" "An option doesn't exist"

reset_logs
yes y | PATH="$STUBS:$PATH" STUB_CODENAME=precise LANG=en_US.UTF-8 bash "$SCRIPT" --unlock >/dev/null
assert_log 'CLI: --unlock disables screen locking' 'gnome-screensaver/lock_enabled false'

reset_logs
yes n | PATH="$STUBS:$PATH" STUB_CODENAME=precise LANG=en_US.UTF-8 bash "$SCRIPT" --unlock >/dev/null
assert_no_log 'CLI: answering no changes nothing' 'gconftool-2'

reset_logs
yes y | PATH="$STUBS:$PATH" STUB_CODENAME=precise LANG=en_US.UTF-8 bash "$SCRIPT" --compiz >/dev/null
assert_log 'CLI: --compiz resets Compiz' 'recursive-unset /apps/compiz'

reset_logs
yes y | PATH="$STUBS:$PATH" STUB_CODENAME=precise LANG=en_US.UTF-8 bash "$SCRIPT" --panel >/dev/null
assert_log 'CLI: --panel resets panels' 'recursive-unset /apps/panel'

# --------------------------------------------- functions loaded without running
# shellcheck source=../ubumatic.sh disable=SC1091
source "$SCRIPT"
content=$(sources_list_content precise extras)
assert_output 'sources.list: extras entry sits at line 11 like in the original' "$(sed -n 11p <<<"$content")" '^deb http://extras.ubuntu.com/ubuntu precise main$'
assert_output 'sources.list: security entry follows' "$(sed -n 13p <<<"$content")" 'precise-security'
plain=$(sources_list_content lucid)
assert_output 'sources.list: without extras line 11 is security' "$(sed -n 11p <<<"$plain")" 'lucid-security'
assert_output 'sources.list: proposed stays commented out' "$(sed -n 7p <<<"$plain")" '^# deb .* lucid-proposed'

# ------------------------------------------------------------------- lite --
LITE=$ROOT/ubumatic-lite.sh
output=$("$LITE" --dry-run --upgrade --clean)
assert_output 'lite: dry-run prints the upgrade command' "$output" '\[dry-run\] sudo apt-get -y upgrade'
assert_output 'lite: dry-run prints the clean command' "$output" '\[dry-run\] sudo apt-get clean'
output=$("$LITE" --dry-run --all)
assert_output 'lite: --all includes codecs' "$output" 'ubuntu-restricted-extras'
output=$(printf 'n\nn\nn\nn\nn\ny\n' | "$LITE" --dry-run)
assert_output 'lite: interactive answer selects clean' "$output" 'autoremove --purge'
assert_output 'lite: interactive "no" skips upgrade' "$(grep -c 'upgrade' <<<"$output" || true)" '^0$'
output=$("$LITE" --bogus 2>&1 || true)
assert_output 'lite: unknown option is rejected' "$output" 'unknown option'

echo
echo "passed: $passed, failed: $failed"
[[ $failed -eq 0 ]]
