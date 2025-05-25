#!/bin/bash

set -e
trap 'echo "Error occurred at line $LINENO. Exiting..."; exit 1' ERR

IMG="test_ext4.img"
MNT="/mnt/test_ext4"
OUT_DIR="recovered_output"
BLOCK_SIZE=512
LOG_FILE="recovery_log.txt"

echo "=== Starting File Recovery Script ===" | tee $LOG_FILE
echo "Cleaning up any old mounts or files..." | tee -a $LOG_FILE
sudo umount $MNT 2>/dev/null || true
sudo losetup -D || true
rm -rf $MNT $IMG $OUT_DIR recovered_carve_*.txt fls_output.txt

echo "[+] Creating image and formatting..." | tee -a $LOG_FILE
dd if=/dev/zero of=$IMG bs=1M count=2048
mkfs.ext4 $IMG
mkdir -p $MNT

echo "[+] Mounting image..." | tee -a $LOG_FILE
LOOP_DEV=$(sudo losetup --find --show $IMG)
sudo mount $LOOP_DEV $MNT
sleep 1

echo "[+] Populating image with test files..." | tee -a $LOG_FILE
echo "This is a very *unique line* to be recovered later 123ABCxyz!" > $MNT/important.txt
cp /bin/ls $MNT/ls_copy
cp /home/rhittum/wp1817964-interstellar-wallpapers.jpg $MNT
mkdir $MNT/folder1
echo "Hidden message" > $MNT/folder1/secret.txt
for i in {1..100}; do
	echo "This line $i with secret 123ABCxyz" > /mnt/test_ext4/file_$i.txt
done
echo "Creating bin files..."

for i in {101..150}; do
	dd if=/dev/urandom of=/mnt/test_ext4/file_$i.bin bs=512 count=4 status=none
done
sync
sleep 1

echo "[+] Deleting test files..." | tee -a $LOG_FILE
rm $MNT/important.txt $MNT/folder1/secret.txt
rm $MNT/wp1817964-interstellar-wallpapers.jpg
for i in {1..100}; do
	echo "deleting text files $i..."
	rm /mnt/test_ext4/file_$i.txt
	sync
	sleep 1
done

for i in {101..150}; do
	echo "deleting bin files $i..."
	rm /mnt/test_ext4/file_$i.bin
	sync
	sleep 1
done
sync
sleep 1

echo "[+] Unmounting and detaching image..." | tee -a $LOG_FILE
sudo umount $MNT
sudo losetup -d $LOOP_DEV

echo "[+] Running fls for deleted inodes..." | tee -a $LOG_FILE
fls -rd $IMG > fls_output.txt
cat fls_output.txt | tee -a $LOG_FILE

echo "[+] Attempting icat recovery for each inode..." | tee -a $LOG_FILE
mkdir -p $OUT_DIR
while read -r line; do
  echo "Current line: '$line'" | tee -a $LOG_FILE
  inode=$(echo $line | awk -F '[ *:]+''{print $3}')
  echo "Parsed inode: '$inode'" | tee -a $LOG_FILE
  if [[ "$inode" =~ ^[0-9]+$ ]]; then
    echo "Recovering inode $inode..." | tee -a $LOG_FILE
    if istat $IMG $inode | grep -q "Deleted:"; then
	    echo "[+] Deleted inode $inode found. Attempting Recovery..." | tee -a $LOG_FILE
	    if icat $IMG $inode > "$OUT_DIR/recovered_$inode.txt" 2>/dev/null; then
		    echo "Recovered inode $inode" | tee -a $LOG_FILE
	    fi
    else
	echo "[!] Inode $inode not marked deleted. Skipping..." | tee -a $LOG_FILE
    else
      echo "Failed to recover inode $inode" | tee -a $LOG_FILE
    fi
  fi
done < fls_output.txt

echo "[+] Searching for raw pattern and carving manually..." | tee -a $LOG_FILE
grep -iEabo "123ABCxyz|wp1817964-interstellar-wallpapers.jpg" $IMG | cut -d: -f1 | while read OFFSET; do
  if [ ! -z "$OFFSET" ]; then
    echo "Found pattern at byte offset $OFFSET" | tee -a $LOG_FILE
    dd if=$IMG of=recovered_carve_$OFFSET.txt bs=1 skip=$OFFSET count=$BLOCK_SIZE
    echo "Carved file saved as recovered_carve_$OFFSET.txt" | tee -a $LOG_FILE
  fi
done

echo "=== Recovery Finished ===" | tee -a $LOG_FILE
