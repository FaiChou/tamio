#!/usr/bin/env python3
"""Renames catussh / Rayon identifiers to Tamio.

Used once to turn the Rayon tree into Tamio, and again by port-upstream.sh to
rewrite an upstream patch before it is applied here.

    python3 Workflow/Scripts/tamio-rename.py tree [ROOT]   # rename files and contents in place
    python3 Workflow/Scripts/tamio-rename.py text < in > out  # rewrite a patch or any text
"""

import os
import re
import sys

# Order matters: longer and more specific spellings first.
REPLACEMENTS = [
    # Identifiers and URLs.
    ("github.com/mizorewww/catussh", "github.com/missuo/tamio"),
    ("me.mizorewww.rayon", "sb.moe.tamio"),
    ("me.mizorewww.", "sb.moe.tamio."),
    # The deferred iOS app.
    ("MCatusshUITests", "TamioMobileUITests"),
    ("mCatusshUITests", "TamioMobileUITests"),
    ("mCatusshApp", "TamioMobileApp"),
    ("mCatussh", "TamioMobile"),
    # Environment variables and the section markers of the remote probe.
    ("CATUSSH", "TAMIO"),
    # Lower-case where the name is a key, a Unix user or a shell prompt.
    ("catusshKeys", "tamioKeys"),
    ("about.catussh", "about.tamio"),
    ("catussh@ghostty", "tamio@ghostty"),
    ("/home/catussh", "/home/tamio"),
    ('output("catussh")', 'output("tamio")'),
    ("  catussh  ", "  tamio  "),
    ("❯ catussh ", "❯ tamio "),
    # Everything else: types, modules, paths, product name and prose.
    ("Catussh", "Tamio"),
    ("catussh", "Tamio"),
]

# Directory and file names, applied to each path component.
NAME_REPLACEMENTS = [
    ("mCatusshUITests", "TamioMobileUITests"),
    ("mCatusshApp", "TamioMobileApp"),
    ("mCatussh", "TamioMobile"),
    ("Catussh", "Tamio"),
    ("catussh", "Tamio"),
]

SKIP_DIRS = {".git", "DerivedData", ".build", "node_modules", ".swiftpm"}
# Kept verbatim: they credit the projects Tamio comes from.
SKIP_FILES = {"LICENSE", "EULA", "NOTICE.txt", "design.md", "tamio-rename.py", "port-upstream.sh"}


def rewrite(text):
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    return text


def rename_component(name):
    for old, new in NAME_REPLACEMENTS:
        name = name.replace(old, new)
    return name


def is_text(path):
    with open(path, "rb") as handle:
        chunk = handle.read(8192)
    return b"\0" not in chunk


def tree(root):
    changed_files = 0
    for directory, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.endswith(".xcframework")]
        for name in files:
            if name in SKIP_FILES:
                continue
            path = os.path.join(directory, name)
            if os.path.islink(path) or not is_text(path):
                continue
            with open(path, encoding="utf-8", errors="surrogateescape") as handle:
                text = handle.read()
            new = rewrite(text)
            if new != text:
                with open(path, "w", encoding="utf-8", errors="surrogateescape") as handle:
                    handle.write(new)
                changed_files += 1

    # Deepest paths first, so a parent is renamed after its children.
    renamed = 0
    for directory, dirs, files in os.walk(root, topdown=False):
        if any(part in SKIP_DIRS for part in directory.split(os.sep)):
            continue
        for name in files + dirs:
            new_name = rename_component(name)
            if new_name != name:
                os.rename(os.path.join(directory, name), os.path.join(directory, new_name))
                renamed += 1
    print(f"Rewrote {changed_files} files, renamed {renamed} paths.")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "tree":
        tree(sys.argv[2] if len(sys.argv) > 2 else ".")
    elif mode == "text":
        sys.stdout.write(rewrite(sys.stdin.read()))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
