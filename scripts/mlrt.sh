#!/bin/bash

set -e
trap 'echo "Error at line $LINENO"; exit 1' ERR

LOG_FILE="mlrt.log"
OUT_DIR="recovered"
PATTERNS_FILE="patterns.cfg"

mkdir -p "$OUT_DIR"

function show_banner() {
	echo "███╗   ███╗██╗     ██████╗ ████████╗"
	echo "████╗ ████║██║     ██╔══██╗╚══██╔══╝"
	echo "██╔████╔██║██║     ██████╔╝   ██║   "
	echo "██║╚██╔╝██║██║     ██╔══██╗   ██║   "
	echo "██║ ╚═╝ ██║███████╗██║  ██║   ██║   "
	echo "╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   "
	echo
	echo "  Linux Recovery Tool "
	echo
}

function load_patterns() {
	declare -gA PATTERNS

	if [[ ! -f "$PATTERNS_FILE" ]]; then
		echo "INTERSTELLAR:123ABCxyz" > "$PATTERNS_FILE"
	fi

	while IFS=':' read -r name expr; do
		[[ -z "$name" || -z "$expr" ]] && continue
		PATTERNS[$name]="$expr"
	done < "$PATTERNS_FILE"
}

function recover_ext4() {
	local img=$1

	echo "[+] Recovering EXT4: $img" | tee -a "$LOG_FILE"

	load_patterns

	echo "[+] Finding deleted inodes..." | tee -a "$LOG_FILE"
	fls -rd "$img" > fls_output.txt 2>/dev/null || true

	local recovered=0
	while read -r line; do
		inode=$(echo "$line" | awk -F '[ *:]+' '{print $3}')
		if [[ "$inode" =~ ^[0-9]+$ ]]; then
			echo "    Checking inode $inode..." | tee -a "$LOG_FILE"
			if istat "$img" "$inode" 2>/dev/null | grep -qi "deleted"; then
				echo "    → Recovering inode $inode" | tee -a "$LOG_FILE"
				if icat "$img" "$inode" > "$OUT_DIR/inode_$inode.dat" 2>/dev/null; then
					size=$(stat -c%s "$OUT_DIR/inode_$inode.dat" 2>/dev/null || echo 0)
					if [[ "$size" -gt 0 ]]; then
						echo "    → Saved ($size bytes)" | tee -a "$LOG_FILE"
						((recovered++))
					fi
				fi
			fi
		fi
	done < fls_output.txt

	echo "[+] Recovered $recovered files via inodes" | tee -a "$LOG_FILE"

	echo "[+] General text carving (searching for strings)..." | tee -a "$LOG_FILE"
	strings -n 8 "$img" | sort -u | head -100 | while read -r line; do
		escaped=$(printf '%s' "$line" | sed 's/[[\.*^$/&\\&]/\\&/g')
		offset=$(grep -aEbo "$escaped" "$img" 2>/dev/null | head -1 | cut -d: -f1)
		if [[ -n "$offset" && "$offset" =~ ^[0-9]+$ ]]; then
			len=${#line}
			dd if="$img" of="$OUT_DIR/text_${offset}.dat" bs=1 skip=$offset count=$len status=none 2>/dev/null
			echo "    → Carved: ${line:0:50}..." | tee -a "$LOG_FILE"
		fi
	done

	echo "[+] Pattern-based carving..." | tee -a "$LOG_FILE"
	for key in "${!PATTERNS[@]}"; do
		expr="${PATTERNS[$key]}"
		echo "    Searching: $key" | tee -a "$LOG_FILE"
		grep -aEabo "$expr" "$img" 2>/dev/null | cut -d: -f1 | while read -r offset; do
			dd if="$img" of="$OUT_DIR/carve_${key}_${offset}.bin" bs=1 skip=$offset count=512 status=none 2>/dev/null
			echo "    → Carved at offset $offset" | tee -a "$LOG_FILE"
		done
	done

	echo "[+] Parsing journal..." | tee -a "$LOG_FILE"
	debugfs "$img" -R "logdump" 2>/dev/null > ext4_journal.txt || echo "    (no journal data)" | tee -a "$LOG_FILE"

	echo "[+] EXT4 recovery complete" | tee -a "$LOG_FILE"
}

function recover_xfs() {
	local img=$1

	echo "[+] Recovering XFS: $img" | tee -a "$LOG_FILE"

	load_patterns

	echo "[+] General text carving..." | tee -a "$LOG_FILE"
	strings -n 8 "$img" | sort -u | head -100 | while read -r line; do
		escaped=$(printf '%s' "$line" | sed 's/[[\.*^$/&\\&]/\\&/g')
		offset=$(grep -aEbo "$escaped" "$img" 2>/dev/null | head -1 | cut -d: -f1)
		if [[ -n "$offset" && "$offset" =~ ^[0-9]+$ ]]; then
			len=${#line}
			dd if="$img" of="$OUT_DIR/xfs_text_${offset}.dat" bs=1 skip=$offset count=$len status=none 2>/dev/null
			echo "    → Carved: ${line:0:50}..." | tee -a "$LOG_FILE"
		fi
	done

	echo "[+] Pattern-based carving..." | tee -a "$LOG_FILE"
	for key in "${!PATTERNS[@]}"; do
		expr="${PATTERNS[$key]}"
		echo "    Searching: $key" | tee -a "$LOG_FILE"
		grep -aEabo "$expr" "$img" 2>/dev/null | cut -d: -f1 | while read -r offset; do
			dd if="$img" of="$OUT_DIR/xfs_carve_${key}_${offset}.bin" bs=1 skip=$offset count=512 status=none 2>/dev/null
			echo "    → Carved at offset $offset" | tee -a "$LOG_FILE"
		done
	done

	echo "[+] XFS recovery complete" | tee -a "$LOG_FILE"
}

function recover_btrfs() {
	local img=$1

	echo "[+] Recovering BTRFS: $img" | tee -a "$LOG_FILE"
	echo "    Note: BTRFS has limited TSK support, using carving only" | tee -a "$LOG_FILE"

	load_patterns

	echo "[+] General text carving..." | tee -a "$LOG_FILE"
	strings -n 8 "$img" | sort -u | head -100 | while read -r line; do
		escaped=$(printf '%s' "$line" | sed 's/[[\.*^$/&\\&]/\\&/g')
		offset=$(grep -aEbo "$escaped" "$img" 2>/dev/null | head -1 | cut -d: -f1)
		if [[ -n "$offset" && "$offset" =~ ^[0-9]+$ ]]; then
			len=${#line}
			dd if="$img" of="$OUT_DIR/btrfs_text_${offset}.dat" bs=1 skip=$offset count=$len status=none 2>/dev/null
			echo "    → Carved: ${line:0:50}..." | tee -a "$LOG_FILE"
		fi
	done

	echo "[+] Pattern-based carving..." | tee -a "$LOG_FILE"
	for key in "${!PATTERNS[@]}"; do
		expr="${PATTERNS[$key]}"
		echo "    Searching: $key" | tee -a "$LOG_FILE"
		grep -aEabo "$expr" "$img" 2>/dev/null | cut -d: -f1 | while read -r offset; do
			dd if="$img" of="$OUT_DIR/btrfs_carve_${key}_${offset}.bin" bs=1 skip=$offset count=512 status=none 2>/dev/null
			echo "    → Carved at offset $offset" | tee -a "$LOG_FILE"
		done
	done

	echo "[+] BTRFS recovery complete" | tee -a "$LOG_FILE"
}

function detect_fs() {
	local img=$1
	if file "$img" | grep -qi "ext4"; then
		echo "ext4"
	elif file "$img" | grep -qi "xfs"; then
		echo "xfs"
	elif file "$img" | grep -qi "btrfs"; then
		echo "btrfs"
	else
		echo "unknown"
	fi
}

function show_help() {
	echo "Usage: $0 <command> [options]"
	echo
	echo "Commands:"
	echo "  recover <image>    - Recover deleted files from image"
	echo "  list               - List recovered files"
	echo "  help               - Show this help"
	echo
	echo "Examples:"
	echo "  $0 recover test.img"
	echo "  $0 list"
}

case "$1" in
	recover)
		img="$2"
		if [[ -z "$img" || ! -f "$img" ]]; then
			echo "[-] Image not found: $img"
			exit 1
		fi
		show_banner
		fs=$(detect_fs "$img")
		case "$fs" in
			ext4) recover_ext4 "$img" ;;
			xfs) recover_xfs "$img" ;;
			btrfs) recover_btrfs "$img" ;;
			*)
				echo "[-] Unknown filesystem"
				exit 1
				;;
		esac
		echo
		echo "=== Recovered files in ./$OUT_DIR/ ==="
		ls -la "$OUT_DIR"
		;;
	list)
		echo "=== Recovered files ==="
		ls -la "$OUT_DIR"
		;;
	help|--help|-h)
		show_help
		;;
	*)
		show_banner
		show_help
		;;
esac
