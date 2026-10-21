# report-problem

A Claude Code plugin for colleagues to report a problem with one of our apps, or ask for a change, as a Jira issue a developer can work from without coming back to ask. Say what went wrong, or run `/report-problem`: Claude asks about what you saw and did, never about code, and files it at the `needs-codebase` stage, for a developer to refine.

With an app's **product map** installed, Claude knows the app's pages, buttons and messages, and offers them as answers, in the words on its screens, such as the pages to choose from or the message it showed. It also knows what changes the app's behaviour, such as being logged in, so it asks about that. And the map says where the app's problems are filed. Without one, Claude asks the same things in your own words and writes the report for you to paste into Jira, since nothing else says where it goes.

## Install

Once, in Claude Code:

```
/plugin marketplace add ianflanagan1/claude-report-problem
/plugin install report-problem@report-problem
```

Then turn on auto-update for the marketplace in `/plugin`, under Marketplaces, so changes to the skill arrive by themselves. To install it for everyone, add the marketplace and the plugin to the team's managed settings (`extraKnownMarketplaces` and `enabledPlugins`) instead.

Then install the maps of the apps you report on, below: the plugin has none.

## Filing

Issues go where the app's map says, in its front matter: the site and space of the `[tracker]` table in the app's `.workspace.toml`, the same place the team's own issues go. Claude files with the `jira` command from jira-tools, if it's installed, as `jira create --workspace <map>`; otherwise with a Jira connector, such as Atlassian's, if you have one; otherwise it gives you the issue to paste into Jira. Without a map for the app, it isn't filed: it gives you the issue to paste.

On Windows, file with a Jira connector: the `jira` command's sign-in reads its API token from the macOS keychain or Linux's Secret Service, and doesn't yet read Windows Credential Manager, so it stops saying credentials aren't supported there. Developers then refine it with jira-tools' `/jira-refine`, which compares it with the code and, once a developer approves it, makes it `ready-for-agent`.

## Maps

A map is private to the app it describes, so it isn't part of this plugin, which is public and has none. Each is a folder, `<app>/`, in the `product-maps` folder in Claude Code's own folder, read each time the skill runs: add, replace or remove one there and the next report uses it, with no change to the plugin. Claude reads a map's `index.md` as the skill starts, then only the areas of the app a report is about, as it would read a codebase, so a large app's map doesn't fill its context.

| System | Folder |
|---|---|
| macOS | `~/.claude/product-maps/`, that is `/Users/<you>/.claude/product-maps/` |
| Linux | `~/.claude/product-maps/`, that is `/home/<you>/.claude/product-maps/` |
| Windows | `%USERPROFILE%\.claude\product-maps\`, that is `C:\Users\<you>\.claude\product-maps\` |

With `CLAUDE_CONFIG_DIR` set, it's `product-maps` in that folder instead. The skill reads the folder with a POSIX shell script, which on Windows runs in Git Bash, as Claude Code's commands do there.

With one map installed, Claude takes the report to be about that app unless you say otherwise. With several, it works out which from what you say, and asks when it can't tell.

Don't edit them: each app's CI builds its map with [product-map](https://github.com/ianflanagan1/product-map) into the app's repository, where it's reviewed with the code. `product-map publish ~/.claude/product-maps` in the app's repository installs it on your machine; to install it on a colleague's, give them the app's folder, `docs/product-map/map/` in its repository, to put in their own `product-maps` folder, above, named as `publish` names it.

## Development

```sh
devbox run test    # shunit2
devbox run lint    # shellcheck
```
