#!/bin/bash
# Copyright (c) 2019 roga <roga@roga.tw>
# All rights reserved.
#
# backup_www.sh: Backup each source subdirectory and keep backups for 60 days using TGZ.

# Global variables
TAR="$(command -v tar)"

# Function to check if required arguments are provided
check_arguments() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <source_dir> <backup_dir>"
        echo "Example: $0 /var/www /mnt/app-backup/www"
        exit 1
    fi

    if [ -z "$TAR" ]; then
        echo "tar must be installed and available in PATH." >&2
        exit 1
    fi
}

# Function to backup a single directory
backup_directory() {
    local directory_name="$1"
    local source_dir="$2"
    local backup_dir="$3"
    local time="$4"

    local backup_file="$backup_dir/${directory_name}-${time}.tgz"
    local temporary_file="${backup_file}.tmp.$$"

    echo "Backing up directory: $directory_name..."

    # Create the archive in a temporary file and publish it only after success
    if "$TAR" -zcf "$temporary_file" -C "$source_dir" "$directory_name" && \
        mv -f "$temporary_file" "$backup_file"; then
        echo "Success: $backup_file created"
        return 0
    else
        rm -f "$temporary_file"
        echo "Failed to backup directory: $directory_name" >&2
        return 1
    fi
}

# Function to clean up old backups
cleanup_old_backups() {
    local days="$1"
    local backup_dir="$2"

    echo "Cleaning up backups older than $days days..."
    find "$backup_dir" \
        -type f \
        -name "*.tgz" \
        -mtime +"$days" \
        -exec rm -v -- {} \;
}

# Main function
main() {
    # Check arguments
    check_arguments "$@"

    # Set source and backup directories
    local source_dir="$1"
    local backup_dir="$2"

    # Check if source directory exists
    if [ ! -d "$source_dir" ]; then
        echo "Source directory does not exist: $source_dir" >&2
        exit 1
    fi

    # Create backup directory if not exists
    if ! mkdir -p "$backup_dir"; then
        echo "Unable to create backup directory: $backup_dir" >&2
        exit 1
    fi

    # Resolve directories to absolute paths
    source_dir=$(cd "$source_dir" && pwd -P) || exit 1
    backup_dir=$(cd "$backup_dir" && pwd -P) || exit 1

    # Get current date
    local time
    time="$(date +"%Y-%m-%d")"

    # Backup each source subdirectory
    local successful_backups=0
    local directory_path
    local directory_name
    for directory_path in "$source_dir"/*; do
        [ -d "$directory_path" ] || continue
        directory_name="${directory_path##*/}"

        if backup_directory "$directory_name" "$source_dir" "$backup_dir" "$time"; then
            successful_backups=$((successful_backups + 1))
        fi
    done

    if [ "$successful_backups" -eq 0 ]; then
        echo "No new backups were created; existing backups will not be removed." >&2
        exit 1
    fi

    # Clean up old backups (60 days)
    cleanup_old_backups 60 "$backup_dir"

    echo "All done!"
}

# Execute main function
main "$@"
