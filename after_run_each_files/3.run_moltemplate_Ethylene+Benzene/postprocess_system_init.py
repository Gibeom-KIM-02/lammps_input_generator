#!/usr/bin/env python3
"""
postprocess_system_init.py

Purpose
-------
Post-process Moltemplate-generated system.in.init and remove duplicate
'atom_style ...' lines safely.

Rules
-----
1. Keep the first active 'atom_style ...' line.
2. Remove later duplicate atom_style lines if they use the SAME style.
3. Abort if a later atom_style line uses a DIFFERENT style.
4. Ignore blank lines and comment-only lines.

Usage
-----
python postprocess_system_init.py system.in.init
"""

from pathlib import Path
import sys
import re


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python postprocess_system_init.py system.in.init")

    target = Path(sys.argv[1])

    if not target.exists():
        sys.exit(f"[ERROR] File not found: {target}")

    atom_style_pattern = re.compile(r'^\s*atom_style\s+(\S+)\b')

    lines = target.read_text(encoding="utf-8").splitlines(keepends=True)

    first_atom_style = None
    kept_lines = []
    removed_count = 0

    for lineno, line in enumerate(lines, start=1):
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            kept_lines.append(line)
            continue

        match = atom_style_pattern.match(line)
        if match:
            current_style = match.group(1)

            if first_atom_style is None:
                first_atom_style = current_style
                kept_lines.append(line)
            else:
                if current_style != first_atom_style:
                    sys.exit(
                        "[ERROR] Conflicting atom_style detected in "
                        f"{target} at line {lineno}: "
                        f"first='{first_atom_style}', later='{current_style}'.\n"
                        "Please inspect system.in.init manually."
                    )

                removed_count += 1
            continue

        kept_lines.append(line)

    if first_atom_style is None:
        print(f"[WARN] No atom_style line found in {target}. Nothing changed.")
        return

    target.write_text("".join(kept_lines), encoding="utf-8")

    print(
        f"[DONE] Processed {target}\n"
        f"       kept first atom_style '{first_atom_style}'\n"
        f"       removed {removed_count} duplicate atom_style line(s)"
    )


if __name__ == "__main__":
    main()
