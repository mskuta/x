# SPDX-License-Identifier: Unlicense

# How to install:
#   1. name=purge-maven-repo
#   2. mkdir $name
#   3. cp $name.py $name/__main__.py
#   4. cd $name
#   5. python3 -m pip install --target=. --upgrade 'packaging==24.*' 'xmltodict==0.13.*'
#   6. output=$(mktemp)
#   7. python3 -m zipapp "$PWD" --output="$output" --python='/usr/bin/env python3'
#   8. prefix=$HOME/.local
#   9. install -D "$output" "$prefix/bin/$name"
# How to use:
#   purge-maven-repo ~/.m2/repository/some/project/maven-metadata.xml

# Standard Library
from collections import defaultdict
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from shutil import rmtree
import logging
import sys

# Cheese Shop
from packaging.version import InvalidVersion, parse as parseversion
from xmltodict import parse as parsexml, unparse as unparsexml


def main(argc, argv):
    logging.basicConfig(format='%(levelname)s: %(message)s', level=logging.INFO)
    try:
        # convert XML from input file into a dictionary so that it is easy to handle
        if argc != 2:
            raise RuntimeError("Usage wrong")
        xml_path = Path(argv[1]).expanduser()
        logging.info("Opening file: %s", xml_path)
        xml_dict = parsexml(xml_path.read_text(encoding='utf-8'))
        xml_dict_original = deepcopy(xml_dict)

        # validate XML without a schema
        if len(xml_dict) != 1 or "metadata" not in xml_dict or len(xml_dict["metadata"]) != 3 or "groupId" not in xml_dict["metadata"] or "artifactId" not in xml_dict["metadata"] or "versioning" not in xml_dict["metadata"] or "lastUpdated" not in xml_dict["metadata"]["versioning"] or "versions" not in xml_dict["metadata"]["versioning"] or "version" not in xml_dict["metadata"]["versioning"]["versions"]:
            raise RuntimeError("Input not understood")

        # never delete all versions
        if isinstance(xml_dict["metadata"]["versioning"]["versions"]["version"], list):
            # group versions by their major number so that a minimum amount of sub-versions can be retained
            versions_by_major = defaultdict(set)
            for version in xml_dict["metadata"]["versioning"]["versions"]["version"]:
                try:
                    version_parsed = parseversion(version)
                except InvalidVersion:
                    logging.warning("Version not parsable: %s", version)
                else:
                    versions_by_major[version_parsed.major].add(version_parsed)
            for major in sorted(versions_by_major.keys()):
                logging.info("Proceeding with major version: %s", major)

                # keep the 3 highest versions
                versions_sorted = sorted(versions_by_major[major], reverse=True)
                logging.info("Versions to be retained: %s", ' '.join(map(str, versions_sorted[:3])))
                logging.info("Versions to be removed: %s", ' '.join(map(str, versions_sorted[3:])))
                for version_to_be_removed in versions_sorted[3:]:
                    path_to_be_removed = xml_path.parent / str(version_to_be_removed)
                    logging.info("Removing directory: %s", path_to_be_removed)
                    try:
                        rmtree(path_to_be_removed)
                    except FileNotFoundError:
                        logging.warning("File not found: %s", path_to_be_removed)
                        xml_dict["metadata"]["versioning"]["versions"]["version"].remove(str(version_to_be_removed))
                    except NotADirectoryError:
                        logging.warning("Not a directory: %s", path_to_be_removed)
                    else:
                        xml_dict["metadata"]["versioning"]["versions"]["version"].remove(str(version_to_be_removed))
            if xml_dict != xml_dict_original:
                xml_dict["metadata"]["versioning"]["lastUpdated"] = datetime.now().strftime("%Y%m%d%H%M%S")
                logging.info("Updating file: %s", xml_path)
                xml_path.write_text(unparsexml(xml_dict, pretty=True), encoding='utf-8')
        else:
            logging.info("There is only one version, nothing to do.")
    except Exception as exc:
        logging.exception(exc)
        ret = 1
    else:
        ret = 0
    return ret


sys.exit(main(len(sys.argv), sys.argv))

# vim: ts=4 sts=0 sw=4 et
