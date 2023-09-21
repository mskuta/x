# SPDX-License-Identifier: Unlicense

# How to install (on Debian and derivatives):
#   1. apt-get -y install libdigest-sha-perl libnet-nslookup-perl
#   2. prefix=$HOME/.local
#   3. install -D <(cat <(printf '#!/usr/bin/env perl\n\n') update-dynamic-name.pl) "$prefix/bin/update-dynamic-name"

use Digest::SHA qw(sha1_hex);
use Getopt::Long;
use Net::Netrc;
use Net::Nslookup;
use POSIX qw(floor);

$progname = substr($0, rindex($0, '/') + 1);
$usage = <<END;
Usage:
  $progname [OPTIONS] SUBDOMAIN
Options:
  --netrc   Fetch the password from the .netrc file instead of the
            PASSCODE environment variable.
  --verify  Send a second query to check the actual state.
END
GetOptions(
	"netrc"  => \$netrc,
	"verify" => \$verify,
) or die($usage);

$hostname = $ARGV[0] . ".dynamic.name" if (@ARGV == 1);
if ($netrc) {
	$machine = Net::Netrc->lookup($hostname);
	$passcode = $machine->password() if ($machine);
}
else {
	$passcode = $ENV{PASSCODE} if ($ENV{PASSCODE});
}
$hostname and $passcode or die($usage);

print("Sending DNS query to update $hostname\n");
$record = nslookup(
	host   => sha1_hex($passcode . ":" . floor(time() / 1000)) . "." . $hostname,
	server => "update.dynamic.name",
	type   => "A",
);
die("DNS query failed\n") unless (defined($record));
print("Update successful: $record\n");

if ($verify) {
	print("Sending DNS query to verify $hostname\n");
	$record = nslookup(
		host   => $hostname,
		server => "update.dynamic.name",
		type   => "TXT",
	);
	die("DNS query failed\n") unless (defined($record));
	print("Verification successful: $record\n");
}

exit(0);

# vim: ts=8 sts=0 sw=8 noet
