Purpose: Create automated backups for WordPress and non-WordPress websites alike, and 
give the option to encrypt those backups/send them via rsync to another server for storage.

### Dedication

There's quite a few people that day-to-day have been pretty cool to work with. Among these
people are:

- [Jonathan Frederickson](https://github.com/jfrederickson) (who wanted to name this `Backinator`)
- [Charles Birk](https://github.com/cjbirk) (who provided the name `Backeotomy`)
- [Ricardo Feliciano](https://github.com/felicianotech) (who's a pretty cool guy filled up to the brim with Starbucks)
- [Sean Heuer](https://github.com/OompahLoompah) (who's a close friend and an inspirational guy)

I would like to dedicate this script to the four aforementioned colleagues. They're pretty
cool.


# What You Need to Know

This README will document everything that you need to know to start using Backeotomy. This documentation
assumes that you have already configured GnuPG (GPG) on your system, if you want to use the GPG 
encryption feature that is built into Backeotomy.

We're going to assume that you have made the main file (`backeotomy.pl`) executable:

`chmod +x backeotomy.pl`

## Setup

There is minimal setup involved in starting with Backeotomy. The idea behind the script was to make it 
as simple as possible to use and setup, so that you could start automating backups in less than an hour.


### Perl Modules

You will need to install the following Perl modules from CPAN:

- YAML::XS

You can do this by running the following command (in Linux):

`cpan YAML::XS`

We also use the following built-in Perl modules:

- POSIX (for dates)

### Configuration File

Backeotomy comes with a configuration file. As there are no command-line arguments with this script,
you will need to setup the configuration file (`config.yaml`) before using the script.

The descriptions of each key is listed in the comments of the YAML file, but they will be listed here
for your convenience as well:

| Key              | Description                                                                                                                                                 |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ENABLE_LOGGING   | If you want logging (at all, even to STDOUT), you need to enable this. Otherwise, there will be no logs from the script itself. (Default: Enabled)          |
| LOG_FILE         | The file that you want to log to. If this is not set, we will log to STDOUT or the cron log if you're using a cron job. (Default: Log to STDOUT, commented) |
| ROOT_DIRECTORY   | This is the root directory of your website. If you're using WordPress, we will use this to get the `wp-config.php` file later.                              |
| USE_RSYNC        | You will need to enable this if you intend to use the built-in rsync support (eg. sending the files to another server after backup).                        |
| RSYNC_USER       | Username for the rsync                                                                                                                                      |
| RSYNC_PASSWORD   | Password for the rsync user (Default: Disabled, use SSH keys!)                                                                                              |
| RSYNC_HOST       | Hostname for the rsync                                                                                                                                      |
| RSYNC_DIRECTORY  | Remote directory for the rsync                                                                                                                              |
| USE_GPG          | You must have GnuPG installed on your system and a key set up. This will encrypt both the SQL and tar file backup after they've been backed up              |
| GPG_RECIPIENT    | You must set the e-mail of the corresponding public key for the encrypted file if you're using GPG.                                                         |
| KEEP_FILES       | Do you want to keep your files locally? If you choose false (0), plain-text files will be removed at successful encryption and gpg files removed at rsync   |
| SECURE_SCRUB     | When we remove your files (if KEEP_FILES is set to false (0)), do you want us to securely remove them by rewriting them 250 times with zeros?               |
| SAVE_DIRECTORY   | Where do you want us to save your files? (You must set this even if KEEP_FILES is 0, because we need a place to put them while they're being processed)     |
| FILE_PREFIX      | This will be a file prefix next to the default (eg. if your file prefix is `FelicianoTech`, your file will be saved as `dbBackup_FelicianoTech_#date#.sql`) |
| IS_WORDPRESS     | Is this WordPress? If so, we'll obtain your database information from `wp-config.php`.                                                                      |
| DB_USER          | If this isn't WordPress, or you moved your `wp-config.php` file, you'll need to specify your database information                                           |
| DB_PASSWORD      | If this isn't WordPress, or you moved your `wp-config.php` file, you'll need to specify your database information                                           |
| DB_NAME          | If this isn't WordPress, or you moved your `wp-config.php` file, you'll need to specify your database information                                           |
| DB_HOST          | If this isn't WordPress, or you moved your `wp-config.php` file, you'll need to specify your database information                                           |


## Usage

Once you have completed configuring your instance of Backeotomy, you can add a cronjob to run
as many times as you need to run the backup. You can also manually run the backup by running
the script.

`./backeotomy.pl`
