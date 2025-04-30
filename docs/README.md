#   EXT4 File System Recovery Project

##   Overview

This project demonstrates the fundamental principles of file recovery on EXT4 file systems using Bash scripting and The Sleuth Kit (TSK) tools. It automates the process of creating a virtual disk image, populating it with a set of diverse files, simulating file deletion, and subsequently attempting to recover those deleted files. This project aims to provide a practical, hands-on understanding of digital forensics concepts.

##   Key Components

The project comprises the following core scripts:

* `populate_vd.sh`: This script automates the creation and population of a virtual disk image (`test_ext4.img`). It formats the disk with the EXT4 file system and copies a variety of files into it, including text files, an executable, an image, and a nested directory with a secret text file.
* `dummy_deletion.sh`: This script simulates the deletion of a subset of the files created by `populate_vd.sh`. This mimics a scenario where files are accidentally or intentionally deleted from a file system, creating a recovery challenge.
* `recover.sh`: This is the main recovery script. It employs TSK tools, specifically `fls` to identify deleted inodes and `icat` to attempt to recover file content. Additionally, it demonstrates a basic file carving technique by searching for a unique string within the disk image.

##   Purpose

The primary purpose of this project is to illustrate file recovery techniques on the EXT4 file system in a simplified yet practical manner. It draws inspiration from academic research in digital forensics, particularly the methodologies discussed in the paper "Ext4 and XFS File System Forensic Framework Based on TSK" by Kim et al.

##   Limitations

It is important to acknowledge the limitations of the current implementation:

* The `recover.sh` script primarily focuses on inode-based recovery using `fls` and `icat`, and demonstrates a rudimentary pattern carving method.
* It does *not* incorporate journal-based recovery techniques, which the research paper emphasizes as a crucial aspect of modern EXT4 file system forensics. Journaling provides additional metadata that can significantly enhance the success rate of file recovery.
* The project is currently limited to EXT4 file systems and does not include support for other file systems like XFS, which is also discussed in the research paper.
* Recovery success can vary depending on factors such as file fragmentation, disk activity after deletion, and the specific deletion method used.

##   Future Work

Future development of this project could include:

* Implementing journal-based recovery to improve the robustness and effectiveness of file recovery, aligning more closely with the techniques advocated in the research paper.
* Extending the project to support the recovery of files from other file systems, most notably XFS, to broaden its scope and practical applicability.
* Enhancing error handling and logging mechanisms to provide more informative feedback during the recovery process.
* Developing a more sophisticated file carving capability to recover files based on file headers and footers, rather than relying on a single unique string.
