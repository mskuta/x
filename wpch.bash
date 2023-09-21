# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=$HOME/.local
#   2. install -D <(cat <(printf '#!/usr/bin/env bash\n\n') wpch.bash) "$prefix/libexec/wpch"
#   3. mkdir -p "$prefix/bin"
#   4. for i in email url; do ln -s ../libexec/wpch "$prefix/bin/wpch$i"; done

set -euo pipefail

readonly myname=${BASH_SOURCE[0]##*/}

# determine the action to be taken by the name of this script
act=$myname
act=${act%.*}
act=${act#wpch}
declare -A wpoptions
optstring=d:h
case $act in
	email)
		wpoptions=([admin_email]=true)
		;;
	url)
		wpoptions=([home]=true [siteurl]=true)
		optstring=HS$optstring
		;;
	*)
		echo "Error: Action to be taken unknown." >&2
		exit 1
esac

directory=.
showusage=false
wpoptionvalue=
if args=$(getopt $optstring $*); then
	set -- $args

	# process options
	while [[ $# -ne 0 ]]; do
		case $1 in
			-H)
				wpoptions[home]=false
				shift
				;;
			-S)
				wpoptions[siteurl]=false
				shift
				;;
			-d)
				directory=$2
				shift
				shift
				;;
			-h)
				showusage=true
				shift
				;;
			--)
				shift
				break
				;;
		esac
	done

	# process arguments
	if [[ $# -eq 1 ]]; then
		wpoptionvalue=$1
	elif [[ $# -gt 1 ]]; then
		showusage=true
	fi
else
	showusage=true
fi
if [[ $showusage == true ]]; then
	echo "Usage:"
	echo "  $myname [-d DIRECTORY]"
	case $act in
		email)
			echo "  $myname [-d DIRECTORY] ADDRESS"
			;;
		url)
			echo "  $myname [-d DIRECTORY] [-HS] URL"
			;;
	esac
	echo "Options:"
	echo "  -d  Directory containing the WordPress files."
	case $act in
		url)
			echo "  -H  Do not change the WordPress Address (\"home\")."
			echo "  -S  Do not change the Site Address (\"siteurl\")."
			;;
	esac
	echo ""
	echo "If no DIRECTORY is specified, the current one will be used."
	echo "If no argument is specified, just the active settings will be displayed."
	exit 2
fi
if [[ ! -f "$directory/wp-config.php" ]]; then
	echo "Error: Directory does not seem to contain WordPress files: $directory" >&2
	exit 1
fi

# transform PHP variables into Shell variables; sed removes possibly
# added BOM
eval "$(
php <<END | sed $'1s/^\uFEFF//'
<?php
include "$directory/wp-config.php";
echo 'db_host=', constant('DB_HOST'), ';',
     'db_name=', constant('DB_NAME'), ';',
     'db_password=', constant('DB_PASSWORD'), ';',
     'db_user=', constant('DB_USER'), ';',
     'table_prefix=', \$table_prefix;
END
)"

# put the database password in a temporary file so that it does not
# have to be passed on the command line and to avoid an input prompt
mysqlcnfpath=$(mktemp -t)
trap 'rm --force "$mysqlcnfpath"' EXIT
printf "[client]\npassword=%s\n" "$db_password" >"$mysqlcnfpath"

# change settings
if [[ -n "$wpoptionvalue" ]]; then
	for wpoptionname in "${!wpoptions[@]}"; do
		if [[ ${wpoptions[$wpoptionname]} == true ]]; then
			mysql \
			  --defaults-file="$mysqlcnfpath" \
			  --host=$db_host \
			  --database=$db_name \
			  --user=$db_user \
			  --execute="UPDATE ${table_prefix}options SET option_value=\"$wpoptionvalue\" WHERE option_name=\"$wpoptionname\""
		fi
	done
fi

# display settings
for wpoptionname in "${!wpoptions[@]}"; do
	mysql \
	  --defaults-file="$mysqlcnfpath" \
	  --host=$db_host \
	  --database=$db_name \
	  --user=$db_user \
	  --execute="SELECT option_name, option_value FROM ${table_prefix}options WHERE option_name=\"$wpoptionname\"" \
	  --batch \
	  --skip-column-names
done

exit 0

# vim: ts=8 sts=0 sw=8 noet
