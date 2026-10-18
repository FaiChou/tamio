#!/usr/bin/env python3
"""Turns one version's notes (Markdown, from release-notes.sh) into the plain
text Sparkle's update window shows.

Sparkle does not render HTML release notes in a Mac Catalyst app; it prints
the markup instead. So the notes go as plain text: "### Files" becomes a line
of its own, "- " a bullet, and links, code and emphasis lose their marks.

Usage: bash release-notes.sh 0.2.0 | python3 plain-notes.py
"""

import re
import sys


def inline(text: str) -> str:
    text = re.sub(r"!?\[([^\]]+)\]\([^)]+\)", r"\1", text)  # [text](url) → text
    text = re.sub(r"(\*\*|__)(.+?)\1", r"\2", text)  # **bold**
    text = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"\1", text)  # *emphasis*
    text = text.replace("`", "")
    return text.strip()


def plain(markdown: str) -> str:
    out: list[str] = []
    headings: set[int] = set()  # lines of out that are headings
    for line in markdown.splitlines():
        heading = re.match(r"\s*#{1,6}\s+(.*)", line)
        bullet = re.match(r"(\s*)[-*+]\s+(.*)", line)
        if heading:
            if out and out[-1] != "":
                out.append("")
            headings.add(len(out))
            # Plain text has no bold: a heading stands out in capitals.
            out.append(inline(heading.group(1)).upper())
        elif bullet:
            depth = len(bullet.group(1).replace("\t", "    ")) // 2
            out.append("   " * depth + "• " + inline(bullet.group(2)))
        elif line.strip():
            out.append(inline(line))
        elif out and out[-1] != "" and len(out) - 1 not in headings:
            # A heading sits right above what it heads.
            out.append("")
    return "\n".join(out).strip()


if __name__ == "__main__":
    print(plain(sys.stdin.read()))
