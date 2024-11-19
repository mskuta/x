# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=$HOME/.local
#   2. install -D <(cat <(printf '#!/usr/bin/env perl\n\n') rir2mmdb.pl) "$prefix/bin/rir2mmdb"
# How to use:
#   rir2mmdb <nro-delegated-stats >rir2mmdb-country-lite.mmdb

use v5.32;

use Socket;

use MaxMind::DB::Writer::Tree;
use Text::CSV;

# create a Tree object to map IPv4 addresses to country codes
my %types = (
	country  => 'map',
	iso_code => 'utf8_string',
);
my $tree = MaxMind::DB::Writer::Tree->new(
	database_type         => 'rir2mmdb-Country-Lite',
	description           => { en => 'Mappings of IPv4 addresses to country codes' },
	ip_version            => 4,
	languages             => ['en'],
	map_key_type_callback => sub { $types{ $_[0] } },
	record_size           => 24,
);

# create a CSV object with parameters that correspond to a "delegated-extended file" from a RIR
my $csv = Text::CSV->new({
	comment_str     => '#',
	sep_char        => '|',
	skip_empty_rows => 1,
	strict          => 0,
});

# get input either from stdin or from files
while (<<>>) {
	defined $csv->parse($_) or die "Failed to parse line $. of file $ARGV";

	# filter records
	my @columns = $csv->fields();
	@columns == 9 && $columns[2] eq 'ipv4' or next;

	# determine IP range
	my $first_ip = $columns[3];
	my $last_ip = inet_ntoa(pack('N', unpack('N', inet_aton($first_ip)) + $columns[4] - 1));
	$tree->insert_range($first_ip, $last_ip, { country => { iso_code => $columns[1] } });
}
continue {
	# reset line numbering on each input file
	close ARGV if eof;
}

# dump database
binmode(STDOUT, ':raw');
$tree->write_tree(\*STDOUT);

# vim: ts=8 sts=0 sw=8 noet
