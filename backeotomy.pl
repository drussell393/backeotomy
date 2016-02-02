#!/usr/bin/env perl
# Backeotomy
# Secure backup with encryption and rsync
# Author: Dave Russell (drussell393)
# Author URL: https://createazure.com/

use strict;
use warnings;
use POSIX qw(strftime);
use YAML::XS qw(LoadFile);
use File::Basename;

my $defaultSettings = LoadFile(dirname(__FILE__) . '/config.yaml');
my $date = strftime('%m%d%Y', localtime);

if ($defaultSettings->{'IS_WORDPRESS'}) {
    my $credential;
    my %credentials = get_wordpress_credentials();
    for $credential (keys %credentials) {
        $defaultSettings->{$credential} = $credentials{$credential};
    }
}

# Backup MySQL Database
my $dbSaveFile = $defaultSettings->{'SAVE_DIRECTORY'} . '/dbBackup_' . (exists $defaultSettings->{'FILE_PREFIX'} ? $defaultSettings->{'FILE_PREFIX'} . '_' : '') . $date . '.sql';

if (backup_mysql($defaultSettings->{'DB_USER'}, $defaultSettings->{'DB_PASSWORD'}, $defaultSettings->{'DB_NAME'}, $defaultSettings->{'DB_HOST'}, $dbSaveFile)) {
    log_message("MySQL Database successfully backed up!");
}
else
{
    log_message("MySQL Database could not be backed up. Please check MySQL log files, or the config.yaml credentials.");
}

# Backup Files
my $tarSaveFile = $defaultSettings->{'SAVE_DIRECTORY'} . '/fileBackup_' . (exists $defaultSettings->{'FILE_PREFIX'} ? $defaultSettings->{'FILE_PREFIX'} . '_' : '') . $date . '.tar.gz';

if (backup_files($defaultSettings->{'ROOT_DIRECTORY'}, $tarSaveFile)) {
    log_message("Your files have been successfully backed up!");
}
else
{
    log_message("Something went wrong! We couldn't back up your files. Check to make sure the directory exists, or check your logs for the output of the tar command.");
}


# Encrypt Files
if ($defaultSettings->{'USE_GPG'}) {
    if (encrypt_files($dbSaveFile, $tarSaveFile)) {
        log_message("We were able to encrypt your files for $defaultSettings->{'GPG_RECIPIENT'}.");
        if (!$defaultSettings->{'KEEP_FILES'}) {
            log_message("Deleting unencrypted files...");
            scrub($dbSaveFile, $tarSaveFile);
        }
    }
    else
    {
        log_message("We were unable to encrypt your files for $defaultSettings->{'GPG_RECIPIENT'}.");
    }
}

# Rsync Files
if ($defaultSettings->{'USE_RSYNC'}) {
    if ($defaultSettings->{'USE_GPG'}) {
        $dbSaveFile = $dbSaveFile . '.gpg';
        $tarSaveFile = $tarSaveFile . '.gpg';
    }
    if (rsync_files($dbSaveFile, $tarSaveFile)) {
        log_message("Rsync succeeded for both files.");
        if (!$defaultSettings->{'KEEP_FILES'}) {
            log_message("Removing local files...");
            scrub($dbSaveFile, $tarSaveFile);
        }
    }
}

sub get_wordpress_credentials {
    my $config = $defaultSettings->{'ROOT_DIRECTORY'} . '/wp-config.php';
    my $configArray;
    my %configArray;
    my $configOption;

    open(my $configContents, '<', $config) 
        or die "Can't do!";
    while (my $line = <$configContents>) {
        if ($line =~ /^define\(/) {
            my @configOptions = join('', split(/^define\(|\)\;/, $line), '');
            foreach $configOption (@configOptions) {
                my @configOption = split(/,/, $configOption);
                my $key = join('', split(/'|\s+/, $configOption[0]));
                my $value = join('', split(/'|\s+/, $configOption[1]));
                $configArray{$key} = $value;
            }
        }
    }
    close $configContents;
    return %configArray;
}

sub backup_mysql {
    my ($username) = $_[0];
    my ($password) = $_[1];
    my ($database) = $_[2];
    my ($hostname) = $_[3];
    my ($saveLocation) = $_[4];

    system("mysqldump -h ${hostname} -u ${username} -p'${password}' ${database} > ${saveLocation}");
    
    if (-f $saveLocation) {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub backup_files {
    my ($rootDirectory) = $_[0];
    my ($saveLocation) = $_[1];
    
    system("tar -czf ${saveLocation} ${rootDirectory}");

    if (-f $saveLocation) {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub encrypt_files {
    my (@fileNames) = @_;
    my $fileName;

    foreach $fileName (@fileNames) {
        if (-f $fileName) {
            system("gpg --recipient $defaultSettings->{'GPG_RECIPIENT'} --output ${fileName}.gpg --encrypt ${fileName} >>$defaultSettings->{'LOG_FILE'} 2>&1");
            if (!-f $fileName . '.gpg') {
                return 0;
            }
        }
        else
        {
            return 0;
        }
    }
    return 1;
}

sub rsync_files {
    my (@fileNames) = @_;
    my $fileName;

    foreach $fileName (@fileNames) {
        if (-f $fileName) {
            system("rsync -avz " . (exists $defaultSettings->{'RSYNC_PASSWORD'} ? "-p '" . $defaultSettings->{'RSYNC_PASSWORD'} . "'" : '') . " ${fileName} " . $defaultSettings->{'RSYNC_USER'} . "@" . $defaultSettings->{'RSYNC_HOST'} . ":" . $defaultSettings->{'RSYNC_DIRECTORY'});
        }
        else
        {
            return 0;
        }
    }
    return 1;
}

sub scrub {
    my (@fileNames) = @_;
    my $fileName;

    foreach $fileName (@fileNames) {
        if (-f $fileName) {
            if ($defaultSettings->{'SECURE_SCRUB'}) {
                log_message("Securely scrubbing: ${fileName}");
                system("shred -n 250 -z -u ${fileName}");
            }
            else
            {
                log_message("Removing the file using 'rm'...");
                system("rm -f ${fileName}");
            }
        }
        return 1;
    }
}

sub log_message {
    if ($defaultSettings->{'ENABLE_LOGGING'}) {
        my $message = $_[0];
        if ($defaultSettings->{'LOG_FILE'}) {
            open (my $logFile, '>>', $defaultSettings->{'LOG_FILE'})
                or die "Could not open the log file for writing.";
            print $logFile strftime('[%m/%d/%Y] [%H:%M] ', localtime) . $message . "\n";
            close $logFile;
        }
        else
        {
            print strftime('[%m/%d/%Y] [%H:%M] ', localtime) . $message . "\n";
        }
    }
}
