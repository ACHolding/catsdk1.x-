#!/bin/bash
# ================================================
# Catsdk.sh — Devkit Pro + stubs (official PKG only)
# Uses official GitHub *release* PKG (no git clone). pkg.devkitpro.org often 403s curl.
# ================================================
set -euo pipefail

# Newer macOS devkitPro PKG installs dkp-pacman in /usr/local/bin (Linux often uses .../pacman/bin).
resolve_dkp_pacman() {
	local cand

	export PATH="/usr/local/bin:/opt/devkitpro/tools/bin:/opt/devkitpro/pacman/bin:${PATH:-}"
	for cand in "${DKP_PACMAN:-}" "$(command -v dkp-pacman 2>/dev/null || true)" \
		/usr/local/bin/dkp-pacman \
		/opt/devkitpro/pacman/bin/dkp-pacman \
		/opt/devkitpro/tools/bin/dkp-pacman; do
		if [[ -n "$cand" && -x "$cand" ]]; then
			echo "$cand"
			return 0
		fi
	done
	return 1
}

DKP_PACMAN="${DKP_PACMAN:-}"

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

DKP_PACMAN="$(resolve_dkp_pacman || true)"
if [[ -z "${DKP_PACMAN}" ]] || [[ ! -x "${DKP_PACMAN}" ]]; then
	echo ""
	echo "ERROR: dkp-pacman not found after PKG install."
	echo "Try: open a NEW Terminal tab (updates PATH), or run:"
	echo "     ls -la /usr/local/bin/dkp-pacman"
	echo "     export DKP_PACMAN=/full/path/to/dkp-pacman && sudo ./catsdk.sh"
	echo "Some macOS setups need reboot once after pkg (see devkitpro.org wiki)."
	exit 1
fi
echo "- Using pacman binary: ${DKP_PACMAN}"

echo ""
echo "- Syncing pacman + Nintendo toolchains (real SDKs)..."

sudo "${DKP_PACMAN}" -Sy --noconfirm || true

# Install groups individually so one unknown name does not stop the rest
_install() {
	sudo "${DKP_PACMAN}" -S --noconfirm "$1" 2>/dev/null \
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
echo "- Optional: Homebrew cc65 (6502: Atari 8‑bit / NES homebrew style) ..."
if command -v brew >/dev/null 2>&1; then
	HOMEBREW_NO_AUTO_UPDATE=1 brew install cc65 || echo "    (cc65 skipped)"
else
	echo "    (no Homebrew — skip cc65; install brew if you want 6502 toolchain)"
fi

echo ""
echo "Console status:"
echo "   Nintendo (gb/gba/nds/3ds/GC/Wii/WiiU/Switch) → devkitPro packages above when available"
echo "   Atari → Dreamcast (stubs) → PlayStation PS1–PS5 (stubs) → use partner / community SDKs as applicable"

WRAP="/usr/local/catsdk-wrappers"
sudo mkdir -p "$WRAP"

# ---------------------------------------------------------------------------
# Retro / Nintendo / Sega-class stubs (see devkitPro + cc65 above for real bits)
# ---------------------------------------------------------------------------
WRAP_CONSOLES=(
	atari2600 atari7800 lynx jaguar nes snes genesis gb gbc
	gba nds 3ds n64 gc wii wiiu switch dreamcast
)

# ---------------------------------------------------------------------------
# PlayStation PS1–PS5: Sony does not ship public macOS *-gcc binaries here.
# These install /usr/local/bin/ps1-gcc … ps5-gcc as informational stubs (exit 1).
# Real retail builds need SIE / registered partner SDKs & licenses.
# ---------------------------------------------------------------------------
PS_STUBS=(ps1 ps2 ps3 ps4 ps5)

for console in "${WRAP_CONSOLES[@]}" "${PS_STUBS[@]}"; do
	LAB="$(ps_label "$console")"
	TARGET="Community or partner SDK — not bundled by this stub"
	case "$console" in
	atari2600|atari7800|lynx|nes)
		TARGET="6502-era homebrew: use cc65 (brew install cc65) — see catsdk-cc65-help"
		;;
	jaguar|snes|genesis|dreamcast)
		TARGET="No standard public retail macOS *-gcc wired here"
		;;
	gb|gbc|gba|nds|3ds|gc|wii|wiiu|switch)
		TARGET="Use devkitPro / dkp-pacman toolchain above — this wrapper is informational only"
		;;
	n64) TARGET="N64 toolchain is separate / partner mips tools — stub only" ;;
	ps1) TARGET="PS1: retail toolchain is partner-only / NDA (MIPS R3000 class)" ;;
	ps2) TARGET="PS2: EE — SIE partner SDK only" ;;
	ps3) TARGET="PS3: Cell — SIE partner SDK only" ;;
	ps4) TARGET="PS4: x86_64 — SIE partner SDK only" ;;
	ps5) TARGET="PS5: partner SDK only (not Catsdk-provided)" ;;
	esac
	sudo tee "$WRAP/${console}-gcc" > /dev/null << WRAP_EOF
#!/bin/bash
echo "Catsdk: ${LAB} stub (no public ${LAB} compiler on macOS)"
echo "  Target note: ${TARGET}"
echo "  Args:" "\$@"
echo "  This line is a Catsdk informational stub — not a real standalone compiler."
exit 1
WRAP_EOF
	sudo chmod +x "$WRAP/${console}-gcc"
	sudo ln -sf "$WRAP/${console}-gcc" "/usr/local/bin/${console}-gcc" \
		|| sudo cp -f "$WRAP/${console}-gcc" "/usr/local/bin/${console}-gcc"
done

sudo ln -sf "$WRAP/dreamcast-gcc" "/usr/local/bin/dc-gcc" 2>/dev/null \
	|| sudo cp -f "$WRAP/dreamcast-gcc" "/usr/local/bin/dc-gcc" 2>/dev/null || true

sudo tee "/usr/local/bin/catsdk-cc65-help" >/dev/null << 'CC_EOF'
#!/bin/bash
echo "Catsdk: For Atari/NES-style 6502 homebrew install cc65 (brew install cc65) or use:"
echo "  ca65/cl65 from cc65 docs — not bundled as *-gcc here."
exit 1
CC_EOF
sudo chmod +x "/usr/local/bin/catsdk-cc65-help"

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
echo "  catsdk-gba main.c pong   (needs devkitARM on PATH after toolchain install)"
echo "  ps1-gcc … ps5-gcc       — PlayStation informational stubs only (exit 1)"
echo "  nes-gcc / atari2600-gcc — other stubs (exit 1)"
echo "  catsdk-cc65-help       — cc65 pointer for Atari/NES-era 6502"
echo ""
echo "Meow."
