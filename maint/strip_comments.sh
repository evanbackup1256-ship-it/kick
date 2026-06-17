#!/bin/bash
# Strip comments from .luau files for public release.
# Pure bash/sed - no Lua dependency.

for f in "$@"; do
  [ -f "$f" ] || continue

  # 1. Remove block comments: --[[ ... ]]
  # Handles multi-line and single-line block comments
  perl -i -0pe 's/--\[\[.*?\]\]//gs' "$f" 2>/dev/null

  # 2. Remove single-line comments (-- to end of line)
  # Only removes comments that start with -- preceded by whitespace or start of line
  # This is imperfect for strings containing -- but good enough for obfuscation
  perl -i -pe 's/(^|[ \t])--[^\n]*/\1/g' "$f" 2>/dev/null

  # 3. Remove lines that are only whitespace after comment stripping
  sed -i '/^\s*$/d' "$f"

  echo "Stripped: $f"
done
