#!/bin/bash

num_backups="3"
backup_dir="/home/ubuntu/smcp-deploy/du-backup"
tmp_dir="/tmp/smcp-du-backup"
airctl_config="/opt/pf9/airctl/conf/airctl-config.yaml"
backup_command="/opt/pf9/airctl/airctl backup --outdir $tmp_dir --config $airctl_config --verbose"

# Function to create a new backup
create_backup() {

    # Create a directories if not present already to save backup files.
    if [ ! -d "$tmp_dir" ]; then
    mkdir "$tmp_dir"
    fi
    if [ ! -d "$backup_dir" ]; then
    mkdir "$backup_dir"
    fi


    # Get current date for appending to the backup file name and execute the command to create a new backup file.
    current_date=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "Creating a new backup..."
    $backup_command

    if [ ! $? -eq 0 ]; then
	    echo "Backup process failed!"
	    exit 1
    fi

    backup_filename=$(ls -1 "$tmp_dir/")

    if [ -f "$tmp_dir/$backup_filename" ]; then
        echo "Backup file created! : $backup_filename"

        # Rename the backup file with the current date appended.
        mv "$tmp_dir/$backup_filename" "$backup_dir/smcp-du-backup_${current_date}.tar.gz"
        new_backup_filename=$(ls -t $backup_dir | head -1)
        echo "Backup file renamed to: $new_backup_filename"
	rm -rf $tmp_dir
    fi
}

# Function to maintain the desired number of backup files
maintain_backup_count() {
    num_backups=$1
    echo "Expected number of backups: $num_backups"

    current_backups=$(ls -t "$backup_dir" | grep "smcp-du-backup" | wc -l)
    echo "Current number of backup files: $current_backups"

    while [ $current_backups -gt $num_backups ]; do
        oldest_file=$(ls -t "$backup_dir" | grep "smcp-du-backup" | tail -1)
        echo "Removing old backup file: $oldest_file"
        rm "$backup_dir/$oldest_file"
        current_backups=$(($current_backups - 1))
    done
}

# Main script

# Create a new backup
create_backup

# Maintain the desired number of backup files
maintain_backup_count $num_backups

echo "Backup process completed!"
