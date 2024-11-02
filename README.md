# Disk-Utils

This bash script provides a simple CLI for disk imaging, secure erasure and disk formatting. It uses the `dd` command to perform the utilities. Note that while there are multiple verification steps within the script, you should use this script with caution, for `dd` is nicknamed "disk destroyer" for a reason.

## Features

- **Disk Imaging**: Create an image of a specified disk. You should never image a disk that is in use (such as where your OS is running from).
- **Secure Erasure**: Overwrite a disk with random data to securely erase it.
- **Disk Formatting**: Format a disk to a specified file system.

## Usage

1. Clone the repository

```bash
git clone https://github.com/Kairos-T/Disk-Utils
```

2. Navigate to the directory

```bash
cd Disk-Utils
```

3. Make the script executable

```bash
chmod +x DiskUtils.sh
```

4. Run the script with root privileges

```bash
sudo ./DiskUtils.sh
```
