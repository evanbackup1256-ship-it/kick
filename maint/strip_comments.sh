#!/bin/bash
# Fast comment stripper - single perl pass.
for f in "$@"; do
  [ -f "$f" ] || continue
  perl -i -0777 -pe 's/--\[\[.*?\]\]//gs; s/(?:^|[ \t])--[^\n]*//gm; s/^\s*\n//gm' "$f" 2>/dev/null
done
