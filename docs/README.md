# Modern Linux Recovery Tool (MLRT)

**MLRT (Modern Linux Recovery Tool)** is a terminal-based, Bash-scripted file recovery utility designed for modern Linux file systems like `ext4` and `xfs`. Developed as part of a B.Tech academic project, this tool demonstrates basic file recovery through deleted inode extraction, journaling, and raw data carving techniques. It leverages core utilities from **The Sleuth Kit (TSK)** and native Linux tools.

---

## Features

- **Terminal UI** with ASCII art banner
- **EXT4 File Recovery** using:
  - Sleuth Kit tools: `fls`, `icat`, `istat`
  - Signature-based carving with `grep` and `dd`
- **XFS Basic File Carving**
- **Log Viewer** for recovery operations
- **Safe Cleanup & Mounting Automation**
- **Bash-only implementation**

---

## Requirements

- **Linux system**
- `bash`
- `sudo` privileges
- `sleuthkit` tools (`fls`, `icat`, `istat`)
- `losetup`, `mkfs.ext4`, `mkfs.xfs`, `dd`, `mount`, `umount`, etc.
- Optional: `less` for log viewing

---

## Setup & Execution

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/mlrt.git
   cd mlrt

2. Make the script executable:
chmod +x recover.sh

3. Run the script:
./recover.sh

Script Structure
Terminal Options

    EXT4 Recovery

        Creates and mounts a 2GB EXT4 image.

        Populates with test files.

        Deletes files to simulate recovery scenario.

        Uses fls, istat, icat for inode recovery.

        Carves known patterns (e.g., 123ABCxyz) from raw disk image.

    XFS Recovery

        Creates and mounts a 2GB XFS image.

        Populates & deletes sample files.

        Performs byte-pattern search and dd-based carving.

    View Logs

        Displays recovery_log.txt using less or cat.

    Exit

Directory Structure

    recover.sh – Main script

    recovered_output/ – Recovered files will be stored here

    recovery_log.txt – Logs of each recovery operation

    fls_output.txt – Inode list from EXT4

    recovered_carve_*.txt – Carved files

Use Cases

    Academic demonstration of recovery principles

    Basic Linux forensics

    Deleted file extraction for EXT4/XFS

    Carving data from raw disk dumps

Known Limitations

    Not suitable for production use

    Carving relies on known text patterns (can be adapted)

    Only simple data types recovered

    Limited support for complex XFS journaling recovery

License

    This project is open-source and intended for educational purposes only.

Credits

    Brian Carrier, The Sleuth Kit

    IJERT Research, Deleted Files and Metadata Recovery from XFS and EXT4 File Systems

    Simson Garfinkel, Digital Forensics Research

    *Smart India Hackathon 2024 Problem Statements

    Sabine Hossenfelder, Einstein Tile Video Inspiration

    Linux man pages & kernel.org documentation
