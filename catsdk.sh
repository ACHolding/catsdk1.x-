#!/bin/bash
# ================================================
# Catsdk.sh — Devkit Pro + stubs (official PKG only)
# Uses official GitHub *release* PKG (no git clone). pkg.devkitpro.org often 403s curl.
# ================================================
set -euo pipefail

DKP_PACMAN="${DKP_PACMAN:-/opt/devkitpro/pacman/bin/dkp-pacman}"

ps_label() {
	case "$1" in
	ps1) echo "PS1" ;; ps2) echo "PS2" ;; ps3) echo "PS3" ;; ps4) echo "PS4" ;; ps5) echo "PS5" ;;
	*) printf '%s' "$1" | tr '[:lower:]' '[:upper:]' ;;
	esac
}

echo "Catsdk — Devkit Pro + console stubs (Apple Silicon preferred) ..."
sleep 1

echo "- Detecting architecture ..."
# Official macOS PKG is on GitHub Releases (not pkg.devkitpro.org — that host often 403s curl).
# Latest release ships a single universal .pkg for Apple Silicon + Intel.
GITHUB_PKG_LATEST="https://github.com/devkitPro/pacman/releases/latest/download/devkitpro-pacman-installer.pkg"
PKG_URL="${DEVKITPRO_PKG_URL:-$GITHUB_PKG_LATEST}"
if [[ $(uname -m) == "arm64" ]]; then
	echo "   arm64 — using official devkitPro pacman PKG"
else
	echo "   x86_64/other — same universal PKG"
fi

DL="/tmp/devkitpro-pacman.pkg"
echo "- Obtaining devkitPro PKG ..."

if [[ -n "${DEVKITPRO_PKG:-}" && -f "${DEVKITPRO_PKG}" ]]; then
	echo "   Using local file DEVKITPRO_PKG=$DEVKITPRO_PKG"
	cp -f "${DEVKITPRO_PKG}" "$DL"
else
	echo "   URL: $PKG_URL"

	curl_download() {
		local url="$1"
		local out="$2"
		local ua="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:122.0) Gecko/20100101 Firefox/122.0"
		if curl -fSL --retry 3 -A "$ua" "$url" -o "$out"; then
			return 0
		fi
		if curl -fSL --retry 3 "$url" -o "$out"; then
			return 0
		fi
		return 1
	}

	if command -v curl >/dev/null 2>&1; then
		if ! curl_download "$PKG_URL" "$DL"; then
			echo "WARN: Primary download failed — trying pinned release URL ..."
			curl_download "https://github.com/devkitPro/pacman/releases/download/v6.0.2/devkitpro-pacman-installer.pkg" "$DL" \
				|| true
		fi
	elif command -v wget >/dev/null 2>&1; then
		wget -q --show-progress "$PKG_URL" -O "$DL" || wget -q --show-progress \
			"https://github.com/devkitPro/pacman/releases/download/v6.0.2/devkitpro-pacman-installer.pkg" -O "$DL"
	else
		echo "ERROR: Need curl or wget to download PKG."
		exit 1
	fi

	if [[ ! -s "$DL" ]]; then
		echo "ERROR: Download failed or empty file."
		echo "  • Download in Safari: https://github.com/devkitPro/pacman/releases/latest"
		echo "  • Then:  export DEVKITPRO_PKG=/path/to/devkitpro-pacman-installer.pkg && sudo ./catsdk.sh"
		echo "  • Or pin URL:  export DEVKITPRO_PKG_URL='https://github.com/devkitPro/pacman/releases/download/v6.0.2/devkitpro-pacman-installer.pkg'"
		exit 1
	fi
fi

if command -v file >/dev/null 2>&1; then
	if ! file "$DL" | grep -qiE 'xar|Macintosh|Installer|packages|pkg'; then
		echo "WARN: File type looks odd — continuing:" "$(file "$DL")"
	fi
fi

sudo installer -pkg "$DL" -target /
rm -f "$DL"

xcode-select --install 2>/dev/null || true

if [[ ! -x "$DKP_PACMAN" ]]; then
	echo "ERROR: Expected dkp-pacman at $DKP_PACMAN after install."
	exit 1
fi

echo ""
echo "- Syncing pacman + Nintendo toolchains (real SDKs)..."

sudo "$DKP_PACMAN" -Sy --noconfirm || true

# Install groups individually so one unknown name does not stop the rest
_install() {
	sudo "$DKP_PACMAN" -S --noconfirm "$1" 2>/dev/null \
		|| echo "    (skipped: $1)"
}

_install gb-dev
_install gp32-dev
_install gba-dev
_install dsi-dev
_install ds-dev
_install nds-dev
_install 3ds-dev
_install gamecube-dev
_install wii-dev
_install wiiu-dev
_install switch-dev

echo ""
echo "Console status:"
echo "   Nintendo handhelds/console (above) → devkitPro when packages exist"
echo "   PS / retail Sega / Atari retail SDK → not redistributable; stubs only"

WRAP="/usr/local/catsdk-wrappers"
sudo mkdir -p "$WRAP"

for console in ps1 ps2 ps3 ps4 ps5; do
	LAB="$(ps_label "$console")"
	TARGET="Modern SIE"
	if [[ "$console" == "ps1" ]]; then
		TARGET="MIPS R3000-era (retail toolchain NDA-only)"
	fi
	sudo tee "$WRAP/${console}-gcc" > /dev/null << WRAP_EOF
#!/bin/bash
echo "Catsdk: ${LAB} stub (no public ${LAB} compiler on macOS)"
echo "  Target note: ${TARGET}"
echo "  Args:" "\$@"
echo "  This does not build a real ${LAB} binary — use official partner SDKs only."
exit 1
WRAP_EOF
	sudo chmod +x "$WRAP/${console}-gcc"
	sudo ln -sf "$WRAP/${console}-gcc" "/usr/local/bin/${console}-gcc" \
		|| sudo cp -f "$WRAP/${console}-gcc" "/usr/local/bin/${console}-gcc"
done

sudo tee "/usr/local/bin/catsdk-gba" > /dev/null << 'GBA_EOF'
#!/bin/bash
set -euo pipefail
if [[ $# -lt 2 ]]; then
	echo "usage: catsdk-gba <source.c|cpp> <basename>"
	exit 1
fi
if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then
	echo "Catsdk-gba: arm-none-eabi-gcc not found. Open a new terminal or add DEVKITARM to PATH."
	exit 1
fi
SRC="$1"
BASE="$2"
arm-none-eabi-gcc -o "${BASE}.elf" "$SRC" -specs=gba.specs -ltonc
if command -v gbafix >/dev/null 2>&1; then
	gbafix "${BASE}.elf" -o "${BASE}.gba"
else
	arm-none-eabi-objcopy -O binary "${BASE}.elf" "${BASE}.gba"
fi
echo "ROM ready: ${BASE}.gba"
GBA_EOF
sudo chmod +x "/usr/local/bin/catsdk-gba"

echo ""
echo "========================================"
echo "Catsdk installer finished."
echo "========================================"
echo ""
echo "Try:"
echo "  catsdk-gba main.c pong     (needs DEVKITARM on PATH)"
echo "  ps1-gcc …                 (shows stub / exits 1)"
echo ""
echo "Meow."
