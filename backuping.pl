#!/usr/bin/env perl
# Secure backup with encryption and rsync
# Author: Dave Russell (drussell393)
# Author URL: https://createazure.com/

use strict;
use warnings;
use POSIX qw(strftime);
use GnuPG qw(:algo);
use YAML::XS qw(LoadFile);

my $defaultSettings = LoadFile('config.yaml');

print $defaultSettings;

=for comment
my %config = get_user_credentials();
my $date = strftime('%m%d%Y', localtime);

if (backup_mysql($config{DB_USER}, $config{DB_PASSWORD}, $config{DB_NAME}, $config{DB_HOST}, '/root/dbBackup_' . $date . '.sql')) {
    print "We have success, papi. Goodbye. \n"
}

if (backup_files('/srv/www/public', '/root/wpBackup_' . $date . '.tar.gz')) {
    print "More successes! \n"
}

# Enable this section if you want to use GPG encryption
$config{GPG_RECIPIENT} = 'dave@createazure.com';
if (encrypt_files('/root/wpBackup_' . $date . '.tar.gz', '/root/dbBackup_' . $date . '.sql')) {
    print "Yay team! \n"
}

=cut

sub get_user_credentials_wordpress {
    my $config = 'public/wp-config.php';
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
        print $fileName;
        $gpg->encrypt(plaintext => $fileName, output => $fileName . '.gpg',
                      armor => 1, sign => 0, recipient => $config{GPG_RECIPIENT});
        if (!-f $fileName . '.gpg') {
            die "Something went wrong!";
        }
    }
    return 1;
}
