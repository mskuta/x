# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=/usr/local/lib/nagios/plugins
#   2. install -D <(cat <(printf '#!/usr/bin/env python3\n\n') check_ncsi.py) "$prefix/check_ncsi"

from http import HTTPStatus
from http.client import HTTPConnection
from socket import getaddrinfo
import sys


class UnknownState(Exception):
    pass


class CriticalState(Exception):
    pass


class WarningState(Exception):
    pass


def check(timeout=5):
    host = "www.msftconnecttest.com"

    # query name server
    try:
        getaddrinfo(host, "http")
    except Exception as exc:
        raise UnknownState(str(exc)) from exc

    # connect and retrieve data
    try:
        conn = HTTPConnection(host, timeout=timeout)
        conn.request("GET", "/connecttest.txt")
        resp = conn.getresponse()
    except Exception as exc:
        raise CriticalState(str(exc)) from exc
    if resp.status != HTTPStatus.OK:
        raise WarningState(f"Bad status returned by server: {resp.status} {resp.reason}")

    data = resp.read()
    if data != b"Microsoft Connect Test":
        raise WarningState(f"Bad content returned by server: {data}")


def main(argv):
    try:
        if len(argv) != 1:
            raise UnknownState("Usage wrong")
        check()
    except UnknownState as exc:
        print(f"UNKNOWN - {str(exc)}")
        state = 3
    except CriticalState as exc:
        print(f"CRITICAL - {str(exc)}")
        state = 2
    except WarningState as exc:
        print(f"WARNING - {str(exc)}")
        state = 1
    else:
        print("OK - Full Internet access")
        state = 0
    return state


sys.exit(main(sys.argv))

# vim: ts=4 sts=0 sw=4 et
