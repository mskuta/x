# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=$HOME/.local
#   2. install -D <(cat <(printf '#!/usr/bin/env bash\n\n') transmission-session.bash) "$prefix/bin/transmission-session"

set -euo pipefail

readonly myname=${BASH_SOURCE[0]##*/}
auth= host= port=
showusage=false
altspeed=
seedqueue=
seedqueuesize=-1
if args=$(getopt 'c:aAqQs:h' $*); then
	set -- $args

	# process options
	while [[ $# -ne 0 ]]; do
		case $1 in
			-c)
				if [[ $2 =~ ^((.+:.+)@)?([^:@]+)(:([1-9][0-9]*))?$ ]]; then
					auth=${BASH_REMATCH[2]}
					host=${BASH_REMATCH[3]}
					port=${BASH_REMATCH[5]}
				else
					showusage=true
				fi
				shift
				shift
				;;
			-a)
				altspeed=true
				shift
				;;
			-A)
				altspeed=false
				shift
				;;
			-q)
				seedqueue=true
				shift
				;;
			-Q)
				seedqueue=false
				shift
				;;
			-s)
				if [[ $2 =~ ^[0-9]+$ ]]; then
					seedqueuesize=$2
				else
					showusage=true
				fi
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
	if [[ $# -gt 0 ]]; then
		showusage=true
	fi
else
	showusage=true
fi
if [[ $showusage == true ]]; then
	echo "Usage:"
	echo "  $myname [-c [USER:PASS@]HOST[:PORT]] [-a|-A] [-q|-Q] [-s NUMBER]"
	echo "Options:"
	echo "  -c  Connection details of Transmission's RPC socket."
	echo "  -a  Enable alternative speed limits."
	echo "  -A  Disable alternative speed limits."
	echo "  -q  Enable seed queue."
	echo "  -Q  Disable seed queue."
	echo "  -s  Set seed queue size."
	echo ""
	echo "If no modifying option has been selected, just the active settings will be displayed."
	exit 2
fi

# set curl parameters to be used in every call
curlopts=()
curlopts+=("--show-error")
curlopts+=("--silent")
[[ -n $auth ]] && curlopts+=("--basic --user $auth")
curlurl="${host:-localhost}:${port:-9091}/transmission/rpc"

# get current session id
readonly sessionid=$(curl --head ${curlopts[*]} $curlurl | awk '/^X-Transmission-Session-Id:/ { sub(/\r$/, ""); printf("%s", $NF) }')

# build an RPC request in JSON
json=
if [[ -z $altspeed && -z $seedqueue && $seedqueuesize -eq -1 ]]; then
	json+='"method":"session-get"'
	json+=','
	json+='"arguments":{}'
else
	arguments=()
	[[ -n $altspeed ]] && arguments+=('"alt-speed-enabled":'$altspeed)
	[[ -n $seedqueue ]] && arguments+=('"seed-queue-enabled":'$seedqueue)
	[[ $seedqueuesize -ne -1 ]] && arguments+=('"seed-queue-size":'$seedqueuesize)
	json+='"method":"session-set"'
	json+=','
	json+='"arguments":{'
	for (( i=0; i<${#arguments[@]}; i++ )); do
		[[ $i -gt 0 ]] && json+=','
		json+=${arguments[$i]}
	done
	json+='}'
fi
curl \
  --data "{$json}" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "X-Transmission-Session-Id: $sessionid" \
  ${curlopts[*]} $curlurl

# vim: ts=8 sts=0 sw=8 noet
