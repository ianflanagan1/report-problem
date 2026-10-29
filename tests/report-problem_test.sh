#!/bin/sh
# The report-problem skill: what it may run without asking, and the maps it loads from the
# user's Claude folder. Run with
# tests/run.sh.

root=$(cd "$(dirname "$0")/.." && pwd)
skill=$root/skills/ianf-report-problem/SKILL.md

setUp() {
    sandbox=$(mktemp --directory "${SHUNIT_TMPDIR:-${TMPDIR:-/tmp}}/test.XXXXXX")
    mkdir -p "$sandbox/repo/skills/ianf-report-problem/scripts"
    cp "$root/skills/ianf-report-problem/scripts/maps.sh" "$sandbox/repo/skills/ianf-report-problem/scripts/"
    maps_sh=$sandbox/repo/skills/ianf-report-problem/scripts/maps.sh
    HOME=$sandbox/home
    unset CLAUDE_CONFIG_DIR
    maps=$HOME/.claude/product-maps
}

tearDown() {
    rm -rf "$sandbox"
}

# allows command: whether a Bash rule in the skill's allowed-tools matches the command, as Claude
# Code matches it: "*" matches anything, and a legacy "prefix:*" matches the prefix alone or
# followed by a space.
allows() {
    command=$1
    rules=$(sed -n 's/^allowed-tools: //p' "$skill" | sed 's/, /\
/g' | sed -n 's/^Bash(\(.*\))$/\1/p')
    while IFS= read -r rule; do
        [ -n "$rule" ] || continue
        case $rule in
            *:\*) prefix=${rule%:\*}; set -- "$prefix" "$prefix *" ;;
            *) set -- "$rule" ;;
        esac
        for glob; do
            # shellcheck disable=SC2254  # the rule is a glob
            case $command in $glob) return 0 ;; esac
        done
    done <<RULES
$rules
RULES
    return 1
}

# loading_commands: what the skill runs as it loads, one per line, with CLAUDE_SKILL_DIR filled in
# as a skill linked in from a repository outside the working directory would have it.
loading_commands() {
    # shellcheck disable=SC2016
    sed -n 's/^!`\(.*\)`$/\1/p' "$skill" |
        sed -e 's,${CLAUDE_SKILL_DIR},/home/u/.claude/skills/ianf-report-problem,g'
}

test_colleagues_can_start_it_by_asking_to_report_a_problem() {
    assertFalse "disable-model-invocation is set" "grep --quiet '^disable-model-invocation: true' '$skill'"
}

test_it_runs_inline_on_the_session_model_since_it_interviews_the_colleague() {
    assertTrue "model: inherit" "grep --quiet --line-regexp 'model: inherit' '$skill'"
    assertFalse "context: fork" "grep --quiet '^context: fork' '$skill'"
}

test_every_command_it_runs_as_it_loads_is_allowed() {
    commands=$(loading_commands)
    assertNotNull "it loads the maps" "$commands"
    while IFS= read -r command; do
        assertTrue "not allowed: $command" "allows '$command'"
    done <<COMMANDS
$commands
COMMANDS
}

test_no_path_it_loads_climbs_with_dot_dot() {
    assertFalse "a load-time path has .." "loading_commands | grep --quiet '\.\.'"
}

test_filing_with_jira_is_allowed_and_nothing_else_is() {
    assertTrue "allows '$(printf "jira create 'Orders page shows No results' --tracker '/home/u/.claude/product-maps/shop.md' --stage needs-codebase <<'EOF'\nx\nEOF")'"
    assertTrue "allows 'command -v jira'"
    assertTrue "allows 'jira attach PROJ-12 --session 1d7994f2-5552-4b0c-910c-56025078d493'"
    assertFalse "allows 'jira stage PROJ-1 ready-for-agent'"
    assertFalse "allows 'rm -rf /'"
    assertFalse "allows 'curl https://example.com'"
}

# map name app space: installs a map of app, filed in space, as product-map publishes it: a folder
# with index.md, whose front matter says where problems go, and an area file; with no space, an
# index.md without front matter.
map() {
    mkdir -p "$maps/$1/areas"
    if [ -n "${3:-}" ]; then
        printf '+++\napp = "%s"\nbuilt_from = "v1.0.0, 2026-10-01"\n\n[tracker]\nkind = "jira"\nsite = "example.atlassian.net"\nspace = "%s"\n+++\n\n# %s\n\nAreas of %s.\n' \
            "$2" "$3" "$2" "$2" >"$maps/$1/index.md"
    else
        printf '# %s\n\nAreas of %s.\n' "$2" "$2" >"$maps/$1/index.md"
    fi
    printf '# Orders, in %s\n\nEvery page of orders.\n' "$2" >"$maps/$1/areas/orders.md"
}

test_with_no_maps_it_says_so_and_succeeds() {
    output=$(sh "$maps_sh")
    assertEquals 0 $?
    assertEquals "No product maps are installed in $maps." "$output"
}

test_with_an_empty_maps_folder_it_says_so_and_succeeds() {
    mkdir -p "$maps"
    output=$(sh "$maps_sh")
    assertEquals 0 $?
    assertEquals "No product maps are installed in $maps." "$output"
}

test_with_one_map_it_says_the_report_is_about_that_app() {
    map shop Shop SHOP
    output=$(sh "$maps_sh")
    assertEquals 0 $?
    assertContains "$output" "Only one map is installed, Shop's: the report is about Shop unless the colleague says otherwise."
}

test_with_several_maps_it_names_none_as_the_one() {
    map shop Shop SHOP
    map billing Billing BILL
    output=$(sh "$maps_sh")
    assertContains "$output" "2 maps are installed"
    assertNotContains "$output" "Only one map"
}

test_each_map_is_listed_with_where_its_problems_are_filed() {
    map shop Shop SHOP
    output=$(sh "$maps_sh")
    assertContains "$output" "- Shop: problems go to SHOP at example.atlassian.net (jira). Map: $maps/shop, built from v1.0.0, 2026-10-01."
}

test_a_map_without_front_matter_is_listed_as_one_nothing_can_be_filed_from() {
    map old "Old App"
    output=$(sh "$maps_sh")
    assertContains "$output" "- old: its map doesn't say where problems go, so none can be filed. Map: $maps/old."
}

test_a_single_file_map_of_an_earlier_version_is_listed_as_one_to_install_again() {
    mkdir -p "$maps"
    printf '# Old\n' >"$maps/old.md"
    output=$(sh "$maps_sh")
    assertContains "$output" "- old: its map is from an earlier version of product-map, so none can be filed: install it again. Map: $maps/old.md."
}

test_each_map_s_index_is_printed_under_its_app_without_its_front_matter_or_its_areas() {
    map shop Shop SHOP
    map billing Billing BILL
    output=$(sh "$maps_sh")
    assertContains "$output" "=== Product map: Shop, in $maps/shop ==="
    assertContains "$output" "Areas of Shop."
    assertContains "$output" "=== Product map: Billing, in $maps/billing ==="
    assertNotContains "$output" "Every page of orders."
    assertNotContains "$output" "+++"
    assertNotContains "$output" "built_from ="
}

test_an_app_name_with_quotes_is_read_whole() {
    mkdir -p "$maps/shop"
    printf '+++\napp = "Shop \\"Pro\\""\n\n[tracker]\nsite = "s"\nspace = "S"\n+++\n# x\n' >"$maps/shop/index.md"
    output=$(sh "$maps_sh")
    assertContains "$output" '- Shop "Pro": problems go to S at s'
}

test_maps_follow_claude_config_dir_when_it_is_set() {
    CLAUDE_CONFIG_DIR=$sandbox/config
    export CLAUDE_CONFIG_DIR
    maps=$CLAUDE_CONFIG_DIR/product-maps
    map shop Shop SHOP
    output=$(sh "$maps_sh")
    unset CLAUDE_CONFIG_DIR
    assertContains "$output" "=== Product map: Shop, in $maps/shop ==="
}

test_maps_in_the_skills_own_repository_are_ignored() {
    mkdir -p "$sandbox/repo/maps"
    printf '# Shop\n' >"$sandbox/repo/maps/shop.md"
    output=$(sh "$maps_sh")
    assertNotContains "$output" "Shop"
}

test_it_works_from_any_folder() {
    map shop Shop SHOP
    mkdir -p "$sandbox/elsewhere"
    output=$(cd "$sandbox/elsewhere" && sh "$maps_sh")
    assertContains "$output" "=== Product map: Shop, in $maps/shop ==="
}

# shellcheck disable=SC1090
. "$SHUNIT2"
