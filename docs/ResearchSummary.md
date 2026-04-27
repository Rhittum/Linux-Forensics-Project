# Research Summary: File System Forensics and Recovery

This project is grounded in the principles of digital forensics, with a specific focus on the techniques used to recover deleted files from file systems. The core inspiration for this project comes from academic research in the field, particularly the challenges and advancements in file system forensics.

## Key Research Paper

The primary research paper that informs this project is:

* **"Ext4 and XFS File System Forensic Framework Based on TSK"** by Kim et al.

This paper provides a comprehensive analysis of the complexities involved in recovering files from modern file systems, specifically Ext4 and XFS. It highlights the limitations of traditional forensic tools, such as The Sleuth Kit (TSK), in dealing with the evolving structures of these file systems.

## Key Insights from the Paper

The paper emphasizes several critical points relevant to this project:

* **File System Evolution:** Modern file systems like Ext4 and XFS undergo frequent updates to improve performance, reliability, and security. These updates often involve changes to the file system's metadata structures, which can hinder the effectiveness of existing forensic tools.
* **Limitations of TSK:** While TSK is a widely used open-source forensic tool, it has limitations in handling the intricacies of modern file systems. For instance, it lacks native support for XFS and BTRFS and does not fully utilize the journal area in Ext4 for file recovery.
* **Importance of Metadata and Journaling:** The paper underscores the importance of accurately analyzing file system metadata and journal areas for effective file recovery. Metadata provides crucial information about file attributes and locations, while journaling maintains a log of file system changes, enabling the recovery of deleted or corrupted files.
* **Need for Specialized Tools:** The research highlights the need for specialized forensic tools and frameworks that can adapt to the specific characteristics of different file system versions. The paper proposes a TSK-based framework to address the challenges of Ext4 and XFS file recovery.

## Project Alignment with Research

Our project aligns with the research paper in the following ways:

* It utilizes TSK tools (`fls`, `icat`, `istat`) to perform file recovery, demonstrating the fundamental principles of metadata-based recovery.
* It includes journal parsing using `debugfs` for Ext4.
* It acknowledges the challenges of file recovery by simulating scenarios where deletion is performed, leaving room for more complex recovery.
* It adds general text carving as a fallback when inode recovery is unreliable.

## Project Divergence from Research

However, our project also diverges from the research paper in several key aspects:

* **Simplified Journal Implementation:** Our project performs basic journal dumps but does not implement full journal-based recovery reconstruction.
* **Limited XFS/BTRFS Scope:** Our project uses carving-only for XFS and BTRFS due to limited TSK support, rather than full metadata analysis.
* **Manual Workflow:** Unlike automated frameworks, we use a manual VM creation approach for educational purposes.

In conclusion, this project provides a valuable educational demonstration of file recovery principles using TSK and data carving. It is inspired by the challenges and solutions presented in current digital forensics research but represents a simplified implementation with clear limitations and potential for future expansion.
