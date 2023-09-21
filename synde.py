# SPDX-License-Identifier: Unlicense

# How to install:
#   1. name=synde
#   2. mkdir $name
#   3. cp $name.py $name/__main__.py
#   4. cd $name
#   5. python3 -m pip install --requirement=<(printf 'blessings >=1.7,<2\nrequests >=2.28.2,<3\n') --target=.
#   6. output=$(mktemp)
#   7. python3 -m zipapp "$PWD" --output="$output" --python='/usr/bin/env python3'
#   8. prefix=$HOME/.local
#   9. install -D "$output" "$prefix/bin/$name"
# How to use:
#   synde apropos
#   synde "vom Leder ziehen"

# Standard Library
from os.path import basename
import sys

# Cheese Shop
from blessings import Terminal
import requests


class TermNotFoundError(Exception):
    pass


class UsageError(Exception):
    pass


def main(argv):
    try:
        if len(argv) != 2:
            mesg = basename(argv[0]) + " TERM"
            raise UsageError(mesg)

        payload = {"q": argv[1], "format": "application/json", "similar": "true"}
        req = requests.get("https://www.openthesaurus.de/synonyme/search", params=payload, timeout=5)
        req.raise_for_status()

        rsp = req.json()
        if not rsp["synsets"]:
            mesg = argv[1]
            if "similarterms" in rsp:
                mesg += "\nSimilar terms: " + ", ".join(t["term"] for t in rsp["similarterms"])
            raise TermNotFoundError(mesg)

        outp = ""
        term = Terminal()
        for i in rsp["synsets"]:
            if i["categories"]:
                outp += ", ".join(term.italic + c + term.normal for c in i["categories"])
                outp += ":\n"
            for j in i["terms"]:
                if j["term"].lower() != argv[1].lower():
                    outp += j["term"]
                else:
                    outp += term.standout + j["term"] + term.normal
                if "level" in j:
                    outp += " " + term.dim + "(" + j["level"] + ")" + term.normal
                outp += "\n"
            outp += "\n"
        print(outp, end="")
    except TermNotFoundError as exc:
        print("Term not found: " + str(exc), file=sys.stderr)
        ret = 3
    except UsageError as exc:
        print("Usage: " + str(exc), file=sys.stderr)
        ret = 2
    except Exception as exc:
        print("Error: " + str(exc), file=sys.stderr)
        ret = 1
    else:
        ret = 0
    return ret


sys.exit(main(sys.argv))

# vim: ts=4 sts=0 sw=4 et
