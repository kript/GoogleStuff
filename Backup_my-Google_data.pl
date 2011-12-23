#!/usr/bin/perl-5.12.2
# from a template embedded documentation and command parsing
#  see POD for more info

use strict;
use v5.12.2; #make use of the say command and other nifty perl 10.0 onwards goodness
use Carp;
use common::sense;
use DateTime;
use WWW::Mechanize;
use YAML;
use WWW::Contact;
#TODO add UTF8 module here

#set the version number in a way Getopt::Euclid can parse
BEGIN { use version; our $VERSION = qv('0.1.1_1') }

use Getopt::Euclid; # Create a command-line parser that implements the documentation below... 

my $dir = $ARGV{-d};
my $reader = $ARGV{-r};
my $calendar = $ARGV{-c};
my $addressbook = $ARGV{-a};
#determine which options to run, defaulting to all of them
my $all;
if ( defined($reader) && defined($calendar) && defined($addressbook) )
	{ $all = 1; }
else
	{ $all = 0;  }

#check at least one option has been defined..
unless ( defined($reader) || defined($calendar) || defined($addressbook) )
 { croak "Need at least one option defined for backup use --man to see options"; }

sub Backup_Calendar
{
	my $accounthash = shift;
	my $account = $$accounthash;
	my $dir = shift;
	my $dt = DateTime->now;
	my $ymd = $dt->ymd;
	my $filename = $dir . "calendar_" . $ymd . ".ical.zip";
	
	# First, log in:
	my $mech = WWW::Mechanize->new;
	$mech->get('https://calendar.google.com/');
	$mech->form_with_fields(qw(Email Passwd))
    	or die "Failed to locate login form";
	$mech->set_fields(
    	Email => $account->{username}, Passwd => $account->{password}
	);
	$mech->submit or die "Failed to submit calendar login form";

	if  ( $mech->success() )
		{ say "succeeded - logged into google calendar"; }
	else
	{ say "failed" }

	# Now, fetch the ical export ZIP file:


	$mech->get(
    	'https://www.google.com/calendar/exporticalzip'
	) or carp "Failed to fetch ical export ZIP file";

	if  ( $mech->success() )
		{ say "succeeded - got ical"; }
	else
		{ carp "failed ical download" }

	$mech->save_content( $filename );

	say "saved ical at $filename";

} #end of sub Backup_Calendar


sub Backup_Contacts
{
	my $accounthash = shift;
	my $account = $$accounthash;
	my $dir = shift;
	my $dt = DateTime->now;
	my $ymd = $dt->ymd;
	my $filename = $dir . "googleContacts" . $ymd . ".yaml";
	my $fh;
	
	my $wc       = WWW::Contact->new();
	my $username = $account->{username} . '@googlemail.com';
	my @contacts = $wc->get_contacts($username, $account->{password});
	
	my $errstr   = $wc->errstr;
	if ($errstr) 
	{
		croak "failed to retreieve contacts because: $errstr"; # like 'Wrong Username or Password'
	} 
	else 
	{
		open $fh, ">:encoding(utf8)", "$filename" or croak "$filename: $!";
		#Dump the file as YAML
		my $YAML_Contacts = Dump(@contacts);
		print $fh $YAML_Contacts;
		#when done, close and write file
 		close $fh or croak "$filename: $!";
		say "written contacts file to $filename";
	}
} #end of sub Backup_Contacts

sub Backup_Reader
{
	my $accounthash = shift;
	my $account = $$accounthash;
	my $dir = shift;
	my $dt = DateTime->now;
	my $ymd = $dt->ymd;
	my $mech = WWW::Mechanize->new;
	my $filename = $dir . "googleReader" . $ymd . ".xml";
	
	# First, log in:
	$mech->get('https://www.google.com/reader');
	$mech->form_with_fields(qw(Email Passwd))
    	or die "Failed to locate reader login form";
	$mech->set_fields(
    	Email => $account->{username}, Passwd => $account->{password}
	);
	$mech->submit or die "Failed to submit login form";

	if  ( $mech->success() )
		{ say "succeeded - logged into google calendar"; }
	else
	{ say "failed" }

	$mech->get('http://www.google.com/reader/subscriptions/export'
		) or warn "Failed to fetch Reader subscriptions";

	say "saving Reader XML at $filename";
	$mech->save_content( $filename );
	if  ( $mech->success() )
		{ say "Reader download succeeded - got $filename"; }
	else
		{ carp "Reader download failed getting $filename because: $!" }


} #end of sub Backup_Reader

##Main code starts here

#get the google login data
my $account = YAML::LoadFile($ENV{HOME} . "/.google_login")
    or die "Failed to read $ENV{HOME}/.google_login - $!";
my $backup_dir = $dir;

say "creating files in $backup_dir";
say "loaded YAML credentials file OK";

if ( $all || $calendar ) { Backup_Calendar(\$account, $dir); } 
if ( $all || $addressbook ) { Backup_Contacts(\$account, $dir); }
if ( $all || $reader ) { Backup_Reader(\$account, $dir); }

say "completed all requested backups";



__END__
=head1 NAME

Backup_my-Google_data - make local copies of your contacts, caledner and reader subcriptions.


=head1 USAGE

    Backup_my-Google_data  -d -c -r -a
    	-d[irectory] specify destination directory
    	-c[alendar] download calendar as ics file
    	-r[eader] download reader subscrptions in XML
    	-a[ddressbook] download contacts in YAML format
    
..Sure, Google "do no evil", but I don't trust them to hold my data without me having a backup.

script to back up;

 * Google Contacts/Addressbook
 * Google Calender
 * Google Reader subscriptions

You can backup individual members of these via the command line options.
If none are provided (with the exception of -d in the future), all of them will be run.

*NOTE* unless you provide -d the data files will be created in the current working directory.

<b> Note</b> The script expect to find a file called ~/.google_login and will fail if it can't.
It's a YAML file and follows the following format;

 ---
 username: my_google_username
 password: my_google_password


Thanks to David Precious (bigpresh), who put his version on Github
 (https://github.com/bigpresh/misc-scripts/tree/master/backup-google-stuff).

=head1 OPTIONS

=over

=item  -d[ir] [=] <dir>

Specify directory to select the file from [default: dir.default]


=for Euclid:
    dir.type:    string 
    dir.default: './'
    dir.type.error: must be a valid directory

=item  -c[alendar]

enable backing up of Google Calendar

=item  -a[ddressbook]

enable backing up of Google Contacts/Addressbook.  Should work from both gmail and contacts

=item  -r[eader]

enable backing up of Google reader subscriptions.  
 Current backup option is XML only; OPLML would be more useful, but raw data is still cool.
 
=item –v

=item --verbose

Print all warnings

=item --version

=item --usage

=item --help

=item --man

Print the usual program information

=back

=begin remainder of documentation here. . .

