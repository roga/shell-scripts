#!/bin/bash
# Copyright (c) 2019 roga <roga@roga.tw>
# All rights reserved.
#
# mysql_backup.sh: Backup MySQL databases and keep backups for 60 days using ZIP.

set -o pipefail

# Global variables
MYSQL="$(command -v mysql)"
MYSQLDUMP="$(command -v mysqldump)"

# Function to check if required arguments are provided
check_arguments() {
    if [ $# -lt 4 ]; then
        echo "Usage: $0 <db_host> <db_user> <db_passwd> <backup_path>"
        echo "Example: $0 127.0.0.1 root password /mnt/app-backup/mysql"
        exit 1
    fi

    if [ -z "$MYSQL" ] || [ -z "$MYSQLDUMP" ]; then
        echo "mysql and mysqldump must be installed and available in PATH." >&2
        exit 1
    fi
}

# Function to get list of databases to backup
get_databases() {
    local db_user="$1"
    local db_passwd="$2"
    local db_host="$3"
    
    MYSQL_PWD="$db_passwd" "$MYSQL" -u "$db_user" -h "$db_host" -Bse "SHOW DATABASES;" | \
        grep -Ev "^(information_schema|performance_schema|mysql|sys)$"
}

# Function to backup a single database
backup_database() {
    local db="$1"
    local db_user="$2"
    local db_passwd="$3"
    local db_host="$4"
    local time="$5"
    local backup_dir="$6"
    
    local sql_file="$backup_dir/${time}.${db}.sql"
    local zip_file="$backup_dir/${time}.${db}.zip"

    echo "Backing up database: $db..."

    # Dump SQL file
    if ! MYSQL_PWD="$db_passwd" "$MYSQLDUMP" \
        --default-character-set=utf8 --single-transaction --add-drop-table \
        -u "$db_user" -h "$db_host" "$db" > "$sql_file"; then
        echo "Failed to dump database: $db" >&2
        rm -f "$sql_file"
        return 1
    fi

    # Compress with zip
    if zip -j -q "$zip_file" "$sql_file"; then
        rm -f "$sql_file"
        echo "Success: $zip_file created"
        return 0
    else
        echo "Failed to compress $sql_file" >&2
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
        -name "*.zip" \
        -mtime +"$days" \
        -exec rm -v -- {} \;
}

# Main function
main() {
    # Check arguments
    check_arguments "$@"
    
    # Set database credentials and backup directory
    local db_host="$1"
    local db_user="$2"
    local db_passwd="$3"
    local backup_dir="$4"
    
    # Create backup directory if not exists
    if ! mkdir -p "$backup_dir"; then
        echo "Unable to create backup directory: $backup_dir" >&2
        exit 1
    fi
    
    # Get current date
    local time="$(date +"%Y-%m-%d")"
    
    # Get list of databases to backup
    local dbs
    if ! dbs=$(get_databases "$db_user" "$db_passwd" "$db_host"); then
        echo "Unable to retrieve database list; no backups were created." >&2
        exit 1
    fi

    if [ -z "$dbs" ]; then
        echo "No databases found; no backups were created." >&2
        exit 1
    fi
    
    # Backup each database
    local successful_backups=0
    while IFS= read -r db; do
        [ -n "$db" ] || continue
        if backup_database "$db" "$db_user" "$db_passwd" "$db_host" "$time" "$backup_dir"; then
            successful_backups=$((successful_backups + 1))
        fi
    done <<< "$dbs"

    if [ "$successful_backups" -eq 0 ]; then
        echo "No new backups were created; existing backups will not be removed." >&2
        exit 1
    fi

    # Clean up old backups (60 days), while preserving the newest archive.
    cleanup_old_backups 60 "$backup_dir"
    
    echo "All done!"
}

# Execute main function
main "$@"
