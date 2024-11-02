#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Define script version
VERSION="1.0"

# Script name for logging
SCRIPT_NAME=$(basename "$0")

# Log file location
LOG_FILE="/var/log/disk_management.log"

# Function to check required tools
check_requirements() {
    local required_tools=("dd" "mkfs.ext4" "mkfs.ntfs" "mkfs.fat" "mkfs.exfat" "lsblk")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        log "${YELLOW}Please install the missing tools and try again.${NC}"
        exit 1
    fi
}

# Enhanced logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "$timestamp - $message"
    echo "$timestamp - ${message//$'\033'[0-9;]*m/}" >> "$LOG_FILE"
}

# Display script banner
show_banner() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}    Disk Management Utility v${VERSION}    ${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}Running as user:${NC} $(whoami)"
    echo -e "${YELLOW}Date:${NC} $(date)"
    echo -e "${BLUE}====================================${NC}"
}

# Check for sudo permissions
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log "${RED}Please run this script as root!${NC}"
        exit 1
    fi
}

# Enhanced disk information display
display_disk_info() {
    local disk="$1"
    log "${YELLOW}Disk Information for $disk:${NC}"
    echo -e "${PURPLE}=== Basic Information ===${NC}"
    lsblk "$disk"
    echo -e "\n${PURPLE}=== Detailed Information ===${NC}"
    fdisk -l "$disk"
    echo -e "\n${PURPLE}=== SMART Status ===${NC}"
    if smartctl -H "$disk" &>/dev/null; then
        smartctl -H "$disk"
    else
        echo -e "${YELLOW}SMART data not available for this disk${NC}"
    fi
}

# Calculate SHA256 hash of disk image
calculate_hash() {
    local file="$1"
    log "${YELLOW}Calculating SHA256 hash of the image...${NC}"
    sha256sum "$file" | tee -a "$LOG_FILE"
}

# Improved disk imaging function
image_disk() {
    lsblk
    echo -e -n "Enter the path of the disk to image (e.g., ${YELLOW}/dev/sda${NC}): "
    read -r disk

    if [ ! -e "$disk" ]; then
        log "${RED}Error: Disk '$disk' not found.${NC}"
        return 1
    fi

    display_disk_info "$disk"

    echo -e -n "${YELLOW}Proceed to image the disk? [y/N] ${NC}"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log "${YELLOW}Disk imaging aborted.${NC}"
        return 1
    fi

    echo -e -n "Enter the path to save the image (e.g., ${YELLOW}/Downloads/disk.img${NC}): "
    read -r path

    # Check for available space
    local disk_size=$(blockdev --getsize64 "$disk")
    local target_dir=$(dirname "$path")
    local available_space=$(df -B1 "$target_dir" | awk 'NR==2 {print $4}')

    if [ "$disk_size" -gt "$available_space" ]; then
        log "${RED}Error: Not enough space available in target directory.${NC}"
        log "${YELLOW}Required: $(numfmt --to=iec-i --suffix=B $disk_size)${NC}"
        log "${YELLOW}Available: $(numfmt --to=iec-i --suffix=B $available_space)${NC}"
        return 1
    fi

    if [ ! -d "$(dirname "$path")" ]; then
        log "${RED}Error: Directory '$(dirname "$path")' does not exist.${NC}"
        return 1
    fi

    log "${YELLOW}Starting disk imaging...${NC}"
    if dd if="$disk" of="$path" bs=4M status=progress conv=sync,noerror; then
        log "${GREEN}Disk imaging completed successfully.${NC}"
        calculate_hash "$path"
    else
        log "${RED}Disk imaging failed.${NC}"
        return 1
    fi
}

# Enhanced secure disk erasure
securely_erase_disk() {
    lsblk
    echo -e -n "Enter the disk to erase (e.g., ${YELLOW}/dev/sda${NC}): "
    read -r disk

    if [ ! -e "$disk" ]; then
        log "${RED}Error: Disk '$disk' not found.${NC}"
        return 1
    fi

    display_disk_info "$disk"

    echo -e "${RED}WARNING: This will permanently erase all data on $disk${NC}"
    echo -e -n "${YELLOW}Type the disk name again to confirm: ${NC}"
    read -r confirm_disk

    if [ "$disk" != "$confirm_disk" ]; then
        log "${RED}Disk names do not match. Aborting.${NC}"
        return 1
    }

    echo -e "Select erasure method:"
    echo -e "1. Single pass with random data (faster)"
    echo -e "2. Three passes (DoD 5220.22-M)"
    echo -e "3. Seven passes (Gutmann-lite)"
    read -r method

    case $method in
        1)
            log "${YELLOW}Starting single pass erasure...${NC}"
            if dd if=/dev/urandom of="$disk" bs=4M status=progress; then
                log "${GREEN}Disk erased successfully.${NC}"
            else
                log "${RED}Erasure failed.${NC}"
                return 1
            fi
            ;;
        2)
            log "${YELLOW}Starting DoD 5220.22-M three-pass erasure...${NC}"
            for pass in {1..3}; do
                log "${YELLOW}Pass $pass of 3${NC}"
                case $pass in
                    1) dd if=/dev/zero of="$disk" bs=4M status=progress ;;
                    2) dd if=/dev/urandom of="$disk" bs=4M status=progress ;;
                    3) dd if=/dev/zero of="$disk" bs=4M status=progress ;;
                esac
            done
            log "${GREEN}DoD erasure completed.${NC}"
            ;;
        3)
            log "${YELLOW}Starting seven-pass erasure...${NC}"
            for pass in {1..7}; do
                log "${YELLOW}Pass $pass of 7${NC}"
                dd if=/dev/urandom of="$disk" bs=4M status=progress
            done
            log "${GREEN}Seven-pass erasure completed.${NC}"
            ;;
        *)
            log "${RED}Invalid option!${NC}"
            return 1
            ;;
    esac
}

# Enhanced disk formatting function
format_disk() {
    lsblk
    echo -e -n "Enter the disk to format (e.g., ${YELLOW}/dev/sda${NC}): "
    read -r disk

    if [ ! -e "$disk" ]; then
        log "${RED}Error: Disk '$disk' not found.${NC}"
        return 1
    fi

    display_disk_info "$disk"

    echo -e "${RED}WARNING: This will erase all data on $disk${NC}"
    echo -e -n "${YELLOW}Type the disk name again to confirm: ${NC}"
    read -r confirm_disk

    if [ "$disk" != "$confirm_disk" ]; then
        log "${RED}Disk names do not match. Aborting.${NC}"
        return 1
    }

    echo -e "1. Format as ext4 filesystem (Linux)"
    echo -e "2. Format as NTFS filesystem (Windows)"
    echo -e "3. Format as FAT32 filesystem (USB drives, max 32GB)"
    echo -e "4. Format as exFAT filesystem (USB drives, >32GB)"
    echo -e "5. Format as btrfs filesystem (Linux)"
    echo -e "${YELLOW}Choose the format option:${NC}"
    read -r format_choice

    echo -e -n "Enter label for the filesystem: "
    read -r label

    case $format_choice in
        1)
            mkfs.ext4 -L "$label" "$disk" && \
            tune2fs -m 1 "$disk" && \
            log "${GREEN}Disk formatted as ext4 filesystem successfully.${NC}"
            ;;
        2)
            mkfs.ntfs -L "$label" -f "$disk" || \
            log "${RED}Failed to format disk as NTFS. Ensure ntfs-3g is installed.${NC}"
            ;;
        3)
            mkfs.fat -F32 -n "$label" "$disk" && \
            log "${GREEN}Disk formatted as FAT32 filesystem successfully.${NC}"
            ;;
        4)
            mkfs.exfat -n "$label" "$disk" || \
            log "${RED}Failed to format disk as exFAT. Ensure exfat-utils is installed.${NC}"
            ;;
        5)
            mkfs.btrfs -L "$label" "$disk" || \
            log "${RED}Failed to format disk as btrfs. Ensure btrfs-progs is installed.${NC}"
            ;;
        *)
            log "${RED}Invalid option!${NC}"
            return 1
            ;;
    esac
}

# Main menu
main_menu() {
    show_banner
    check_requirements

    PS3=$'\n'"${YELLOW}Choose an option (1-5):${NC} "
    while true; do
        echo -e "\n${BLUE}=== Main Menu ===${NC}"
        select choice in "Image Disk" "Securely Erase Disk" "Format Disk" "View Logs" "Exit"; do
            case $choice in
                "Image Disk")
                    image_disk
                    break
                    ;;
                "Securely Erase Disk")
                    securely_erase_disk
                    break
                    ;;
                "Format Disk")
                    format_disk
                    break
                    ;;
                "View Logs")
                    if [ -f "$LOG_FILE" ]; then
                        less "$LOG_FILE"
                    else
                        log "${YELLOW}No logs found.${NC}"
                    fi
                    break
                    ;;
                "Exit")
                    log "${YELLOW}Exiting the script.${NC}"
                    exit 0
                    ;;
                *)
                    log "${RED}Invalid option!${NC}"
                    break
                    ;;
            esac
        done
    done
}

# Trap Ctrl+C
trap 'echo -e "\n${YELLOW}Script interrupted by user${NC}"; exit 1' INT

# Initialize log file
touch "$LOG_FILE" 2>/dev/null || {
    echo "${RED}Cannot create log file. Please run as root.${NC}"
    exit 1
}

# Start script
check_sudo
main_menu
