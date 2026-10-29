#!/usr/bin/env python3
"""Reject releases that cannot advance existing Sparkle installations."""
import plistlib
import re
import sys
import xml.etree.ElementTree as ET


def version(value):
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value):
        raise ValueError(f"Invalid numeric build version: {value}")
    parts = tuple(map(int, value.split(".")))
    return parts + (0,) * (3 - len(parts))


def main():
    with open(sys.argv[1], "rb") as stream:
        current = version(str(plistlib.load(stream)["CFBundleVersion"]))
    namespace = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
    published = []
    for item in ET.parse(sys.argv[2]).findall("./channel/item"):
        value = item.findtext(namespace + "version")
        enclosure = item.find("enclosure")
        if value is None and enclosure is not None:
            value = enclosure.get(namespace + "version")
        if value is not None:
            published.append(version(value))
    if not published:
        raise ValueError("Latest published appcast has no build versions.")
    if current <= max(published):
        raise ValueError("CFBundleVersion must exceed every build in the latest published appcast.")
    print("Release build version advances the published update feed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, ET.ParseError, OSError) as error:
        sys.exit(str(error))
