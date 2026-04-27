# Modern Linux Recovery Tool (MLRT)

**MLRT (Modern Linux Recovery Tool)** is a terminal-based, Bash-scripted file recovery utility designed for modern Linux file systems like `ext4`, `xfs`, and `btrfs`. Developed as part of a B.Tech academic project, this tool demonstrates file recovery through deleted inode extraction and raw data carving techniques. It leverages core utilities from **The Sleuth Kit (TSK)** and native Linux tools.

---

## Features

- **Terminal UI** with ASCII art banner
- **Manual VM Creation** - Create and manage virtual disk images
- **EXT4 Recovery** using:
  - Sleuth Kit tools: `fls`, `icat`, `istat`
  - Inode-based recovery
  - Journal parsing with `debugfs`
- **XFS Basic File Carving**
- **BTRFS File Carving**
- **General Text Carving** - Automatically finds and recovers any text strings
- **Pattern-based Carving** - Search for custom patterns
- **Bash-only implementation**

---

## Requirements

- **Linux system**
- `bash`
- `sudo` privileges
- `sleuthkit` tools (`fls`, `icat`, `istat`, `debugfs`)
- `xfsprogs` (for XFS support)
- `btrfs-progs` (for BTRFS support)
- `losetup`, `mkfs.ext4`, `mkfs.xfs`, `mkfs.btrfs`, `dd`, `mount`, `umount`, etc.

---

## Quick Start

```bash
cd scripts
chmod +x vhd.sh mlrt.sh
```

### Create a VM and test recovery

```bash
# Create an ext4 image (keeps mounted for inode recovery)
./vhd.sh create ext4 test.img 512 true

# In another terminal, run recovery while mounted
./mlrt.sh recover test.img

# Unmount when done
./vhd.sh unmount
```

### Or use standard workflow

```bash
# Create and mount image
./vhd.sh create ext4 test.img

# (Manually create/delete files in /tmp/mlrt_mount)

# Press Enter to unmount, then recover
./mlrt.sh recover test.img

# View recovered files
./mlrt.sh list
```

---

## Commands

### vhd.sh - VM/Image Manager

| Command | Description |
|---------|-------------|
| `./vhd.sh create <fs> [name] [size] [keep]` | Create VM image (fs: ext4/xfs/btrfs) |
| `./vhd.sh mount <name>` | Mount existing image |
| `./vhd.sh unmount` | Unmount current image |
| `./vhd.sh delete <name>` | Delete image |
| `./vhd.sh list` | List available images |

### mlrt.sh - Recovery Tool

| Command | Description |
|---------|-------------|
| `./mlrt.sh recover <image>` | Recover deleted files |
| `./mlrt.sh list` | List recovered files |

---

## Supported Filesystems

- **ext4** - Full recovery (inode + journal + carving)
- **xfs** - Carving only (limited metadata access)
- **btrfs** - Carving only (limited TSK support)

---

## Directory Structure

```
scripts/
  vhd.sh          - VM/Image creation and management
  mlrt.sh         - Recovery tool
  patterns.cfg    - Custom patterns for carving

recovered/        - Recovered files output
mlrt.log          - Recovery log
```

---

## Custom Patterns

Edit `patterns.cfg` to add custom carving patterns:

```
INTERSTELLAR:123ABCxyz
RIN:Hi, my name is Rin!
JPEG:\xFF\xD8\xFF
```

Format: `NAME:pattern`

---

## Known Limitations

- Not suitable for production use
- Inode recovery requires image to remain mounted (ext4)
- BTRFS/XFS have limited metadata recovery support
- Carving works best with text-based data

---

## License

This project is open-source and intended for educational purposes only.

---

## Credits

- Brian Carrier, The Sleuth Kit
- IJERT Research, Deleted Files and Metadata Recovery from XFS and EXT4 File Systems
- Simson Garfinkel, Digital Forensics Research
- Linux man pages & kernel.org documentation