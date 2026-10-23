#!/bin/sh
# Prints the product maps installed on this machine for the report-problem skill: first one line
# per app with where its problems are filed and its map's folder, read from the front matter of
# the map's index.md; then each map's index.md without its front matter. Not the map's areas,
# which the skill reads as it needs them. With one map, it says the report is about that app.
# With none, it says so, and where they'd go. Always exits 0: without a map, the skill still
# works, it just has less to go on.
#
# The maps are in product-maps/ in the user's Claude folder, ~/.claude unless CLAUDE_CONFIG_DIR
# says otherwise (on Windows, %USERPROFILE%\.claude, which Git Bash calls ~/.claude too): outside
# the skill, so they're installed and updated apart from it, and updating the skill never
# removes them. `product-map publish` writes them there.

maps=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/product-maps

# front_matter <field> <map>: the field's value, unquoted, from the map's front matter between
# +++ lines: app or built_from at its top, or kind, site or space under [tracker]. Empty when it
# has none.
front_matter() {
    awk -v want="$1" '
        NR == 1 { if ($0 != "+++") exit; next }
        $0 == "+++" { exit }
        /^\[/ { table = $0; next }
        {
            split(want, part, ".")
            field = (part[2] == "") ? part[1] : part[2]
            wanted_table = (part[2] == "") ? "" : "[" part[1] "]"
            if (table != wanted_table || index($0, field " = ") != 1) next
            value = substr($0, length(field) + 4)
            if (value ~ /^".*"$/) {
                value = substr(value, 2, length(value) - 2)
                gsub(/\\\\/, "\001", value)
                gsub(/\\"/, "\"", value)
                gsub(/\001/, "\\", value)
            }
            print value
            exit
        }
    ' "$2"
}

# body <map>: the map after its front matter, or all of it when it has none.
body() {
    awk '
        NR == 1 && $0 == "+++" { inside = 1; next }
        inside && $0 == "+++" { inside = 0; next }
        !inside
    ' "$1"
}

count=0
for map in "$maps"/*/index.md "$maps"/*.md; do
    [ -f "$map" ] && count=$((count + 1))
done
if [ "$count" = 0 ]; then
    echo "No product maps are installed in $maps."
    exit 0
fi

index=""
only=""
for map in "$maps"/*/index.md "$maps"/*.md; do
    [ -f "$map" ] || continue
    case $map in
        */index.md) folder=$(dirname "$map") ;;
        *)
            only=$(basename "$map" .md)
            index="$index- $only: its map is from an earlier version of product-map, so none can be filed: install it again. Map: $map.
"
            continue
            ;;
    esac
    app=$(front_matter app "$map")
    space=$(front_matter tracker.space "$map")
    site=$(front_matter tracker.site "$map")
    kind=$(front_matter tracker.kind "$map")
    built=$(front_matter built_from "$map")
    name=${app:-$(basename "$folder")}
    only=$name
    if [ -n "$space" ] && [ -n "$site" ]; then
        line="- $name: problems go to $space at $site${kind:+ ($kind)}. Map: $folder${built:+, built from $built}."
    else
        line="- $name: its map doesn't say where problems go, so none can be filed. Map: $folder."
    fi
    index="$index$line
"
done

if [ "$count" = 1 ]; then
    echo "Only one map is installed, $only's: the report is about $only unless the colleague says otherwise."
else
    echo "$count maps are installed:"
fi
echo
printf '%s' "$index"

for map in "$maps"/*/index.md; do
    [ -f "$map" ] || continue
    folder=$(dirname "$map")
    app=$(front_matter app "$map")
    echo
    echo "=== Product map: ${app:-$(basename "$folder")}, in $folder ==="
    body "$map"
done
exit 0
