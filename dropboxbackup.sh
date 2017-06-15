#!/usr/bin/env bash
#
# WP-CLI Dropbox Backup
#
# Utilizes WP-CLI to backup your WordPress sites and upload them
# to Dropbox. Configure this script by including a file named
# `dropboxbackup-config.sh` with the following variables:
#
# - BACKUPPATH=/local/path/to/backups
# - SITESTORE=/path/to/WordPress/installations
# - DAYSKEEP=3
#
# Credit: https://guides.wp-bullet.com/automatically-back-wordpress-dropbox-wp-cli-bash-script/

# Check for `dropboxbackup-config.sh`
if ! $(source dropboxbackup-config.sh 2>/dev/null); then
    echo 'ERROR: No configuration found!. Please setup `dropboxbackup-config.sh` with your BACKUPPATH and SITESTORE vars.'
    exit
fi

# Load the configuration
source dropboxbackup-config.sh

#date prefix
DATEFORM=$(date +"%Y-%m-%d")

#calculate days as filename prefix
DAYSKEPT=$(date +"%Y-%m-%d" -d "-$DAYSKEEP days")

#create array of sites based on folder names
SITELIST=($(ls -lh $SITESTORE | awk '{print $9}'))

#make sure the backup folder exists
mkdir -p $BACKUPPATH

#start the loop
for SITE in ${SITELIST[@]}; do
    # check if there are old backups and delete them
    EXISTS=$(dropbox_uploader list /$SITE | grep -E $DAYSKEPT.*.tar.gz | awk '{print $3}')
    if [ ! -z $EXISTS ]; then
        dropbox_uploader delete /$SITE/$DAYSKEPT-$SITE.tar.gz /$SITE/
        dropbox_uploader delete /$SITE/$DAYSKEPT-$SITE.sql.gz /$SITE/
    fi

    echo Backing up $SITE
    #enter the WordPress folder
    cd $SITESTORE/$SITE/public

    # This script only backs up WordPress installs
    if ! $(wp core is-installed); then
        continue
    fi

    if [ ! -e $BACKUPPATH/$SITE ]; then
        mkdir $BACKUPPATH/$SITE
    fi

    #back up the WordPress folder
    tar -czf $BACKUPPATH/$SITE/$DATEFORM-$SITE.tar.gz .

    # Back up the WordPress database
    wp db export $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql --single-transaction --quick --lock-tables=false --allow-root --skip-themes --skip-plugins
    cat $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql | gzip > $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.gz
    rm $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql

    #upload packages
    dropbox_uploader upload $BACKUPPATH/$SITE/$DATEFORM-$SITE.tar.gz /$SITE/
    dropbox_uploader upload $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.gz /$SITE/

    #remove backup
    rm -rf $BACKUPPATH/$SITE
done

#if you want to delete all local backups
#rm -rf $BACKUPPATH/*

#delete old backups locally over DAYSKEEP days old
#find $BACKUPPATH -type d -mtime +$DAYSKEEP -exec rm -rf {} \;