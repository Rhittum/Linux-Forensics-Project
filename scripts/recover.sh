#!/bin/bash

set -e
trap 'echo "Error occurred at line $LINENO. Exiting..."; exit 1' ERR

BLOCK_SIZE=512
LOG_FILE="recovery_log.txt"
OUT_DIR="recovered_output"
MNT="/mnt/recovery"
IMG_EXT4="test_ext4.img"
IMG_XFS="test_xfs.img"
PATTERN_FILE="patterns.cfg"
PATTERN_DIR="patterns_out"

mkdir -p "$PATTERN_DIR"

function show_banner() {
	echo "███╗   ███╗██╗     ██████╗ ████████╗"
	echo "████╗ ████║██║     ██╔══██╗╚══██╔══╝"
	echo "██╔████╔██║██║     ██████╔╝   ██║   "
	echo "██║╚██╔╝██║██║     ██╔══██╗   ██║   "
	echo "██║ ╚═╝ ██║███████╗██║  ██║   ██║   "
	echo "╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   "
	echo
}

pause_and_return() {
  read -p "Press Enter to return to menu..."
}

function show_help() {
  echo "==================== HELP ===================="
  echo "Tool: Ext4 & XFS File Recovery Utility"
  echo "Author: Vaibhav, Vanshveer & Rhittum(Melan)"
  echo "Options: Recover deleted files, carve by pattern,"
  echo "         extract metadata, and parse ext4 journals."
  echo "=============================================="
}

function setup_environment() {
  sudo umount $MNT 2>/dev/null || true
  sudo losetup -D || true
  rm -rf $MNT $OUT_DIR recovered_carve_*.txt fls_output.txt ext4_journal_dump.txt $LOG_FILE
  mkdir -p $MNT $OUT_DIR
}

function create_ext4_image() {
  echo "[+] Creating and populating EXT4 image..." | tee -a $LOG_FILE
  dd if=/dev/zero of=$IMG_EXT4 bs=1M count=2048
  mkfs.ext4 $IMG_EXT4
  LOOP_DEV=$(sudo losetup --find --show $IMG_EXT4)
  sudo mount $LOOP_DEV $MNT

  echo "Populating files..." | tee -a $LOG_FILE
  echo "This is a very *unique line* to be recovered later 123ABCxyz!" > $MNT/important.txt
  cp /bin/ls $MNT/ls_copy
  echo "Hidden message" > $MNT/secret.txt
  words=("alpha" "bravo" "charlie" "delta" "echo" "foxtrot" "golf" "hotel" "india" "juliet")
  for i in {1..100}; do
	  word=${words[$((i % ${#words[@]}))]}
		  echo "File $i contains the word: $word" > /mnt/test_ext4/file_$i.txt
	  done
  for i in {101..150}; do
    dd if=/dev/urandom of=$MNT/file_$i.bin bs=512 count=4 status=none
  done
  sync
  sleep 1

  echo "Deleting files..." | tee -a $LOG_FILE
  rm -rf $MNT/*
  sync
  sleep 1

  sudo umount $MNT
  sudo losetup -d $LOOP_DEV
}

function parse_ext4_journal() {
  echo "[+] Parsing EXT4 Journal..." | tee -a $LOG_FILE

  # Raw journal dump
  debugfs $IMG_EXT4 -R "logdump" > ext4_journal_dump.txt 2>/dev/null

  echo "[+] Extracting journal block numbers..." | tee -a $LOG_FILE
  grep -Eo "block [0-9]+" ext4_journal_dump.txt | awk '{print $2}' > journal_blocks.txt

  mkdir -p $OUT_DIR/journal_blocks

  while read -r blk; do
    if [[ "$blk" =~ ^[0-9]+$ ]]; then
      echo "Dumping journal block $blk" | tee -a $LOG_FILE
      dd if=$IMG_EXT4 of="$OUT_DIR/journal_blocks/block_$blk.bin" \
        bs=4096 skip=$blk count=1 status=none
    fi
  done < journal_blocks.txt

  echo "[+] Journal block extraction complete." | tee -a $LOG_FILE
}


function recover_ext4() {
  echo "[+] Recovering files using TSK tools (ext4)..." | tee -a $LOG_FILE
  fls -rd $IMG_EXT4 > fls_output.txt
  while read -r line; do
    inode=$(echo $line | awk -F '[ *:]+' '{print $3}')
    if [[ "$inode" =~ ^[0-9]+$ ]]; then
      echo "Recovering inode $inode..." | tee -a $LOG_FILE
      if istat $IMG_EXT4 $inode | grep -q "Deleted:"; then
        icat $IMG_EXT4 $inode > "$OUT_DIR/recovered_$inode.txt" 2>/dev/null && \
        echo "Recovered inode $inode" | tee -a $LOG_FILE
        istat $IMG_EXT4 $inode > "$OUT_DIR/metadata/inode_${inode}_meta.txt"
      fi
    fi
  done < fls_output.txt

  carve_by_patterns
  parse_ext4_journal

  # echo "[+] Generating SHA256 hashes of recovered files..." | tee -a $LOG_FILE
  # sha256sum $OUT_DIR/* > $OUT_DIR/file_hashes.txt

  echo "[+] Attempting journal parse (debugfs)..." | tee -a $LOG_FILE
  debugfs $IMG_EXT4 -R "logdump" > ext4_journal_dump.txt 2>/dev/null || echo "Journal empty." | tee -a $LOG_FILE

  echo "=== EXT4 Recovery Finished ===" | tee -a $LOG_FILE
  pause_and_return
}

function load_patterns() {
  declare -gA PATTERNS

  if [[ ! -f "$PATTERN_FILE" ]]; then
    echo "INTERSTELLAR:123ABCxyz" > $PATTERN_FILE
    echo "JPEG:\xFF\xD8\xFF" >> $PATTERN_FILE
  fi

  while IFS=':' read -r name expr; do
    [[ -z "$name" || -z "$expr" ]] && continue
    PATTERNS[$name]="$expr"
  done < $PATTERN_FILE
}

function carve_by_patterns() {
  echo "[+] Starting Pattern-Based Carving..." | tee -a $LOG_FILE
  load_patterns

  for key in "${!PATTERNS[@]}"; do
    expr="${PATTERNS[$key]}"
    echo "[*] Searching for pattern: $key ($expr)" | tee -a $LOG_FILE

    grep -aEabo "$expr" "$IMG_EXT4" | cut -d: -f1 | while read OFFSET; do
      OUT_FILE="$PATTERN_DIR/${key}_${OFFSET}.bin"
      dd if=$IMG_EXT4 of="$OUT_FILE" bs=1 skip=$OFFSET count=$BLOCK_SIZE status=none
      echo "    → Carved at offset $OFFSET → $OUT_FILE" | tee -a $LOG_FILE
    done
  done

  echo "[+] Pattern-based carving complete." | tee -a $LOG_FILE
}


function recover_xfs() {
	echo "=== Starting Basic XFS Recovery ===" | tee $LOG_FILE
	IMG="test_xfs.img"
	dd if=/dev/zero of=$IMG bs=1M count=2048
	mkfs.xfs -f $IMG
	mkdir -p /mnt/test_xfs
	LOOP_DEV=$(sudo losetup --find --show $IMG)
	sudo mount $LOOP_DEV /mnt/test_xfs

	echo "[+] Populating test XFS image..." | tee -a $LOG_FILE
	for i in {1..20}; do
		echo "XFS sample data line $i" > /mnt/test_xfs/xfs_file_$i.txt
	done
	sync
	rm -f /mnt/test_xfs/xfs_file_*.txt
	sync

	sudo umount /mnt/test_xfs
	sudo losetup -d $LOOP_DEV

	echo "[+] Performing carving from XFS image..." | tee -a $LOG_FILE
	grep -aEabo "XFS sample data" $IMG | cut -d: -f1 | while read OFFSET; do
	dd if=$IMG of=recovered_carve_xfs_$OFFSET.txt bs=1 skip=$OFFSET count=$BLOCK_SIZE
	echo "Carved xfs segment at offset $OFFSET" | tee -a $LOG_FILE
done

echo "=== XFS Recovery Done ===" | tee -a $LOG_FILE
pause_and_return
}

view_logs() {
  echo "=== Viewing Log File ==="
  if command -v less &> /dev/null; then
    less $LOG_FILE
  else
    cat $LOG_FILE
    pause_and_return
  fi
}

# ========== MAIN ==========
clear
show_banner
mkdir -p $OUT_DIR/metadata

function main_menu() {
	while true; do
		echo "Select File System for Recovery:"
		echo "1. EXT4"
		echo "2. XFS"
		echo "3. View Logs"
		echo "4. Help"
		echo "5. Exit"
		read -p "Choice: " CHOICE

		case $CHOICE in
			1)
				setup_environment
				create_ext4_image
				parse_ext4_journal
				;;
			2)
				setup_environment
				recover_xfs
				;;
			3)
				view_logs
				;;
			4)
				show_help
				;;
			*)
				echo "Exiting..."
				exit 0
				;;
		esac
	done
}
main_menu

echo "=== Recovery Completed ===" | tee -a $LOG_FILE

