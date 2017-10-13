#!/bin/bash
#
# # WP-CLI Dropbox Backup
#
# ## Options
#
# -s | --sites  @string Filename containing a list of sites (i.e. directories) to backup, one per line. Overrides $SITESTORE inside .dropboxbackup-config.sh.
#
# ## Configuration
#
# Utilizes WP-CLI to backup your WordPress sites and upload them
# to Dropbox. Configure this script by including a file named
# `dropboxbackup-config.sh` with the following variables:
#
# - DROPBOXCONFIG=.dropbox_uploader
# - USERPATH=/home/dir/for/user
# - BACKUPPATH=/local/path/to/backups
# - SITESTORE=/path/to/WordPress/installations
# - WEBROOT=public
# - DAYSKEEP=3
#
# ## Details
#
# This script requires dropbox_uploader to be installed. If you
# need to add it to your setup, do the following:
#
#   1. sudo curl "https://raw.githubusercontent.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh" -o /usr/bin/dropbox_uploader
#   2. sudo chmod +x /usr/bin/dropbox_uploader
#
# Now, you'll need to add your access token from an app you've
# setup in your Dropbox account. When you run `dropbox_uploader`
# it will walk you through the process.
#
# Finally, you'll need to setup a cron to call this script
# daily. Example:
#
# 30 0 * * * bash ~/dropboxbackup.sh >/dev/null 2>&1 # Runs every day at 12:30am
#
# Credit: https://guides.wp-bullet.com/automatically-back-wordpress-dropbox-wp-cli-bash-script/

# Process args
while [[ $# -gt 1 ]]
do
    key="$1"

    case $key in
        -s|--sites)
        SITES="$2"
        shift
        ;;
        *)

        ;;
    esac
done
echo SITES = "${SITES}"


# Get current directory (not bulletproof, source: http://www.ostricher.com/2014/10/the-right-way-to-get-the-directory-of-a-bash-script/)
PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check for `dropboxbackup-config.sh`
if ! $(source $PWD/dropboxbackup-config.sh 2>/dev/null); then
    echo 'ERROR: No configuration found! Please setup `dropboxbackup-config.sh`.'
    exit
fi

# Load the configuration
source $PWD/dropboxbackup-config.sh

#date prefix
DATEFORM=$(date +"%Y-%m-%d")

#calculate days as filename prefix
DAYSKEPT=$(date +"%Y-%m-%d" -d "-$DAYSKEEP days")

# Get our list of sites
if [ ! -z $SITES ]; then
    # read in an array of sites from our SITES file
    SITELIST=$(cat $SITES)
else
    #create array of sites based on folder names
    SITELIST=($(ls -lh $SITESTORE | awk '{print $9}'))
fi

#make sure the backup folder exists
mkdir -p $BACKUPPATH

#start the loop
for SITE in ${SITELIST[@]}; do
    # check if there are old backups and delete them
    EXISTS=$(dropbox_uploader -f $USERPATH/$DROPBOXCONFIG list /$SITE | grep -E $DAYSKEPT.*.tar.gz | awk '{print $3}')
    if [ ! -z $EXISTS ]; then
        dropbox_uploader -f $USERPATH/$DROPBOXCONFIG delete /$SITE/$DAYSKEPT-$SITE.tar.gz /$SITE/
        dropbox_uploader -f $USERPATH/$DROPBOXCONFIG delete /$SITE/$DAYSKEPT-$SITE.sql.gz /$SITE/
    fi

    echo Backing up $SITE
    #enter the WordPress folder
    cd $SITESTORE/$SITE/$WEBROOT

    # This script only backs up WordPress installs
    if ! $(wp core is-installed 2>/dev/null); then
        echo "$SITE is not a WordPress install, continuing with next site..."
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
    dropbox_uploader -f $USERPATH/$DROPBOXCONFIG upload $BACKUPPATH/$SITE/$DATEFORM-$SITE.tar.gz /$SITE/
    dropbox_uploader -f $USERPATH/$DROPBOXCONFIG upload $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.gz /$SITE/

    #remove backup
    rm -rf $BACKUPPATH/$SITE
done

#if you want to delete all local backups
#rm -rf $BACKUPPATH/*

#delete old backups locally over DAYSKEEP days old
#find $BACKUPPATH -type d -mtime +$DAYSKEEP -exec rm -rf {} \;