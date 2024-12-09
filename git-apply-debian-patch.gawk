# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=$HOME/.local
#   2. install -D <(cat <(printf '#!/usr/bin/env -S gawk -f\n\n') git-apply-debian-patch.gawk) "$prefix/bin/git-apply-debian-patch"
# How to use:
#   cd GITREPO; d=SOURCEPACKAGE/debian/patches; xargs -I{} -a "$d/series" git-apply-debian-patch "$d/{}"

BEGIN {
	# separate key/value pairs from patch metadata into fields
	FS = ": "
}

BEGINFILE {
	print "git-apply-debian-patch: Processing file: " FILENAME
	delete git
}

$1 == "Author" {
	git["author"] = $2
}

$1 == "Last-Update" {
	git["date"] = $2
}

$1 == "Description" {
	git["msg"] = $2
}

$1 == "Index" {
	if ("author" in git && "date" in git && "msg" in git) {
		if (system("git apply --whitespace=nowarn '" FILENAME "' && git commit --all --author='" git["author"] "' --date='" git["date"] "T00:00:00Z' --message='" git["msg"] "'") == 0) {
			nextfile
		}
		else {
			print "git-apply-debian-patch: Problems occurred when running git" >"/dev/stderr"
			exit 255
		}
	}
	else {
		print "git-apply-debian-patch: Insufficient metadata available" >"/dev/stderr"
		exit 255
	}
}

# vim: ts=8 sts=0 sw=8 noet
