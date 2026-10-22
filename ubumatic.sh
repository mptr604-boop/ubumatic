#!/bin/bash
# Ubumatic for Ubuntu 10.04 LTS Lucid Lynx, 12.04 LTS Precise Pangolin and other versions
# Description: Simple script to configure and manage the system
# License: GPLv3
##    Ubumatic
##    Copyright (C) 2012  Piotr Miros
##
##    This program is free software: you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Readable refactor of the original script. Behaviour is kept, only the code
# structure changed (named variables, functions, message tables, quoting).
# Known limitations of the original design are listed in README.md.

set -u

readonly UBUNTU_ARCHIVE=http://archive.ubuntu.com/ubuntu/
readonly CANONICAL_ARCHIVE=http://archive.canonical.com/ubuntu
readonly SECURITY_ARCHIVE=http://security.ubuntu.com/ubuntu
readonly EXTRAS_ARCHIVE=http://extras.ubuntu.com/ubuntu
readonly APT_COMPONENTS='main restricted universe multiverse'
readonly KERNEL_MAINLINE_URL=http://kernel.ubuntu.com/~kernel-ppa/mainline/
readonly SOURCES_BACKUP=/etc/apt/sources.list.backup_l1
readonly BOLD=$'\e[1m'
readonly RESET=$'\e[0m'

declare -A T=()
ARCH=
RELEASE=          # codename reported by lsb_release
LOGIC_RELEASE=    # lucid or precise (quantal is handled as precise)
RELEASE_LABEL=
ARCH_LABEL=
WIN_WIDTH=
WIN_HEIGHT=
SUDO_PASSWORD=
WORK_DIR=

# ---------------------------------------------------------------- messages --

load_messages_pl() {
	T[bits_suffix]=owe
	T[wait]=$'Proszę czekać...\n\nMoże to potrwać od kilku do kilkunastu minut'
	T[arch_unsupported]='Skrypt nie obsługuje tej architektury procesora'
	T[os_unsupported]='Skrypt nie obsługuje tego systemu operacyjnego'
	T[not_found]='Nie znaleziono/zainstaluj'
	T[enter_password]='Proszę podać swoje hasło'
	T[no_admin]='Brak uprawnień administratora'
	T[bad_password]='Niepoprawne hasło'
	T[other_pm]='W tle pracuje inny menedżer pakietów'
	T[configure_title]='Skonfiguruj Ubuntu'
	T[select_options]='Zaznacz opcje'
	T[opt_repo]='Ustaw zalecane repozytorium (obowiązkowe)'
	T[opt_updates]='Zainstaluj najnowsze aktualizacje'
	T[opt_codecs]='Zainstaluj kodeki audio, wideo, DVD itp'
	T[opt_flash_java]='Zainstaluj Flasha i Javę dla przeglądarek internetowych'
	T[opt_archivers]='Zainstaluj RAR-a i 7-Zipa do kompresji i dekompresji plików'
	T[opt_fonts]='Zainstaluj Windowsowe czcionki'
	T[opt_totem]='Ustaw polskie napisy w odtwarzaczu Totem'
	T[opt_tweak]='Zainstaluj Ubuntu Tweak do wygodnego zarządzania systemem'
	T[checking_net]='Trwa sprawdzanie połączenia z internetem'
	T[net_failed]='Połączenie z internetem nie powiodło się'
	T[configuring_repo]='Trwa konfigurowanie repozytorium'
	T[repo_hint]=$'Jeśli nie zaznaczyłeś opcji, która ustawia repozytorium, to\nwtedy nie wszystkie pakiety mogą zostać zainstalowane'
	T[install_failed]='Instalacja/aktualizacja nie powiodła się. Naciśnij enter'
	T[repairing]='Trwa sprawdzanie i w razie czego naprawianie problemów'
	T[ask_clean]=$'Czy chcesz usunąć pobrane pliki, aby\nzwolnić trochę miejsca na dysku'
	T[cleaning]='Usuwanie pobranych plików'
	T[finished]=$'Zakończono\n\nUbumatic dla Ubuntu 10.04 LTS Lucid Lynx\ni 12.04 LTS Precise Pangolin\n\nLicencja: GPLv3'
	T[opt_gadu]='Zainstaluj wtyczkę obsługującą Gadu-Gadu w komunikatorze Empathy'
	T[opt_panels]='Zainstaluj klasyczne panele GNOME'
	T[yes_no]='(T)ak/(N)ie:'
	T[finished_cli]=$'Zakończono\n\nUbumatic dla Ubuntu\n'
	T[license_cli]=$'Licencja: GPLv3'
	T[restart]='Uruchomić ponownie komputer'
	T[run_as_root]='Uruchom skrypt z prawami roota (sudo ubumatic.sh --opcja)'
	T[configure]='Skonfiguruj'
	T[configure_desc]=$'Ustaw zalecane repozytorium; zainstaluj najnowsze aktualizacje; kodeki audio,\nwideo, DVD itp.; Flasha i Javę dla przeglądarek internetowych; RAR-a, 7-Zipa\ndo kompresji i dekompresji plików oraz Windowsowe czcionki'
	T[help_title]=$'Ubumatic dla Ubuntu 10.04 LTS Lucid Lynx, 12.04 LTS Precise Pangolin i innych\nwersji - prosty skrypt do konfigurowania i zarządzania systemem\nKonfiguracja Ubuntu'
	T[additional_options]='Dodatkowe opcje'
	T[option]=opcja
	T[help_help]=pomoc
	T[help_button]='zmień kolejność przycisków w Metacity'
	T[help_compiz]='przywróć domyślne ustawienia w Compiz Fusion'
	T[help_mplayer]=$'\n\t--mplayer - ustaw polskie napisy w odtwarzaczu multimedialnym MPlayer'
	T[help_panel]='przywróć domyślny wygląd paneli w GNOME'
	T[help_sonata]='skonfiguruj odtwarzacz muzyczny MPD + Sonata'
	T[help_unlock]=$'wyłącz blokowanie ekranu w GNOME 2 (hibernacja, uśpienie,\n\t  wygaszacz)'
	T[help_clean]='usuń zbędne pakiety, pobrane i konfiguracyjne pliki'
	T[help_empty]=$'opróżnij kosz oraz wyczyść katalog Thumbnails ze wszystkich\n\t  kont'
	T[help_grub]='zainstaluj ponownie program rozruchowy GRUB 2 (tylko z Live CD)'
	T[help_hibernate]='przywrócenie opcji hibernacji'
	T[help_kernelnew]='zainstaluj najnowszą wersję kernela (mainline)'
	T[help_kernelold]='usuń stare wersje kerneli'
	T[help_kubuntu]='podstawowa konfiguracja Kubuntu (KDE)'
	T[help_lubuntu]='podstawowa konfiguracja Lubuntu (LXDE)'
	T[help_repair]='napraw uszkodzone pakiety'
	T[help_repositories]=$'edytuj repozytorium (sources.list), aktualizuj wpisy\n\t  i pobierz brakujące klucze GPG'
	T[help_ubuntu]='podstawowa konfiguracja Ubuntu (GNOME)'
	T[help_upgrade]='zainstaluj najnowsze aktualizacje'
	T[help_xubuntu]='podstawowa konfiguracja Xubuntu (Xfce)'
	T[warning]='UWAGA! Ze skryptu korzystasz na własną odpowiedzialność'
	T[zenity_missing]='Nie znaleziono zenity'
	T[button_title]='Zmień kolejność przycisków'
	T[select_option]='Wybierz opcję'
	T[right_side]='Prawa strona'
	T[left_side]='Lewa strona'
	T[custom_settings]='Własne ustawienia'
	T[default_settings]='Domyślne ustawienia'
	T[enter_custom]='Wpisz własną wartość'
	T[title_clean]='Usuń zbędne pakiety, pobrane i konfiguracyjne pliki'
	T[title_empty]='Opróżnij kosz oraz wyczyść katalog Thumbnails ze wszystkich kont'
	T[detected_disks]='Wykryte dyski i partycje'
	T[enter_disk]='Wpisz nazwę dysku i partycji, np'
	T[or_q_cancel]='lub q, aby anulować'
	T[no_such_option]='Nie ma takiej opcji'
	T[title_mplayer]='Ustaw polskie napisy w odtwarzaczu multimedialnym MPlayer'
	T[mplayer_missing]='MPlayer nie jest zainstalowany'
	T[title_repositories]='Edytuj repozytorium (sources.list), aktualizuj wpisy i pobierz brakujące klucze GPG'
	T[music_dir]='Muzyka'
	T[sonata_missing]='MPD i Sonata nie są zainstalowane'
	T[title_unlock]='Wyłącz blokowanie ekranu w GNOME 2 (hibernacja, uśpienie, wygaszacz)'
}

load_messages_en() {
	T[bits_suffix]=
	T[wait]=$'Please wait...\n\nIt may take from a few to several minutes'
	T[arch_unsupported]="The script doesn't support this architecture"
	T[os_unsupported]="The script doesn't support this operating system"
	T[not_found]='Not found/install'
	T[enter_password]='Please enter your password'
	T[no_admin]='No administrator privileges'
	T[bad_password]='Password incorrect'
	T[other_pm]='Another package manager is working in the background'
	T[configure_title]='Configure the Ubuntu'
	T[select_options]='Select options'
	T[opt_repo]='Set the recommended repository (required)'
	T[opt_updates]='Install the latest updates'
	T[opt_codecs]='Install the audio, video, DVD codecs, etc'
	T[opt_flash_java]='Install the Flash and Java for web browsers'
	T[opt_archivers]='Install RAR and 7-Zip to compress and decompress files'
	T[opt_fonts]='Install Windows fonts'
	T[opt_totem]=
	T[opt_tweak]='Install Ubuntu Tweak for convenient system management'
	T[checking_net]='Checking internet connection'
	T[net_failed]='Internet connection failure'
	T[configuring_repo]='Configuration repository loading'
	T[repo_hint]=$'Not all packages can be installed if you have not\nselected an option that sets the repository'
	T[install_failed]='Installation/update failed. Press enter'
	T[repairing]='Checking and fixing the problems if neccesary'
	T[ask_clean]=$'Do you want to remove files to free\nup some hard disk space'
	T[cleaning]='Deleting downloaded files'
	T[finished]=$'Finished\n\nUbumatic for Ubuntu 10.04 LTS Lucid Lynx\nand 12.04 LTS Precise Pangolin\n\nLicense: GPLv3'
	T[opt_gadu]=
	T[opt_panels]='Install GNOME classic panels'
	T[yes_no]='(Y)es/(N)o:'
	T[finished_cli]=$'Finished\n\nUbumatic for Ubuntu\n'
	T[license_cli]=$'License: GPLv3'
	T[restart]='Restart the computer'
	T[run_as_root]='Run script as a root (sudo script --option)'
	T[configure]='Configure the'
	T[configure_desc]=$'Set recommended repository, install the latest updates, audio codecs, video,\nDVD, etc., Flash and Java for web browsers, RAR and 7-Zip to compress and\ndecompress files and Windows fonts'
	T[help_title]=$'Ubumatic for Ubuntu 10.04 LTS Lucid Lynx, 12.04 LTS Precise Pangolin and other\nversions - simple script to configure and manage the system\nConfiguration Ubuntu'
	T[additional_options]='Additional options'
	T[option]=option
	T[help_help]=help
	T[help_button]='change the order of buttons in Metacity'
	T[help_compiz]='restore default settings in Compiz Fusion'
	T[help_mplayer]=
	T[help_panel]='restore default appearance of panels in GNOME'
	T[help_sonata]='configure the music player MPD + Sonata'
	T[help_unlock]=$'the screen blocking off in GNOME 2 (hibernate, suspend,\n\t  screen saver)'
	T[help_clean]=$'remove unnecessary packages, downloaded and configuration\n\t  files'
	T[help_empty]='empty trash and the Thumbnails folder for all accounts'
	T[help_grub]='reinstall GRUB 2 (for Live CD use only)'
	T[help_hibernate]='restore the hibernate option'
	T[help_kernelnew]='install the latest version of kernel (mainline)'
	T[help_kernelold]='delete the old versions of kernels'
	T[help_kubuntu]='Kubuntu (KDE) basic configuration'
	T[help_lubuntu]='Lubuntu (LXDE) basic configuration'
	T[help_repair]='repair broken packages'
	T[help_repositories]=$'edit repository (sources.list), update alerts and\n\t  download the missing GPG keys'
	T[help_ubuntu]='Ubuntu (GNOME) basic configuration'
	T[help_upgrade]='install the latest updates'
	T[help_xubuntu]='Xubuntu (Xfce) basic configuration'
	T[warning]='WARNING! Using the script at your own risk'
	T[zenity_missing]='Zenity not found'
	T[button_title]='Change the order of buttons'
	T[select_option]='Select an option'
	T[right_side]='Right'
	T[left_side]='Left'
	T[custom_settings]='Custom settings'
	T[default_settings]='Default settings'
	T[enter_custom]='Enter your own value'
	T[title_clean]='Remove unnecessary packages, downloaded and configuration files'
	T[title_empty]='Empty trash and the Thumbnails folder for all accounts'
	T[detected_disks]='Detected disks and partitions'
	T[enter_disk]='Enter the name of the disk and partition, e.g'
	T[or_q_cancel]='or q to cancel'
	T[no_such_option]="An option doesn't exist"
	T[title_mplayer]=
	T[mplayer_missing]=
	T[title_repositories]='Edit repository (sources.list), update alerts and download the missing GPG keys'
	T[music_dir]='Music'
	T[sonata_missing]="MPD and Sonata isn't installed"
	T[title_unlock]='The screen blocking off in GNOME 2 (hibernate, suspend, screen saver)'
}

is_polish() {
	[[ ${LANG:-} == pl_PL.UTF-8 || ${LANG:-} == pl_PL.utf8 ]]
}

load_messages() {
	if is_polish; then
		load_messages_pl
	else
		LANG=C
		export LANG
		load_messages_en
	fi
}

# ---------------------------------------------------------- system helpers --

detect_system() {
	ARCH=$(LANG=C uname -m 2>/dev/null)
	RELEASE=$(LANG=C lsb_release -cs 2>/dev/null)
	if [[ $ARCH == x86_64 ]]; then
		ARCH_LABEL="64 bit${T[bits_suffix]} (x86_64)"
	else
		ARCH_LABEL="32 bit${T[bits_suffix]} (i686)"
	fi
}

check_system() {
	if [[ $(lsb_release -is 2>/dev/null) != Ubuntu ]]; then
		echo "${T[os_unsupported]}"
		exit 0
	fi
	if [[ $ARCH != x86_64 && $ARCH != i686 ]]; then
		echo "${T[arch_unsupported]}"
		exit 0
	fi
}

require_root() {
	if ((EUID != 0)); then
		echo "${T[run_as_root]}"
		exit 0
	fi
}

make_work_dir() {
	WORK_DIR=$(mktemp -d /tmp/ubumatic.XXXXXX)
}

remove_work_dir() {
	if [[ -n $WORK_DIR && -d $WORK_DIR ]]; then
		rm -rf "$WORK_DIR"
	fi
	WORK_DIR=
}

# Run a command with root privileges. The password (when needed) is piped to
# "sudo -S"; as root, or with cached credentials, nothing is required.
sudo_run() {
	printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@"
}

priv() {
	if ((EUID == 0)); then
		"$@"
	else
		sudo_run "$@"
	fi
}

# write_root_file PATH CONTENT
write_root_file() {
	# shellcheck disable=SC2016 # expanded by the inner bash, not here
	priv env "CONTENT=$2" bash -c 'printf "%s\n" "$CONTENT" > "$0"' "$1"
}

apt_install() {
	apt-get -y --force-yes install "$@"
}

repair_packages() {
	for _ in 1 2; do
		dpkg -a --configure
		apt-get -fy --force-yes install
	done
}

# ----------------------------------------------------------- shared output --

# yes/no prompt; "no" ends the script
confirm() {
	local answer
	while true; do
		read -r -p "$1 " answer
		case $answer in
			[Tt] | [Tt][Aa][Kk] | [Yy] | [Yy][Ee][Ss])
				return 0
				;;
			[Nn] | [Nn][Ii][Ee] | [Nn][Oo])
				clear
				exit 0
				;;
		esac
	done
}

confirm_action() {
	local text=$*
	clear
	printf '%s%s%s\n' "$BOLD" "${text^}" "$RESET"
	confirm "${BOLD}${T[yes_no]}${RESET}"
}

ask_reboot() {
	printf '%s\n%s\n\n%s\n' "${T[finished_cli]%$'\n'}" "${T[license_cli]}" "${T[restart]}"
	confirm "${T[yes_no]}"
	reboot
}

finish_cli() {
	clear
	printf '%s\n%s' "${T[finished_cli]%$'\n'}" "${T[license_cli]}"
	read -r
	clear
	exit 0
}

show_error() {
	if command -v zenity >/dev/null 2>&1; then
		zenity --error --title Ubumatic --text "$*"
	elif command -v kdialog >/dev/null 2>&1; then
		kdialog --title Ubumatic --error "$*"
	else
		echo "$*"
	fi
	exit 0
}

# ------------------------------------------------------ apt sources and keys --

sources_list_content() {
	local release=$1 with_extras=${2:-}
	cat <<EOF
deb $UBUNTU_ARCHIVE $release $APT_COMPONENTS
deb-src $UBUNTU_ARCHIVE $release $APT_COMPONENTS
deb $UBUNTU_ARCHIVE $release-updates $APT_COMPONENTS
deb-src $UBUNTU_ARCHIVE $release-updates $APT_COMPONENTS
deb $UBUNTU_ARCHIVE $release-backports $APT_COMPONENTS
deb-src $UBUNTU_ARCHIVE $release-backports $APT_COMPONENTS
# deb $UBUNTU_ARCHIVE $release-proposed $APT_COMPONENTS
# deb-src $UBUNTU_ARCHIVE $release-proposed $APT_COMPONENTS
deb $CANONICAL_ARCHIVE $release partner
deb-src $CANONICAL_ARCHIVE $release partner
EOF
	if [[ -n $with_extras ]]; then
		printf 'deb %s %s main\ndeb-src %s %s main\n' "$EXTRAS_ARCHIVE" "$release" "$EXTRAS_ARCHIVE" "$release"
	fi
	cat <<EOF
deb $SECURITY_ARCHIVE $release-security $APT_COMPONENTS
deb-src $SECURITY_ARCHIVE $release-security $APT_COMPONENTS
deb http://www.deb-multimedia.org stable main non-free
deb-src http://www.deb-multimedia.org stable main non-free
deb http://archive.getdeb.net/ubuntu $release-getdeb apps games
deb-src http://archive.getdeb.net/ubuntu $release-getdeb apps games
EOF
}

backup_sources_list() {
	if [[ ! -s $SOURCES_BACKUP ]]; then
		priv cp -p /etc/apt/sources.list "$SOURCES_BACKUP"
	fi
}

# configure_repositories [with_extras]
configure_repositories() {
	backup_sources_list
	write_root_file /etc/apt/sources.list "$(sources_list_content "$RELEASE" "${1:-}")"
}

# ------------------------------------------------------------------ GUI mode --

progress_dialog() {
	zenity --width 500 --progress --title Ubumatic --text "$1. ${T[wait]}" --pulsate --auto-close
}

# run_with_progress [--mandatory] TEXT COMMAND...
# Returns the command status, or 143 when the user cancelled the dialog.
# With --mandatory the cancel button is ignored and the dialog is shown again.
run_with_progress() {
	local mandatory=
	if [[ $1 == --mandatory ]]; then
		mandatory=1
		shift
	fi
	local text=$1 pid
	shift
	"$@" &
	pid=$!
	while kill -0 "$pid" 2>/dev/null; do
		(while kill -0 "$pid" 2>/dev/null; do sleep 0.5; done) | progress_dialog "$text"
		if [[ ${PIPESTATUS[1]} -eq 1 && -z $mandatory ]] && kill -0 "$pid" 2>/dev/null; then
			pkill -P "$pid" 2>/dev/null
			kill "$pid" 2>/dev/null
			wait "$pid" 2>/dev/null
			return 143
		fi
	done
	wait "$pid"
}

configure_totem() {
	command -v totem >/dev/null 2>&1 || return 0
	if [[ $LOGIC_RELEASE == lucid ]]; then
		gconftool-2 -t bool -s /apps/totem/autoload_subtitles true
		gconftool-2 -t str -s /apps/totem/subtitle_encoding WINDOWS-1250
	else
		gsettings set org.gnome.totem autoload-subtitles true
		gsettings set org.gnome.totem subtitle-encoding WINDOWS-1250
	fi
}

authenticate_sudo() {
	local output
	sudo -K
	if echo | sudo -Sv >/dev/null 2>&1; then
		SUDO_PASSWORD=
		return 0
	fi
	SUDO_PASSWORD=$(zenity --entry --title Ubumatic --text "${T[enter_password]}" --hide-text) || exit 0
	if ! output=$(printf '%s\n' "$SUDO_PASSWORD" | sudo -Sv 2>&1); then
		if [[ -n $(sed '/\[sudo\].*:/d' <<<"$output") ]]; then
			zenity --error --title Ubumatic --text "${T[no_admin]}"
		else
			zenity --error --title Ubumatic --text "${T[bad_password]}"
		fi
		exit 0
	fi
}

# set_gui_window_size ("polish"/"english" layout differ because of text length)
set_gui_window_size() {
	if is_polish; then
		WIN_HEIGHT=360
		if [[ $LOGIC_RELEASE == lucid ]]; then WIN_WIDTH=540; else WIN_WIDTH=482; fi
	elif [[ $LOGIC_RELEASE == lucid ]]; then
		WIN_HEIGHT=314
		WIN_WIDTH=448
	else
		WIN_HEIGHT=337
		WIN_WIDTH=444
	fi
}

# checklist rows: state, id, label
build_checklist_rows() {
	ROWS=(
		TRUE 1 "${T[opt_repo]}"
		TRUE 2 "${T[opt_updates]}"
		FALSE 3 "${T[opt_codecs]}."
		FALSE 4 "${T[opt_flash_java]}"
		FALSE 5 "${T[opt_archivers]}"
		FALSE 6 "${T[opt_fonts]}"
	)
	if is_polish; then
		ROWS+=(FALSE 7 "${T[opt_totem]}")
	fi
	ROWS+=(FALSE 9 "${T[opt_tweak]}")
	if [[ $LOGIC_RELEASE == lucid ]]; then
		if is_polish; then ROWS+=(FALSE 0 "${T[opt_gadu]}"); fi
	else
		ROWS+=(FALSE a "${T[opt_panels]}")
	fi
}

windows_codec_package() {
	if [[ $ARCH == x86_64 ]]; then echo w64codecs; else echo w32codecs; fi
}

# Translate the checklist selection into WANT_* flags and the PACKAGES list.
parse_selection() {
	local pick
	local -a picks
	IFS=: read -ra picks <<<"$1"
	for pick in "${picks[@]}"; do
		case $pick in
			1)
				WANT_REPO=1
				[[ $LOGIC_RELEASE == precise ]] && WANT_EXTRAS_REPO=1
				;;
			2)
				WANT_UPGRADE=1
				;;
			3)
				PACKAGES+=(gstreamer0.10-ffmpeg gstreamer0.10-plugins-bad gstreamer0.10-plugins-bad-multiverse gstreamer0.10-plugins-ugly libdvdcss2 "$(windows_codec_package)")
				if [[ $LOGIC_RELEASE == lucid ]]; then
					PACKAGES+=(libavcodec-extra-52 libmp4v2-0 gstreamer0.10-plugins-ugly-multiverse)
					[[ $ARCH == i686 ]] && PACKAGES+=(gstreamer0.10-pitfdll)
				else
					PACKAGES+=(gstreamer0.10-fluendo-mp3 libavcodec-extra-53)
				fi
				;;
			4)
				if [[ $ARCH == x86_64 ]]; then PACKAGES+=(flashplugin-installer); else PACKAGES+=(adobe-flashplugin); fi
				if [[ $LOGIC_RELEASE == lucid ]]; then PACKAGES+=(icedtea6-plugin); else PACKAGES+=(icedtea-7-plugin); fi
				;;
			5)
				PACKAGES+=(p7zip-rar unrar)
				;;
			6)
				PACKAGES+=(ttf-mscorefonts-installer)
				;;
			b)
				PACKAGES+=(ubuntu-restricted-extras libdvdcss2 p7zip-rar "$(windows_codec_package)")
				[[ $LOGIC_RELEASE == precise ]] && PACKAGES+=(icedtea-7-plugin)
				;;
			7)
				if ((EUID != 0)); then
					configure_totem
				else
					su "$LOGNAME" -c "$(declare -p LOGIC_RELEASE); $(declare -f configure_totem); configure_totem"
				fi
				;;
			9)
				WANT_TWEAK_PPA=1
				PACKAGES+=(ubuntu-tweak)
				;;
			0)
				[[ $LOGIC_RELEASE == lucid ]] && WANT_TELEPATHY_PPA=1
				PACKAGES+=(telepathy-sunshine)
				;;
			a)
				PACKAGES+=(gnome-session-fallback)
				;;
		esac
	done
}

check_internet() {
	local rc=0
	for _ in 1 2; do
		wget -4 -q -t 10 -T 5 --no-cache --no-dns-cache --no-proxy --spider "$UBUNTU_ARCHIVE"
		rc=$?
	done
	return "$rc"
}

setup_repositories_gui() {
	if [[ $WANT_REPO -eq 1 ]]; then
		if [[ $WANT_EXTRAS_REPO -eq 1 ]]; then
			configure_repositories extras
		else
			configure_repositories
		fi
		sudo_run apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 07DC563D1F41B907 A8A515F046D7E7CF
	fi
	[[ $WANT_TWEAK_PPA -eq 1 ]] && sudo_run add-apt-repository ppa:tualatrix/ppa
	[[ $WANT_TELEPATHY_PPA -eq 1 ]] && sudo_run add-apt-repository ppa:kkszysiu/telepathy
}

# Runs inside xterm: only exported variables are visible there.
apt_worker() {
	local failed='' package
	printf '%s\n' "$SUDO_PASSWORD" | sudo -S apt-get update
	if [[ $WANT_UPGRADE == 1 ]]; then
		printf '%s\n' "$SUDO_PASSWORD" | sudo -S apt-get -y --force-yes upgrade || failed=1
		printf '%s\n' "$SUDO_PASSWORD" | sudo -S apt-get -y --force-yes dist-upgrade || failed=1
	fi
	for package in $APT_PACKAGES; do
		printf '%s\n' "$SUDO_PASSWORD" | sudo -S apt-get -y --force-yes install "$package" || failed=1
	done
	if [[ -n $failed ]]; then
		clear
		read -r -p "$INSTALL_FAILED_MESSAGE"
	fi
}

xterm_geometry() {
	local width height
	read -r width height < <(xrandr 2>/dev/null | sed -n 's/^ *\([0-9]\+\)x\([0-9]\+\).*\*.*/\1 \2/p' | head -n 1)
	if [[ -n ${width:-} && -n ${height:-} ]]; then
		printf '80x24+%d+%d' $(((width - 484) / 2)) $(((height - 316) / 2))
	else
		printf '80x24'
	fi
}

run_apt_in_terminal() {
	export SUDO_PASSWORD WANT_UPGRADE
	export APT_PACKAGES="${PACKAGES[*]}"
	export INSTALL_FAILED_MESSAGE="${T[install_failed]}"
	xterm -title Ubumatic -geometry "$(xterm_geometry)" -e bash -c "$(declare -f apt_worker); apt_worker"
}

fix_broken_packages_gui() {
	for _ in 1 2; do
		sudo_run dpkg -a --configure
		sudo_run apt-get -fy --force-yes install
	done
}

run_gui() {
	local selection rc
	WANT_REPO=0 WANT_EXTRAS_REPO=0 WANT_UPGRADE=0 WANT_TWEAK_PPA=0 WANT_TELEPATHY_PPA=0
	PACKAGES=()

	case $RELEASE in
		quantal) LOGIC_RELEASE=precise RELEASE_LABEL='12.10 Quantal Quetzal' ;;
		lucid) LOGIC_RELEASE=lucid RELEASE_LABEL='10.04 LTS Lucid Lynx' ;;
		precise) LOGIC_RELEASE=precise RELEASE_LABEL='12.04 LTS Precise Pangolin' ;;
		*) LOGIC_RELEASE=$RELEASE RELEASE_LABEL='12.04 LTS Precise Pangolin' ;;
	esac

	if [[ -t 0 ]]; then
		"$0" --help
		[[ $LOGIC_RELEASE == lucid || $LOGIC_RELEASE == precise ]] || exit 0
	fi

	if [[ $LOGIC_RELEASE != lucid && $LOGIC_RELEASE != precise ]]; then
		show_error "${T[os_unsupported]}"
	fi
	if [[ $ARCH != x86_64 && $ARCH != i686 ]]; then
		show_error "${T[arch_unsupported]}"
	fi

	local tool missing=
	for tool in xterm zenity; do
		command -v "$tool" >/dev/null 2>&1 || missing+=" $tool"
	done
	[[ -n $missing ]] && show_error "${T[not_found]}:$missing"

	authenticate_sudo
	if printf '%s\n' "$SUDO_PASSWORD" | sudo -S fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
		zenity --error --title Ubumatic --text "${T[other_pm]}"
		exit 0
	fi

	set_gui_window_size
	build_checklist_rows
	selection=$(zenity --width "$WIN_WIDTH" --height "$WIN_HEIGHT" --list --title Ubumatic \
		--text "${T[configure_title]} $RELEASE_LABEL $ARCH_LABEL" --hide-column 2 --checklist \
		--column '' --column '' --column "${T[select_options]}" --separator : "${ROWS[@]}") || exit 0
	[[ -z $selection ]] && exit 0
	selection=${selection/3:4:5:6/b}
	parse_selection "$selection"

	if [[ $WANT_REPO -eq 1 || $WANT_UPGRADE -eq 1 || $WANT_TWEAK_PPA -eq 1 || $WANT_TELEPATHY_PPA -eq 1 || ${#PACKAGES[@]} -gt 0 ]]; then
		run_with_progress "${T[checking_net]}" check_internet
		rc=$?
		if [[ $rc -eq 4 || $rc -eq 143 ]]; then
			remove_work_dir
			zenity --error --title Ubumatic --text "${T[net_failed]}"
			exit 0
		fi
	fi

	if [[ $WANT_REPO -eq 1 || $WANT_TWEAK_PPA -eq 1 || $WANT_TELEPATHY_PPA -eq 1 ]]; then
		run_with_progress "${T[configuring_repo]}" setup_repositories_gui
		if [[ $? -eq 143 ]]; then
			WANT_TWEAK_PPA=0
			WANT_TELEPATHY_PPA=0
		fi
	fi

	if [[ ${#PACKAGES[@]} -gt 0 || $WANT_REPO -eq 1 || $WANT_UPGRADE -eq 1 ]]; then
		[[ ${#PACKAGES[@]} -gt 0 ]] && zenity --warning --title Ubumatic --text "${T[repo_hint]}" --timeout 5
		run_apt_in_terminal
	fi

	if [[ ${#PACKAGES[@]} -gt 0 || $WANT_REPO -eq 1 || $WANT_UPGRADE -eq 1 ]]; then
		run_with_progress --mandatory "${T[repairing]}" fix_broken_packages_gui
		if zenity --question --title Ubumatic --text "${T[ask_clean]}?"; then
			run_with_progress --mandatory "${T[cleaning]}" sudo_run apt-get clean
		fi
	fi

	remove_work_dir
	zenity --info --title Ubumatic --text "${T[finished]}"
	exit 0
}

# ------------------------------------------------------------ command line --

set_recommended_repositories() {
	configure_repositories "$([[ $RELEASE != lucid ]] && echo extras)"
	wget -q http://www.deb-multimedia.org/dists/stable/Release.gpg http://archive.getdeb.net/getdeb-archive.key -O - | apt-key add -
	apt-get update
	apt-get -y --force-yes upgrade
	apt-get -y --force-yes dist-upgrade
	apt_install libdvdcss2 p7zip-rar
	apt_install "$(windows_codec_package)"
	[[ $RELEASE != lucid ]] && apt_install icedtea-7-plugin
}

confirm_system_setup() {
	check_system
	require_root
	confirm_action "${T[configure]} $(lsb_release -ds) $ARCH_LABEL"$'\n'"${RESET}${T[configure_desc]}${RESET}"
}

cmd_help() {
	check_system
	clear
	printf '%s:\n\t%s\n%s:\n\t[[ %s --%s ]]\n' "${T[help_title]}" "$0" "${T[additional_options]}" "$0" "${T[option]}"
	printf '\t--help - %s\n' "${T[help_help]}"
	printf '\t--button - %s\n' "${T[help_button]}"
	printf '\t--compiz - %s%s\n' "${T[help_compiz]}" "${T[help_mplayer]}"
	printf '\t--panel - %s\n' "${T[help_panel]}"
	printf '\t--sonata - %s\n' "${T[help_sonata]}"
	printf '\t--unlock - %s\n' "${T[help_unlock]}"
	printf '\t[[ sudo %s --%s ]]\n' "$0" "${T[option]}"
	local name
	for name in clean empty grub hibernate kernelnew kernelold kubuntu lubuntu repair repositories ubuntu upgrade xubuntu; do
		printf '\t--%s - %s\n' "$name" "${T[help_$name]}"
	done
	printf '\n%s\n\n%s' "${T[warning]}" "${T[license_cli]}"
	read -r
	clear
	exit 0
}

cmd_button() {
	local choice custom
	check_system
	if ! command -v zenity >/dev/null 2>&1; then
		echo "${T[zenity_missing]}"
		exit 0
	fi
	local width
	if is_polish; then
		if [[ $RELEASE == lucid ]]; then width=212; else width=210; fi
	elif [[ $RELEASE == lucid ]]; then
		width=206
	else
		width=213
	fi
	choice=$(zenity --width "$width" --height 205 --list --title Ubumatic --text "${T[button_title]}" \
		--hide-column 2 --radiolist --column '' --column '' --column "${T[select_option]}" \
		TRUE 1 "${T[right_side]}" \
		FALSE 2 "${T[left_side]}" \
		FALSE 3 "${T[custom_settings]}" \
		FALSE 4 "${T[default_settings]}")
	case $choice in
		1) gconftool-2 -t str -s /apps/metacity/general/button_layout :minimize,maximize,close ;;
		2) gconftool-2 -t str -s /apps/metacity/general/button_layout close,minimize,maximize: ;;
		3)
			if custom=$(zenity --width 300 --entry --title Ubumatic --text "${T[enter_custom]}" --entry-text close,minimize,maximize:menu); then
				gconftool-2 -t str -s /apps/metacity/general/button_layout "$custom"
			fi
			;;
		4) gconftool-2 --recursive-unset /apps/metacity/general/button_layout ;;
		*)
			clear
			exit 0
			;;
	esac
	zenity --info --title Ubumatic --text "${T[finished_cli]%$'\n'}"
	clear
	exit 0
}

cmd_clean() {
	check_system
	require_root
	confirm_action "${T[title_clean]}"
	apt-get -y --purge autoremove
	dpkg -l | sed -n 's/^rc *\([^ ]\+\).*/\1/p' | xargs -r dpkg -P
	apt-get clean
	finish_cli
}

cmd_compiz() {
	check_system
	confirm_action "${T[help_compiz]}"
	gconftool-2 --recursive-unset /apps/compiz
	finish_cli
}

cmd_empty() {
	check_system
	require_root
	confirm_action "${T[title_empty]}"
	rm -rf /home/*/.local/share/Trash/*/** /root/.local/share/Trash/*/** /home/*/.thumbnails/*/** /root/.thumbnails/*/**
	finish_cli
}

cmd_grub() {
	local disk partition
	check_system
	require_root
	confirm_action "${T[help_grub]}"
	echo "${T[detected_disks]}:"
	fdisk -l
	echo
	while true; do
		printf '%s.: /dev/sda /dev/sda1\n%s: ' "${T[enter_disk]}" "${T[or_q_cancel]}"
		read -r disk partition
		if [[ $disk =~ ^/dev/sd[a-z]$ && ${partition:-} =~ ^/dev/sd[a-z][0-9]+$ ]]; then
			mount "$partition" /mnt
			grub-install --boot-directory=/mnt/boot "$disk"
			grub-mkconfig -o /mnt/boot/grub/grub.cfg
			umount /mnt
			ask_reboot
		elif [[ $disk == q ]]; then
			clear
			exit 0
		fi
	done
}

cmd_hibernate() {
	check_system
	require_root
	confirm_action "${T[help_hibernate]}"
	cat >/etc/polkit-1/localauthority/50-local.d/com.ubuntu.desktop.pkla <<'EOF'
[Re-enable hibernate by default]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate
EOF
	ask_reboot
}

cmd_kernelnew() {
	local latest installed arch_suffix
	local -a deb_urls
	clear
	echo .....
	latest=$(wget -q "$KERNEL_MAINLINE_URL" -O - | sed 's/.*\(v[0-9.]*-[a-z]*\/\).*/\1/;/\/$/h;$!d;x')
	check_system
	require_root
	confirm_action "${T[help_kernelnew]}: ${RESET}$([[ -n $latest ]] && sed 's/v\([0-9.]*-[a-z]*\)\//\1/' <<<"$latest" || echo x.x.x)${RESET}"
	installed=$(dpkg -l 'linux-image-[0-9].*-generic' 2>/dev/null | sed -n '$s/.* \([0-9.]*\) .*/\1/p')
	# NOTE: condition kept from the original script; it looks inverted
	# (it installs only when the installed version matches the latest one).
	if [[ $latest =~ $installed ]]; then
		[[ $(uname -m) == x86_64 ]] && arch_suffix=amd64 || arch_suffix=i386
		mapfile -t deb_urls < <(wget -q "$KERNEL_MAINLINE_URL$latest" -O - \
			| sed -n "s_.*\(linux.*\($arch_suffix\|all\)\.deb\).*_$KERNEL_MAINLINE_URL$latest\1_p")
		make_work_dir
		wget -c "${deb_urls[@]}" -P "$WORK_DIR/"
		dpkg -i "$WORK_DIR"/*.deb
		remove_work_dir
	fi
	finish_cli
}

cmd_kernelold() {
	local old_versions
	old_versions=$(dpkg -l 'linux-image-[0-9].*-generic' 2>/dev/null \
		| sed -n '/^ii/!d;$'"d;/$(uname -r)/d;s/.* \([0-9.]\+-[0-9]\+\).*/\1/p")
	check_system
	require_root
	confirm_action "${T[help_kernelold]}: ${RESET}${old_versions}${RESET}"
	# shellcheck disable=SC2086 # the list is intentionally split into versions
	apt-get -y --force-yes purge $old_versions
	finish_cli
}

cmd_flavour() {
	local package=$1
	confirm_system_setup
	set_recommended_repositories
	apt_install "$package"
	repair_packages
	finish_cli
}

cmd_mplayer() {
	check_system
	if ! is_polish; then
		echo "${T[no_such_option]}"
		exit 0
	fi
	confirm_action "${T[title_mplayer]}"
	if [[ -x /usr/bin/mplayer ]]; then
		rm -rf "$HOME/.mplayer"
		mkdir "$HOME/.mplayer"
		cat >"$HOME/.mplayer/config" <<'EOF'
# Write your default config options here!

font=/usr/share/fonts/truetype/freefont/FreeSans.ttf
subcp=cp1250
EOF
		finish_cli
	else
		echo "${T[mplayer_missing]}"
		exit 0
	fi
}

cmd_panel() {
	check_system
	confirm_action "${T[help_panel]}"
	gconftool-2 --recursive-unset /apps/panel
	finish_cli
}

cmd_repair() {
	check_system
	require_root
	confirm_action "${T[help_repair]}"
	repair_packages
	finish_cli
}

cmd_repositories() {
	local missing_keys
	check_system
	require_root
	confirm_action "${T[title_repositories]}"
	nano /etc/apt/sources.list
	for _ in 1 2; do
		missing_keys=$(apt-get update 2>&1 | sed -n 's/.*NO_PUBKEY //p')
		missing_keys=${missing_keys//$'\n'/ }
		# shellcheck disable=SC2086 # several key ids, one per word
		# shellcheck disable=SC2086
		gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys $missing_keys
		# shellcheck disable=SC2086
		gpg --export --armor $missing_keys | apt-key add -
	done
	finish_cli
}

cmd_sonata() {
	local music_dir=${T[music_dir]}
	check_system
	confirm_action "${T[help_sonata]}"
	if [[ -x /usr/bin/mpd && -x /usr/bin/sonata ]]; then
		mkdir -p "$HOME/.mpd/music" "$HOME/.mpd/playlists"
		[[ -d $HOME/$music_dir ]] || mkdir "$HOME/$music_dir"
		ln -sf "$HOME/$music_dir" "$HOME/.mpd/music/"
		cat >"$HOME/.mpd/mpd.conf" <<EOF
music_directory "~/.mpd/music"
playlist_directory "~/.mpd/playlists"
db_file "~/.mpd/tag_cache"
log_file "~/.mpd/mpd.log"
pid_file "~/.mpd/pid"
state_file "~/.mpd/state"
user "$USER"
bind_to_address "127.0.0.1"
port "6666"
input {
 plugin "curl"
}
audio_output {
 type "pulse"
 name "My Pulse Output"
}
mixer_type "software"
filesystem_charset "UTF-8"
id3v1_encoding "UTF-8"
EOF
		mpd --kill
		mpd --create-db "$HOME/.mpd/mpd.conf"
		mkdir -p "$HOME/.config/autostart"
		cat >"$HOME/.config/autostart/mpd.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Exec=mpd .mpd/mpd.conf
Hidden=false
X-GNOME-Autostart-enabled=true
Name[pl_PL]=MPD
Name=MPD
Comment[pl_PL]=
Comment=
EOF
		mkdir -p "$HOME/.config/sonata"
		cat >"$HOME/.config/sonata/sonatarc" <<EOF
[profiles]
num_profiles = 1
names[0] = Domyślny profil
hosts[0] = localhost
ports[0] = 6666
passwords[0] = 
musicdirs[0] = $HOME
EOF
		finish_cli
	else
		echo "${T[sonata_missing]}"
		exit 0
	fi
}

cmd_unlock() {
	check_system
	confirm_action "${T[title_unlock]}"
	gconftool-2 -t bool -s /apps/gnome-power-manager/lock/hibernate false
	gconftool-2 -t bool -s /apps/gnome-power-manager/lock/suspend false
	gconftool-2 -t bool -s /apps/gnome-screensaver/lock_enabled false
	finish_cli
}

cmd_upgrade() {
	check_system
	require_root
	confirm_action "${T[help_upgrade]}"
	apt-get update
	apt-get -y --force-yes upgrade
	apt-get -y --force-yes dist-upgrade
	finish_cli
}

main() {
	load_messages
	detect_system

	case ${1:-} in
		'')
			if [[ -n ${UBUMATIC_DEBUG:-} ]]; then run_gui; else run_gui 2>/dev/null; fi
			;;
		--help) cmd_help ;;
		--button) cmd_button ;;
		--clean) cmd_clean ;;
		--compiz) cmd_compiz ;;
		--empty) cmd_empty ;;
		--grub) cmd_grub ;;
		--hibernate) cmd_hibernate ;;
		--kernelnew) cmd_kernelnew ;;
		--kernelold) cmd_kernelold ;;
		--kubuntu) cmd_flavour kubuntu-restricted-extras ;;
		--lubuntu) cmd_flavour lubuntu-restricted-extras ;;
		--mplayer) cmd_mplayer ;;
		--panel) cmd_panel ;;
		--repair) cmd_repair ;;
		--repositories) cmd_repositories ;;
		--sonata) cmd_sonata ;;
		--ubuntu) cmd_flavour ubuntu-restricted-extras ;;
		--unlock) cmd_unlock ;;
		--upgrade) cmd_upgrade ;;
		--xubuntu) cmd_flavour xubuntu-restricted-extras ;;
		*)
			check_system
			echo "${T[no_such_option]}"
			exit 0
			;;
	esac
}

# Allow sourcing the file (used by the tests) without running anything.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	main "$@"
fi
