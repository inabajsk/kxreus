#!/usr/bin/env python3
"""Pull the named onboard motion-table slots out of a Heart to Heart project.

A .h4p is XML: each <DictionaryEntry><Value xsi:type="Motion"> holds a
<Number> (the RCB-4 motion-table slot, 0..119) and a <Name>. Most of the 120
slots are never renamed by the operator and stay "M001".."M120" -- those are
factory-empty and not worth putting in front of an operator, so only entries
whose name does NOT match that placeholder pattern are kept.

Usage:
    motions_from_h4p.py "Hello_KXR-L4D(V1.0).h4p" > motions.txt

Prints one `{n, "name"},` line per kept motion, in slot order, ready to paste
into a kMotions[] C array (see lib/policy/policy.cpp's kActors[] neighbour).
Escapes double quotes and backslashes; does not otherwise touch the name, so
Japanese text goes through as UTF-8 (matches the page's own <meta charset>).
"""
import argparse
import re
import sys


def extract(path):
    text = open(path, encoding="utf-8").read()
    entries = re.findall(
        r'<Value xsi:type="Motion">\s*<Number>(\d+)</Number>\s*<Name>(.*?)</Name>',
        text, re.S)
    out = []
    for num, name in entries:
        if re.fullmatch(r"M\d+", name):
            continue  # untouched placeholder -- factory-empty slot
        # H4P's own naming convention repeats the slot number inside the name
        # itself (e.g. "XL4D_101_..." for slot 0) -- redundant once the slot
        # number is already a separate field the UI shows, so stripped.
        name = re.sub(r"^X[A-Z0-9]+_\d+_", "", name)
        out.append((int(num), name))
    return sorted(out)


def c_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("h4p")
    args = ap.parse_args()
    motions = extract(args.h4p)
    print(f"// {len(motions)} named motions extracted from {args.h4p}", file=sys.stderr)
    for num, name in motions:
        print(f'    {{{num}, "{c_escape(name)}"}},')


if __name__ == "__main__":
    main()
