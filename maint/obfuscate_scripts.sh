#!/bin/bash
# Fast Luraph-grade obfuscation - single-pass perl for all transformations.
# Skips bootstrap.luau and loader.luau.

for f in "$@"; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [[ "$base" == "bootstrap.luau" || "$base" == "loader.luau" ]] && echo "Skipping $base" && continue

  size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
  [ "$size" -lt 50 ] && continue

  # Single perl pass: rename vars + obfuscate strings + obfuscate numbers + strip comments + minify
  perl -i -0777 -pe '
    use strict; use warnings;
    my $src = $_;
    my %rename; my %used; my $vc = 0;

    # ── Collect all local declarations ──
    while ($src =~ /^\s*local\s+([a-zA-Z_]\w*)/gm) {
      my $v = $1;
      next if $v =~ /^(Rayfield|game|workspace|Players|RunService|UserInputService|StarterGui|ENV|_G|script|Instance|Vector[23]|Color3|UDim2?|CFrame|Ray|Region3|NumberRange|NumberSequence|ColorSequence|BrickColor|TweenInfo|Random|Rect|DateTime|tick|time|wait|spawn|delay|pcall|xpcall|print|warn|error|assert|type|typeof|tostring|tonumber|next|pairs|ipairs|select|unpack|setmetatable|getmetatable|rawget|rawset|rawlen|string|table|math|coroutine|debug|os|io|bit32|buffer|utf8|require|loadstring|load|getfenv|setfenv|getgenv|getrenv|getreg|hookfunction|clonefunction|checkcaller|newcclosure|iscclosure|islclosure|syn|crypt|Drawing|WebSocket|HttpService|TweenService|ContentProvider|InsertService|ScriptContext|LogService|NetworkClient|TeleportService|VirtualUser|VRService)$/;
      next if length($v) <= 2;
      next if exists $rename{$v};

      my $n;
      while (1) {
        my $len = 1 + int(rand(2));
        $n = join("", map { chr(int(rand(26)) + (rand() < 0.5 ? 97 : 65)) } (1..$len));
        last if !$used{$n}++;
      }
      $rename{$v} = $n;
      $vc++;
    }

    # ── Apply renames ──
    foreach my $old (keys %rename) {
      my $new = $rename{$old};
      $src =~ s/\b\Q$old\E\b/$new/g;
    }

    # ── Remove comments (single-line only, not inside strings) ──
    $src =~ s/--\[\[.*?\]\]//gs;
    $src =~ s/(?:^|[ \t])--[^\n]*//gm;

    # ── Obfuscate short string literals ──
    $src =~ s{"([^"]{1,12})"}{ "string.char(" . join(",", map { ord($_) } split("", $1)) . ")" }ge;

    # ── Obfuscate number literals ──
    $src =~ s{\b(\d+)\b}{
      my $n = $1;
      if ($n >= 0 && $n <= 255) {
        if (rand() < 0.5) { sprintf("0x%X", $n) }
        else { my $a = 1 + int(rand($n+4)); ($a+$n) . "-$a" }
      } else { sprintf("0x%X", $n) }
    }ge;

    # ── Insert junk locals (opaque predicates) ──
    my $junk_count = 1 + int(rand(2));
    for (1..$junk_count) {
      my $jv1 = 1 + int(rand(998));
      my $jv2 = 1 + int(rand(998));
      my $jv3 = 1 + int(rand(998));
      my $js = $jv1 + $jv2 - $jv3;
      my $jn = "j" . int(rand(99999));
      my $junk = "local $jn=$jv1+$jv2-$jv3;if $jn~=$js then return end;";
      my $maxpos = length($src) - 100;
      if ($maxpos < 10) { $maxpos = 10; }
      my $pos = int(rand($maxpos)) + 5;
      substr($src, $pos, 0, $junk);
    }

    # ── Heavy minify ──
    $src =~ s/^\s+//gm;
    $src =~ s/\s+$//gm;
    $src =~ s/\n(?!\n)/ /g;
    $src =~ s/[ \t]+/ /g;
    $src =~ s/\s*=\s*/=/g;
    $src =~ s/\s*,\s*/,/g;
    $src =~ s/\(\s*/\(/g;
    $src =~ s/\s*\)/\)/g;
    $src =~ s/\s*\.\.\s*/\.\./g;

    $_ = $src;
  ' "$f" 2>/dev/null

  echo "Done: $base"
done
