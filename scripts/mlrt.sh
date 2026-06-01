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

<<<<<<< HEAD
function check_tsk_tools() {
	local missing=0
	for tool in fls istat icat; do
		if ! command -v "$tool" &>/dev/null; then
			echo "    [-] TSK tool '$tool' not found (install: sudo apt install sleuthkit)" | tee -a "$LOG_FILE"
			missing=1
		fi
	done
	return $missing
}

function parse_ext4_journal_superblock() {
	local img=$1
	local journal_inode=8

	echo "[+] Parsing Ext4 journal superblock (inode $journal_inode)..." | tee -a "$LOG_FILE"

	local jsb_offset
	jsb_offset=$(debugfs "$img" -R "stat <$journal_inode>" 2>/dev/null | grep -oP '\(0-\d+?\):\K\d+' | head -1)

	if [[ -z "$jsb_offset" ]]; then
		echo "    [-] Could not locate journal inode data blocks" | tee -a "$LOG_FILE"
		return 1
	fi

	echo "    [i] Journal data starts at block $jsb_offset" | tee -a "$LOG_FILE"

	local block_size
	block_size=$(debugfs "$img" -R "stats" 2>/dev/null | grep "Block size:" | awk '{print $3}')
	block_size=${block_size:-4096}

	local magic
	magic=$(dd if="$img" bs="$block_size" skip="$jsb_offset" count=1 status=none 2>/dev/null | xxd -s 0 -l 4 -p)
	echo "    Magic: 0x${magic^^}" | tee -a "$LOG_FILE"

	if [[ "${magic,,}" != "c03b3998" ]]; then
		echo "    [-] Invalid journal superblock magic" | tee -a "$LOG_FILE"
		return 1
	fi

	local s_feature_incompat
	s_feature_incompat=$(dd if="$img" bs="$block_size" skip="$jsb_offset" count=1 status=none 2>/dev/null | xxd -s 40 -l 4 -p | sed 's/^0*//')
	s_feature_incompat=${s_feature_incompat:-0}
	echo "    s_feature_incompat: 0x${s_feature_incompat}" | tee -a "$LOG_FILE"

	local csum_v3_flag=$(( 16#${s_feature_incompat} & 0x10 ))
	if [[ "$csum_v3_flag" -eq 16 ]]; then
		echo "    [!] Journal Checksum V3 detected (CSUM_V3)" | tee -a "$LOG_FILE"
		echo "CSUM_V3" > "$OUT_DIR/journal_version.txt"
	else
		echo "    [i] Journal Checksum V2 or earlier (flag: 0x${s_feature_incompat})" | tee -a "$LOG_FILE"
		echo "CSUM_V2" > "$OUT_DIR/journal_version.txt"
	fi

	dd if="$img" bs="$block_size" skip="$jsb_offset" count=1 status=none 2>/dev/null | xxd > "$OUT_DIR/journal_superblock.hex" 2>/dev/null

	return 0
}

function recover_ext4_journal() {
	local img=$1

	echo "[+] Starting Ext4 journal-based deleted file recovery..." | tee -a "$LOG_FILE"

	parse_ext4_journal_superblock "$img" || return 1

	local journal_version
	journal_version=$(cat "$OUT_DIR/journal_version.txt" 2>/dev/null || echo "UNKNOWN")
	echo "[+] Using journal descriptor format: $journal_version" | tee -a "$LOG_FILE"

	echo "[+] Dumping journal with debugfs..." | tee -a "$LOG_FILE"
	debugfs "$img" -R "logdump -a" 2>/dev/null > "$OUT_DIR/journal_full.txt" || true

	if [[ ! -s "$OUT_DIR/journal_full.txt" ]]; then
		echo "    [-] No journal entries found (journal may be clean after unmount)" | tee -a "$LOG_FILE"
		echo "    [i] Tip: For journal recovery, run before unmounting: ./mlrt.sh recover <image>" | tee -a "$LOG_FILE"
		return 1
	fi

	local journal_lines
	journal_lines=$(wc -l < "$OUT_DIR/journal_full.txt")
	echo "    [i] Journal dump: $journal_lines lines" | tee -a "$LOG_FILE"

	echo "[+] Extracting transaction descriptors and data blocks..." | tee -a "$LOG_FILE"

	local current_transaction=""
	local journal_found=0
	local journal_recovered=0
	local deleted_inodes=()

	while IFS= read -r line; do
		if echo "$line" | grep -qiE "^Journal starts|^[[:space:]]*Transaction"; then
			current_transaction=$(echo "$line" | awk '{print $NF}')
			echo "    [i] Processing transaction $current_transaction" | tee -a "$LOG_FILE"
		fi

		if echo "$line" | grep -qiE "Inode.*deleted|d_time|Deleted|dtime"; then
			local inode_num
			inode_num=$(echo "$line" | grep -oE 'Inode [0-9]+' | awk '{print $2}')
			local atime
			atime=$(echo "$line" | grep -oE '[acm]time[=: ]+[0-9]+' | grep -oE '[0-9]+$' || echo "0")

			if [[ -n "$inode_num" && "$inode_num" =~ ^[0-9]+$ && "$inode_num" != "8" ]]; then
				if [[ " ${deleted_inodes[*]} " =~ " ${inode_num} " ]]; then
					continue
				fi
				deleted_inodes+=("$inode_num")
				echo "    [!] Found deleted inode $inode_num in journal (a_time=$atime)" | tee -a "$LOG_FILE"

				if command -v icat &>/dev/null; then
					if icat "$img" "$inode_num" > "$OUT_DIR/journal_recovered_inode_$inode_num.dat" 2>/dev/null; then
						local jsize
						jsize=$(stat -c%s "$OUT_DIR/journal_recovered_inode_$inode_num.dat" 2>/dev/null || echo 0)
						if [[ "$jsize" -gt 0 ]]; then
							echo "    [✓] Recovered inode $inode_num from journal ($jsize bytes)" | tee -a "$LOG_FILE"
							((journal_recovered++))
						else
							echo "    [-] Inode $inode_num recovered but empty" | tee -a "$LOG_FILE"
							rm -f "$OUT_DIR/journal_recovered_inode_$inode_num.dat"
						fi
					else
						echo "    [-] Failed to recover inode $inode_num from journal" | tee -a "$LOG_FILE"
					fi
				else
					echo "    [i] TSK 'icat' not available — logging inode $inode_num for manual recovery" | tee -a "$LOG_FILE"
					echo "inode:$inode_num:atime:$atime:txn:$current_transaction" >> "$OUT_DIR/journal_deleted_inodes.csv"
				fi
				((journal_found++))
			fi
		fi
	done < "$OUT_DIR/journal_full.txt"

	if ! command -v icat &>/dev/null && [[ $journal_found -gt 0 ]]; then
		echo "    [i] To recover listed inodes: sudo apt install sleuthkit && icat <image> <inode>" | tee -a "$LOG_FILE"
	fi

	echo "[+] Journal recovery complete: found $journal_found deleted inodes, recovered $journal_recovered" | tee -a "$LOG_FILE"
}

=======
>>>>>>>
function recover_ext4() {
	local img=$1

	echo "[+] Recovering EXT4: $img" | tee -a "$LOG_FILE"

	load_patterns

<<<<<<< HEAD
	echo "[+] Phase 1: Finding deleted inodes via metadata..." | tee -a "$LOG_FILE"
=======
	echo "[+] Finding deleted inodes..." | tee -a "$LOG_FILE"
>>>>>>>
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

<<<<<<< HEAD
	echo "[+] Recovered $recovered files via metadata inodes" | tee -a "$LOG_FILE"

	echo "[+] Phase 2: Journal-based recovery (checksum v3 aware)..." | tee -a "$LOG_FILE"
	recover_ext4_journal "$img"

	echo "[+] Phase 3: General text carving..." | tee -a "$LOG_FILE"
=======
	echo "[+] Recovered $recovered files via inodes" | tee -a "$LOG_FILE"

	echo "[+] General text carving (searching for strings)..." | tee -a "$LOG_FILE"
>>>>>>>
	strings -n 8 "$img" | sort -u | head -100 | while read -r line; do
		escaped=$(printf '%s' "$line" | sed 's/[[\.*^$/&\\&]/\\&/g')
		offset=$(grep -aEbo "$escaped" "$img" 2>/dev/null | head -1 | cut -d: -f1)
		if [[ -n "$offset" && "$offset" =~ ^[0-9]+$ ]]; then
			len=${#line}
			dd if="$img" of="$OUT_DIR/text_${offset}.dat" bs=1 skip=$offset count=$len status=none 2>/dev/null
			echo "    → Carved: ${line:0:50}..." | tee -a "$LOG_FILE"
		fi
	done

<<<<<<< HEAD
	echo "[+] Phase 4: Pattern-based carving..." | tee -a "$LOG_FILE"
=======
	echo "[+] Pattern-based carving..." | tee -a "$LOG_FILE"
>>>>>>>
	for key in "${!PATTERNS[@]}"; do
		expr="${PATTERNS[$key]}"
		echo "    Searching: $key" | tee -a "$LOG_FILE"
		grep -aEabo "$expr" "$img" 2>/dev/null | cut -d: -f1 | while read -r offset; do
			dd if="$img" of="$OUT_DIR/carve_${key}_${offset}.bin" bs=1 skip=$offset count=512 status=none 2>/dev/null
			echo "    → Carved at offset $offset" | tee -a "$LOG_FILE"
		done
	done

<<<<<<< HEAD
=======
	echo "[+] Parsing journal..." | tee -a "$LOG_FILE"
	debugfs "$img" -R "logdump" 2>/dev/null > ext4_journal.txt || echo "    (no journal data)" | tee -a "$LOG_FILE"

>>>>>>>
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
