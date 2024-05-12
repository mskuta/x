# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=/usr/local/lib/nagios/plugins
#   2. install -D <(cat <(printf '#!/usr/bin/env -S gawk -f\n\n') check_mountpoint.gawk) "$prefix/check_mountpoint"
# How to use:
#   check_mountpoint /mnt/nfs/home

BEGIN {
	STATE_OK = 0
	STATE_WARNING = 1
	STATE_CRITICAL = 2
	STATE_UNKNOWN = 3
	state = STATE_UNKNOWN
	text = "?"
	if (ARGC != 2)
		text = "Usage wrong"
	else {
		MOUNTSFILE = "/proc/mounts"
		if ((getline <MOUNTSFILE) == -1)
			text = ERRNO ": " MOUNTSFILE
		else {
			text = "Mountpoint not found: " ARGV[1]
			state = STATE_CRITICAL
			while (state != STATE_OK && (getline <MOUNTSFILE) > 0)
				if (ARGV[1] == $2) {
					text = "Mountpoint found: " $2 "\nSource: " $1 "\nType: " $3 "\nOptions: " $4
					state = STATE_OK
				}
		}
	}

	state_text[STATE_OK] = "OK"
	state_text[STATE_WARNING] = "WARNING"
	state_text[STATE_CRITICAL] = "CRITICAL"
	state_text[STATE_UNKNOWN] = "UNKNOWN"
	print(state_text[state], "-", text)
	exit(state)
}

# vim: ts=8 sts=0 sw=8 noet
