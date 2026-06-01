# How It Works: MLRT File Recovery Process

This document explains the file recovery process in MLRT, which uses a two-script approach: `vhd.sh` for VM/image management and `mlrt.sh` for recovery.

---

## Overview

<<<<<<< HEAD
MLRT uses four recovery techniques (in order of attempt):

1. **Metadata Inode Recovery** - Uses TSK tools to find and recover deleted file metadata
2. **Journal-Based Recovery** - Parses Ext4 journal (checksum V3 aware) to recover deleted inodes backed up in transactions
3. **General Text Carving** - Automatically finds and recovers any text strings
4. **Pattern-based Carving** - Searches for custom patterns from `patterns.cfg`
=======
MLRT uses three recovery techniques (in order of attempt):

1. **Inode Recovery** - Uses TSK tools to find and recover deleted file metadata
2. **General Text Carving** - Automatically finds and recovers any text strings
3. **Pattern-based Carving** - Searches for custom patterns from `patterns.cfg`
>>>>>>>

---

## 1. VM Creation (`vhd.sh create`)

The `vhd.sh` script creates a virtual disk image for testing recovery:

```bash
./vhd.sh create ext4 test.img 512 true
```

**Process:**
1. **Image Creation**: Uses `dd` to create a raw disk image filled with zeros
2. **Formatting**: Creates filesystem (ext4/xfs/btrfs) using appropriate `mkfs` tool
3. **Mounting**: Uses `losetup` to create loop device, then `mount` to attach
4. **User Interaction**: You can create/delete files manually in the mount point
5. **Cleanup**: Unmounts and detaches loop device (or keeps mounted if `true` is passed for ext4)

**Mount Point**: `/tmp/mlrt_mount`

---

## 2. File Recovery (`mlrt.sh recover`)

The `mlrt.sh` script performs recovery on the disk image:

### For ext4:

<<<<<<< HEAD
1. **Metadata Inode Recovery**:
=======
1. **Inode Recovery**:
>>>>>>>
   - Uses `fls -rd` to list deleted inodes
   - Uses `istat` to verify inode is deleted
   - Uses `icat` to extract file content from inode

<<<<<<< HEAD
2. **Journal-Based Recovery (Checksum V3 Aware)**:
   - Parses journal superblock (inode 8) to detect magic `0xC03B3998`
   - Reads `s_feature_incompat` flag to determine descriptor format (V2 vs V3)
   - Dumps full journal with `debugfs logdump -a`
   - Extracts deleted inode metadata backed up in journal transactions
   - When multiple backups exist, selects most recent via `a_time` comparison
   - Recovers inodes from journal data blocks

3. **General Text Carving**:
=======
2. **General Text Carving**:
>>>>>>> 
   - Uses `strings` to extract all readable strings from image
   - Searches for each string using `grep -aEbo`
   - Uses `dd` to carve the data at found offsets

<<<<<<< HEAD
4. **Pattern-based Carving**:
=======
3. **Pattern-based Carving**:
>>>>>>>
   - Loads patterns from `patterns.cfg`
   - Searches for each pattern in the raw image
   - Carves data blocks at found offsets

<<<<<<< HEAD
=======
4. **Journal Parsing**:
   - Uses `debugfs` to dump ext4 journal
   - Extracts block numbers for further analysis

>>>>>>>
### For xfs/btrfs:

Since TSK has limited support for xfs and btrfs:
- Only performs general text carving
- Only performs pattern-based carving
- No inode-level recovery

---

## 3. Output

Recovered files are stored in `./recovered/` directory:
<<<<<<< HEAD
- `inode_*.dat` - Files recovered via metadata inode extraction
- `journal_recovered_inode_*.dat` - Files recovered from journal data blocks
- `journal_version.txt` - Detected journal checksum version (CSUM_V2/CSUM_V3)
- `journal_full.txt` - Full debugfs journal dump
=======
- `inode_*.dat` - Files recovered via inode extraction
>>>>>>>
- `text_*.dat` - Files carved via general text search
- `carve_*.bin` - Files carved via pattern matching

---

## Why Inode Recovery May Fail

1. **Inode Reuse**: After deletion, ext4 may reuse the inode for new files
2. **Block Reuse**: Data blocks may be overwritten
3. **Unmount Triggers Cleanup**: Unmounting the filesystem triggers inode reclamation
4. **Filesystem Activity**: Any write operation may overwrite deleted data

**Tip**: For reliable inode recovery on ext4, keep the image mounted:
```bash
./vhd.sh create ext4 test.img 512 true
# Run recovery while mounted
./mlrt.sh recover test.img
./vhd.sh unmount
```

---

## Recovery Techniques Explained

### Inode Recovery
The inode contains metadata about a file (size, permissions, timestamps) and pointers to data blocks. When a file is deleted, the inode is marked as free but data blocks may persist until overwritten.

### Data Carving
Carving ignores filesystem metadata and searches directly for known file signatures or patterns in raw disk data. This works even when filesystem structures are corrupted.

### General Text Carving
MLRT extracts all strings from the image and searches for each one, recovering any text data that still exists on disk regardless of file boundaries.
