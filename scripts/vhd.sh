#!/bin/bash

set -e
trap 'echo "Error at line $LINENO"; exit 1' ERR

MOUNT_POINT="/tmp/mlrt_mount"
LOG_FILE="mlrt.log"

function show_banner() {
	echo "███╗   ███╗██╗     ██████╗ ████████╗"
	echo "████╗ ████║██║     ██╔══██╗╚══██╔══╝"
	echo "██╔████╔██║██║     ██████╔╝   ██║   "
	echo "██║╚██╔╝██║██║     ██╔══██╗   ██║   "
	echo "██║ ╚═╝ ██║███████╗██║  ██║   ██║   "
	echo "╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   "
	echo
	echo "   VM/HDD Manager   "
	echo
}

cleanup() {
	echo "[*] Cleaning up..."
	sudo umount "$MOUNT_POINT" 2>/dev/null || true
	sudo losetup -D 2>/dev/null || true
	rmdir "$MOUNT_POINT" 2>/dev/null || true
}

trap cleanup EXIT

function create_vm() {
	local fs_type=$1
	local img_name=$2
	local size_mb=${3:-512}
	local keep_mounted=${4:-false}

	echo "[+] Creating ${size_mb}MB ${fs_type} image: $img_name"

	dd if=/dev/zero of="$img_name" bs=1M count=$size_mb status=none

	case $fs_type in
		ext4)
			mkfs.ext4 -F "$img_name"
			;;
		xfs)
			mkfs.xfs -f "$img_name"
			;;
		btrfs)
			mkfs.btrfs -f "$img_name"
			;;
		*)
			echo "[-] Unsupported filesystem: $fs_type"
			exit 1
			;;
	esac

	mkdir -p "$MOUNT_POINT"
	LOOP_DEV=$(sudo losetup --find --show "$img_name")
	sudo mount "$LOOP_DEV" "$MOUNT_POINT"

	echo "[+] Image mounted at $MOUNT_POINT"
	echo "[+] Loop device: $LOOP_DEV"
	echo "[+] Image file: $img_name"
	echo
	echo "You can now:"
	echo "  - Create files in $MOUNT_POINT"
	echo "  - Delete files to test recovery"
	echo "  - Run 'mlrt.sh recover $img_name' when ready"
	echo

	if [[ "$fs_type" == "ext4" && "$keep_mounted" == "true" ]]; then
		echo "[*] Keeping ext4 mounted for recovery..."
		echo "[*] Run './vhd.sh unmount' when done, or press Ctrl+C to cancel"
		read

		sudo umount "$MOUNT_POINT"
		sudo losetup -d "$LOOP_DEV"
		rmdir "$MOUNT_POINT"

		echo "[+] Image saved as: $img_name"
	else
		echo "Press Enter when done (filesystem will be unmounted)..."
		read

		sudo umount "$MOUNT_POINT"
		sudo losetup -d "$LOOP_DEV"
		rmdir "$MOUNT_POINT"

		echo "[+] Image saved as: $img_name"
		echo "[+] Run './mlrt.sh recover $img_name' to recover deleted files"
	fi
}

function mount_vm() {
	local img_name=$1

	if [[ ! -f "$img_name" ]]; then
		echo "[-] Image not found: $img_name"
		exit 1
	fi

	mkdir -p "$MOUNT_POINT"
	LOOP_DEV=$(sudo losetup --find --show "$img_name")
	sudo mount "$LOOP_DEV" "$MOUNT_POINT"

	echo "[+] Mounted $img_name at $MOUNT_POINT"
	echo "[+] Press Enter when done..."
	read

	sudo umount "$MOUNT_POINT"
	sudo losetup -d "$LOOP_DEV"
	rmdir "$MOUNT_POINT"
	echo "[+] Unmounted"
}

function delete_vm() {
	local img_name=$1

	if [[ ! -f "$img_name" ]]; then
		echo "[-] Image not found: $img_name"
		exit 1
	fi

	rm -f "$img_name"
	echo "[+] Deleted: $img_name"
}

function list_vms() {
	echo "=== Available VM Images ==="
	ls -lh *.img 2>/dev/null || echo "No .img files found"
}

function show_help() {
	echo "Usage: $0 <command> [options]"
	echo
	echo "Commands:"
	echo "  create <ext4|xfs|btrfs> [name] [size_mb] [keep_mounted]  - Create a new VM image"
	echo "                                                      (keep_mounted: 'true' for ext4 to keep mounted)"
	echo "  mount <name>                        - Mount an existing image"
	echo "  unmount                             - Unmount current image"
	echo "  delete <name>                       - Delete a VM image"
	echo "  list                                - List available images"
	echo "  help                                - Show this help"
	echo
	echo "Examples:"
	echo "  $0 create ext4 test.img 512"
	echo "  $0 create ext4 test.img 512 true   # keep mounted for inode recovery"
	echo "  $0 create xfs xfs_test.img 256"
	echo "  $0 create btrfs btrfs_test.img 256"
	echo "  $0 mount test.img"
	echo "  $0 unmount"
	echo "  $0 delete test.img"
}

case "$1" in
	create)
		fs="${2:-ext4}"
		name="${3:-test.img}"
		size="${4:-512}"
		keep="${5:-false}"
		create_vm "$fs" "$name" "$size" "$keep"
		;;
	mount)
		mount_vm "$2"
		;;
	unmount)
		sudo umount "$MOUNT_POINT" 2>/dev/null || echo "Nothing mounted"
		sudo losetup -D 2>/dev/null || true
		rmdir "$MOUNT_POINT" 2>/dev/null || true
		echo "[+] Unmounted"
		;;
	delete)
		delete_vm "$2"
		;;
	list)
		list_vms
		;;
	help|--help|-h)
		show_help
		;;
	*)
		show_banner
		show_help
		;;
esac
