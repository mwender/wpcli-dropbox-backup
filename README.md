# WP-CLI Dropbox Backup

Utilizes WP-CLI to backup your WordPress sites and upload them to Dropbox. Configure this script by including a file named `dropboxbackup-config.sh` with the following variables:

- `BACKUPPATH=/local/path/to/backups`
- `SITESTORE=/path/to/WordPress/installations`
- `DAYSKEEP=3`

This script requires dropbox_uploader to be installed. If you need to add it to your setup, do the following:

  1. `sudo curl "https://raw.githubusercontent.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh" -o /usr/bin/dropbox_uploader`
  2. `sudo chmod +x /usr/bin/dropbox_uploader`

Now, you'll need to add your access token from an app you've setup in your Dropbox account. When you run `dropbox_uploader` it will walk you through the process.

Finally, you'll need to setup a cron to call this script daily. Example:

`30 0 * * * bash ~/dropboxbackup.sh >/dev/null 2>&1 # Runs every day at 12:30am`

Credit: [Automatically Back up WordPress to Dropbox with WP-CLI Bash Script](https://guides.wp-bullet.com/automatically-back-wordpress-dropbox-wp-cli-bash-script/) 