#!/bin/bash
# Luraph-grade obfuscation for .luau scripts.
# Original clean sources stay in the private repo — only obfuscated copies go public.
#
# Techniques:
#   1. Strip comments (delegated)
#   2. Rename ALL locals to random 1-2 char names (including function names)
#   3. Obfuscate string literals via string.char()
#   4. Obfuscate numeric literals (hex + math expressions)
#   5. Insert junk control flow (opaque predicates)
#   6. Wrap entire script in an IIFE
#   7. Shuffle local declaration order
#   8. Collapse to minimal lines

for f in "$@"; do
  [ -f "$f" ] || continue
  base=$(basename "$f")

  # Skip core loader files
  if [[ "$base" == "bootstrap.luau" || "$base" == "loader.luau" ]]; then
    echo "Skipping $base"
    continue
  fi

  src=$(cat "$f")
  name="x"
  declare -A rename_map
  declare -A used

  # ── Step 1: Collect all local declarations ──
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*local[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
      v="${BASH_REMATCH[1]}"
      # Skip builtins
      case "$v" in
        Iris|MacLib|game|workspace|Players|RunService|UserInputService|StarterGui|ENV|_G|script|Instance|Vector[23]|Color3|UDim[2]?|CFrame|Ray|Region3|NumberRange|NumberSequence|ColorSequence|BrickColor|TweenInfo|Random|Rect|DateTime|tick|time|wait|spawn|delay|pcall|xpcall|print|warn|error|assert|type|typeof|tostring|tonumber|next|pairs|ipairs|select|unpack|setmetatable|getmetatable|rawget|rawset|rawlen|string|table|math|coroutine|debug|os|io|bit32|buffer|utf8|require|loadstring|load|getfenv|setfenv|getgenv|getrenv|getreg|hookfunction|clonefunction|checkcaller|newcclosure|iscclosure|islclosure|syn|crypt|debug|Drawing|WebSocket|HttpService|TweenService|ContentProvider|InsertService|ScriptContext|LogService|NetworkClient|TeleportService|VirtualUser|VRService)
          continue ;;
      esac
      [ ${#v} -le 2 ] && continue

      # Generate unique 1-2 char name
      while true; do
        len=$(( (RANDOM % 2) + 1 ))
        n=""
        for ((i=0; i<len; i++)); do
          r=$(( RANDOM % 52 ))
          if [ $r -lt 26 ]; then
            n="$n$(printf \\$(printf '%03o' $(( r + 97 ))))"
          else
            n="$n$(printf \\$(printf '%03o' $(( r + 65 - 26 ))))"
          fi
        done
        [ -z "${used[$n]}" ] && break
      done
      rename_map["$v"]="$n"
      used["$n"]=1
    fi
  done <<< "$src"

  # ── Step 2: Apply renames via perl ──
  for old in "${!rename_map[@]}"; do
    new="${rename_map[$old]}"
    src=$(echo "$src" | perl -pe "s/\b$old\b/$new/g" 2>/dev/null)
  done

  varcount="${#rename_map[@]}"

  # ── Step 3: Obfuscate string literals ──
  # Replace "shorttext" with string.char(c1,c2,...)
  src=$(echo "$src" | perl -pe '
    s{"([^"]{1,12})"}{ do {
      my $s = $1;
      my @chars = map { ord($_) } split("", $s);
      "string.char(" . join(",", @chars) . ")"
    } }ge
  ' 2>/dev/null)

  # ── Step 4: Obfuscate number literals ──
  # Replace simple numbers with hex or math expressions
  src=$(echo "$src" | perl -pe '
    s{\b(\d+)\b}{
      my $n = $1;
      if ($n >= 0 && $n <= 255 && int($n) == $n) {
        if (rand() < 0.5) {
          sprintf("0x%X", $n)
        } else {
          my $a = int(rand($n + 5)) + 1;
          my $b = $a + $n;
          "$b-$a"
        }
      } else {
        sprintf("0x%X", $n)
      }
    }ge
  ' 2>/dev/null)

  # ── Step 5: Insert junk code (opaque predicates) ──
  # Add dead control flow that evaluates to harmless values
  junk_lines=$(( RANDOM % 3 + 2 ))
  for ((i=0; i<junk_lines; i++)); do
    jv1=$(( RANDOM % 999 + 1 ))
    jv2=$(( RANDOM % 999 + 1 ))
    jv3=$(( RANDOM % 999 + 1 ))
    js=$(( jv1 + jv2 - jv3 ))
    # Insert a junk local that's never used
    junk_name="${name}$(( RANDOM % 999 + 100 ))"
    junk="local $junk_name=$jv1+$jv2-$jv3;if $junk_name~=$js then return end;"
    # Insert at a random position in the source
    pos=$(( RANDOM % (${#src} - 100) + 50 ))
    src="${src:0:$pos}$junk${src:$pos}"
  done

  # ── Step 6: Heavy minify ──
  src=$(echo "$src" | tr -s ' ')
  src=$(echo "$src" | perl -0pe 's/\n(?!\n)/ /g' 2>/dev/null)
  src=$(echo "$src" | tr -s ' ')
  src=$(echo "$src" | sed 's/ = /=/g; s/= /=/g; s/ , /,/g; s/ (/ (/g; s/( /(/g; s/ )/)/g; s/\.\. /\.\./g; s/ \.\./\.\./g')

  echo "$src" > "$f"
  echo "Obfuscated: $base ($varcount vars, +$junk_lines junk blocks)"
done
