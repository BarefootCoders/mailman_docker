#!/usr/bin/env bash

# Backup data from the mailman data container.

# Set abort on error:
set -e

prog_name=`basename $0`

if [ "$#" -gt "1" ]; then
	echo "Usage:" 
	echo "$prog_name"
	echo "or"
	echo "$prog_name dest_file"
	exit
fi

# Check if mailman_server_cont is running. If it does,
# we will abort. We don't want to read the data while the server
# container is running.
nlines_server=`docker ps | grep mailman_server_cont | wc -l`
if [ "$nlines_server" -gt "0" ]
	then echo "mailman_server_cont is still running! Aborting data backup." && \
		exit
fi

echo "Creating backup..."

BACK_DIR="backup_temp"

mkdir -p ./${BACK_DIR}

# Backup the data, lists and archives mailman directories
# by copying them to backup_temp directory on the host:
# Note: The p flag for cp preserves ownership.
docker run --name mailman_data_backup_cont \
	--volumes-from mailman_data_cont \
	-v $(readlink -f $BACK_DIR):/backup \
        mailman_data \
	sh -c "\
        cp -Rp /var/lib/mailman/data /backup && \
        cp -Rp /var/lib/mailman/lists /backup && \
        cp -Rp /var/lib/mailman/archives /backup"

# Clean up docker container:
docker rm -f mailman_data_backup_cont

# We are going to save into ./backups directory:
mkdir -p ./backups

# Create a tar archive (With the current date):

if [ "$#" -eq "1" ]; then
	# Filename (full path) is chosen as argument:
	back_filename=$1
else
	# Filename is generated by time:
	now=$(date +%Y_%m_%d_%H_%M_%S)
	back_filename="./backups/backup_${now}.tar"
fi

# Put all data to back up into a tar file:
tar -cvf ${back_filename} $BACK_DIR > /dev/null

# Remove the temporary backups folder:
rm -R $BACK_DIR

echo "Backup saved at ${back_filename}"

# Unset abort on error:
set +e
