#!/usr/bin/env perl
# Backeotomy
# Secure backup with encryption and rsync
# Author: Dave Russell (drussell393)
# Author URL: https://createazure.com/

use strict;
use warnings;
use POSIX qw(strftime);
use GnuPG qw(:algo);
use YAML::XS qw(LoadFile);
use Data::Dumper;

my $defaultSettings = LoadFile('config.yaml');
my $date = strftime('%m%d%Y', localtime);

if ($defaultSettings->{'IS_WORDPRESS'}) {
    my $credential;
    my %credentials = get_wordpress_credentials();
    for $credential (keys %credentials) {
        $defaultSettings->{$credential} = $credentials{$credential};
    }
}

# Backup MySQL Database
my $dbSaveFile = $defaultSettings->{'SAVE_DIRECTORY'} . '/dbBackup_' . (exists $defaultSettings->{'PREFIX'} ? $defaultSettings->{PREFIX} . '_' : '') . $date . '.sql';

if (backup_mysql($defaultSettings->{'DB_USER'}, $defaultSettings->{'DB_PASSWORD'}, $defaultSettings->{'DB_NAME'}, $defaultSettings->{'DB_HOST'}, $dbSaveFile)) {
    log_message("MySQL Database successfully backed up!");
}
else
{
    log_message("MySQL Database could not be backed up. Please check MySQL log files, or the config.yaml credentials.");
}

# Backup Files
my $tarSaveFile = $defaultSettings->{'SAVE_DIRECTORY'} . '/fileBackup_' . (exists $defaultSettings->{'PREFIX'} ? $defaultSettings->{PREFIX} . '_' : '') . $date . '.tar.gz';

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
        log_message("We were able to encrypt your files for $defaultSettings->{'RECIPIENT'}.");
        if (!$defaultSettings->{'KEEP_FILES'}) {
            log_message("Deleting unencrypted files...");
            system("rm -fv ${dbSaveFile} ${tarSaveFile}");
        }
    }
    else
    {
        log_message("We were unable to encrypt your files for $defaultSettings->{'RECIPIENT'}.");
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
    my $gpg = new GnuPG();
    my $fileName;

    foreach $fileName (@fileNames) {
        $gpg->encrypt(plaintext => $fileName, output => $fileName . '.gpg',
                      armor => 1, sign => 0, recipient => $defaultSettings->{'GPG_RECIPIENT'});
        if (!-f $fileName . '.gpg') {
            die "Something went wrong!";
        }
    }
    return 1;
}

sub log_message {
    if ($defaultSettings->{'ENABLE_LOGGING'}) {
        if ($defaultSettings->{'LOG_FILE'}) {
            open (my $logFile, '>', $defaultSettings->{'LOG_FILE'})
                or die "Could not open the log file for writing.";
            print $_;
            close $logFile;
        }
        else
        {
            print strftime('[%m/%d/%Y] [%H:%M]', localtime); . $_ . "\n";
        }
    }
}
