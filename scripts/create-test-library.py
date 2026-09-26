#!/usr/bin/env python3
"""Create a synthetic full-library fixture for the optional import check."""
import argparse
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=False)
for category in ("design", "coding", "content", "business"):
    folder = args.output / category
    folder.mkdir()
    for number in range(13):
        kind = "cheat-sheet" if number == 0 else "prompt"
        title = f"{category.title()} example {number + 1}"
        (folder / f"example-{number + 1:02}.md").write_text(
            f"---\ntitle: {title}\ntype: {kind}\nprimary_category: {category}\n---\n\n# {title}\n\n"
            f"Review synthetic {category} sample {number + 1} and return its relevant observations.\n"
        )
print("Created 52 synthetic entries across four categories, including four cheat sheets.")
