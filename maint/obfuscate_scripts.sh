#!/bin/bash
# Fast single-pass obfuscation -- all transformations in one Perl invocation.
# Skips bootstrap.luau and loader.luau.
# Uses content-hash cache (.obfuscation_cache) to skip unchanged files.
set -e

CACHE_DIR=".obfuscation_cache"
mkdir -p "$CACHE_DIR"

OBFUSCATE_FILES=()

for f in "$@"; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [[ "$base" == "bootstrap.luau" || "$base" == "loader.luau" ]] && echo "Skipping $base" && continue

  size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)
  [ "$size" -lt 50 ] && continue

  # Check cache: skip if unchanged since last obfuscation
  src_hash=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)
  cache_file="$CACHE_DIR/${src_hash}.done"
  if [ -f "$cache_file" ]; then
    echo "Skipping $base (unchanged)"
    continue
  fi

  OBFUSCATE_FILES+=("$f")
done

if [ ${#OBFUSCATE_FILES[@]} -eq 0 ]; then
  echo "No files need obfuscation"
  exit 0
fi

# Process all files in a single Perl invocation
for f in "${OBFUSCATE_FILES[@]}"; do
  base=$(basename "$f")
  size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)

  perl -i -0777 -pe '
    use strict; use warnings;
    my $src = $_;
    return if length($src) < 50;
    my ($version_marker) = $src =~ /local\s+VERSION\s*=\s*"([^"]+)"/;

    my %rename; my %used;

    # Collect and rename local variables (1-2 char names)
    while ($src =~ /^\s*local\s+([a-zA-Z_]\w*)/gm) {
      my $v = $1;
      next if $v =~ /^(game|workspace|Players|RunService|UserInputService|StarterGui|ENV|_G|script|Instance|Vector[23]|Color3|UDim2?|CFrame|Ray|Region3|NumberRange|NumberSequence|ColorSequence|BrickColor|TweenInfo|Random|Rect|DateTime|tick|time|wait|spawn|delay|pcall|xpcall|print|warn|error|assert|type|typeof|tostring|tonumber|next|pairs|ipairs|select|unpack|setmetatable|getmetatable|rawget|rawset|rawlen|string|table|math|coroutine|debug|os|io|bit32|buffer|utf8|require|loadstring|load|getfenv|setfenv|getgenv|getrenv|getreg|hookfunction|clonefunction|checkcaller|newcclosure|iscclosure|islclosure|syn|crypt|Drawing|WebSocket|HttpService|TweenService|ContentProvider|InsertService|ScriptContext|LogService|NetworkClient|TeleportService|VirtualUser|VRService)$/;
      next if length($v) <= 2;
      next if exists $rename{$v};
      my $n;
      while (1) {
        my $len = 1 + int(rand(2));
        $n = join("", map { chr(int(rand(26)) + (rand() < 0.5 ? 97 : 65)) } (1..$len));
        last if !$used{$n}++;
      }
      $rename{$v} = $n;
    }

    foreach my $old (keys %rename) {
      my $new = $rename{$old};
      $src =~ s/\b\Q$old\E\b/$new/g;
    }

    # Remove block and single-line comments
    $src =~ s/--\[\[.*?\]\]//gs;
    $src =~ s/(?:^|[ \t])--[^\n]*//gm;

    # Obfuscate short string literals
    $src =~ s{"([^"]{1,12})"}{ "string.char(" . join(",", map { ord($_) } split("", $1)) . ")" }ge;

    # Obfuscate number literals
    $src =~ s{\b(\d+)\b}{
      my $n = $1;
      if ($n >= 0 && $n <= 255) {
        if (rand() < 0.5) { sprintf("0x%X", $n) }
        else { my $a = 1 + int(rand($n+4)); ($a+$n) . "-$a" }
      } else { sprintf("0x%X", $n) }
    }ge;

    # Insert junk locals (opaque predicates)
    my $junk_count = 1 + int(rand(2));
    for (1..$junk_count) {
      my $maxpos = length($src) - 100;
      next if $maxpos < 10;
      my $jv1 = 1 + int(rand(998));
      my $jv2 = 1 + int(rand(998));
      my $jv3 = 1 + int(rand(998));
      my $js = $jv1 + $jv2 - $jv3;
      my $jn = "j" . int(rand(99999));
      my $junk = "local $jn=$jv1+$jv2-$jv3;if $jn~=$js then return end;";
      my $pos = int(rand($maxpos)) + 5;
      substr($src, $pos, 0, $junk);
    }

    # Heavy minify
    $src =~ s/^\s+//gm;
    $src =~ s/\s+$//gm;
    $src =~ s/\n(?!\n)/ /g;
    $src =~ s/[ \t]+/ /g;
    $src =~ s/\s*=\s*/=/g;
    $src =~ s/\s*,\s*/,/g;
    $src =~ s/\(\s*/\(/g;
    $src =~ s/\s*\)/\)/g;
    $src =~ s/\s*\.\.\s*/\.\./g;

    if (defined $version_marker && $version_marker ne "") {
      $src = "-- ALLERAL_VERSION: $version_marker\n" . $src;
    }

    $_ = $src;
  ' "$f"

  # Mark as processed in cache
  src_hash=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)
  touch "$CACHE_DIR/${src_hash}.done"
  echo "Done: $base ($size bytes)"
done

echo "Obfuscation complete: ${#OBFUSCATE_FILES[@]} file(s) processed"
