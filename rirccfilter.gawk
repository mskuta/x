# SPDX-License-Identifier: Unlicense

BEGIN {
	# set field separator for RIR datasets
	FS = "|"

	# calculate this only once
	logof2 = log(2)

	# check given country code
	_cc = ""
	if (cc) {
		if (cc !~ /^[[:alpha:]]{2}$/)
			exit 2
		_cc = toupper(cc)
	}
}

/^\s*$/ || /^\s*#/ {
	# this line is blank or a comment
	next
}

NF == 6 && $NF == "summary" {
	# this line is a header (summary)
	next
}

NF == 7 && FNR == 1 {
	# this line is a header (version)
	k[1] = "Version"
	k[2] = "Registry"
	k[3] = "Serial"
	k[4] = "Records"
	k[5] = "Startdate"
	k[6] = "Enddate"
	k[7] = "UTC-Offset"
	for (i = 1; i <= NF; i++)
		print(k[i], $i) >"/dev/stderr"
}

NF == 9 && $3 == "ipv4" {
	# this line is a record

	# skip records not matching the selected county
	if (_cc && _cc != $2)
		next

	split($4, octets, ".")
	first_ip = lshift(octets[1], 24) + lshift(octets[2], 16) + lshift(octets[3], 8) + octets[4]
	last_ip = first_ip + $5 - 1
	printf("%s%d:%d.%d.%d.%d-%d.%d.%d.%d\n",
	       $2,
	       ++n[$2],
	       and(rshift(first_ip, 24), 0xff),
	       and(rshift(first_ip, 16), 0xff),
	       and(rshift(first_ip,  8), 0xff),
	       and(first_ip, 0xff),
	       and(rshift(last_ip, 24), 0xff),
	       and(rshift(last_ip, 16), 0xff),
	       and(rshift(last_ip,  8), 0xff),
	       and(last_ip, 0xff))
}

# vim: ts=8 sts=0 sw=8 noet
