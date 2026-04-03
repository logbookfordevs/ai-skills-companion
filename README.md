# AI Skills Companion

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="AI Skills Companion icon">
</p>

<p align="center">
  <strong>Native macOS menu bar companion for <code>skills.sh</code> and your local agent skills</strong><br>
  Search official skills, inspect per-agent installs, and organize your personal skill library from one compact AppKit app.
</p>

## Why This Exists

`skills.sh` is powerful, but the day-to-day experience of remembering commands, checking what is installed where, and browsing your own local skill library is still easier when it lives in the menu bar.

AI Skills Companion gives you:

- a native macOS menu bar interface
- official `skills.sh` search without leaving the app
- quick visibility into skills installed per agent
- a dedicated local `~/.agents/skills` browser
- optional categorization through `skills.json`
- local skill management actions such as disable, re-enable, and move to Trash

### Companion Skill

The app's categorization file is also useful outside the app itself.

If you want agents like Codex, Claude Code, Gemini, Cursor, or other skill-aware tools to use the same taxonomy when they discover skills, install the portable `ai-companion` skill from the [AI Field Kit repo](https://github.com/logbookfordevs/ai-field-kit):

```bash
npx skills add https://github.com/logbookfordevs/ai-field-kit --skill ai-companion
```

That skill reads your existing `~/.agents/skills/skills.json`, uses categories, tags, and platforms as discovery hints, and then quietly hands off to the best matching real skill.

## Quick Start

### Requirements

- macOS
- Swift / Xcode Command Line Tools for building the app
- Node.js with `npx` available if you want the `Hub` and `Per Agent` CLI-backed features
- `skills.sh` available through `npx skills ...`
- Codex CLI available if you want to use `Auto Categorize` in the `Global` tab

### Build

```bash
./build-app.sh
```

### Run

```bash
./launch.sh
```

### Install in Applications

If you want the app to appear in Spotlight, Raycast, Launchpad, and the normal macOS Applications list, copy the built app into `/Applications`:

```bash
cp -r "AI Skills Companion.app" /Applications/
```

After that, you can launch it like any other Mac app without needing to open it from the project folder each time.

### Version Metadata

Build metadata now lives in:

```bash
./version.env
```

This file controls the packaged app version, build number, bundle identifier, and menu bar flag without requiring you to hand-edit the generated `.app` bundle.

### Menu Bar Behavior

- Left click the menu bar icon to open or close the app popover.
- Right click the menu bar icon to open a small menu with `Quit AI Skills Companion`.
- Clicking outside the popover closes it automatically.
- Pressing `Esc` closes the popover too.

### App Updates

AI Skills Companion can check GitHub Releases for a newer version.

- Click `Check for Updates` in the popover header.
- If a newer release exists, the app shows:
  - your current version
  - the latest version
  - a `Download DMG` action
  - an `Open Release` action
- `Download DMG` saves the latest DMG into your Downloads folder and opens it automatically.

To replace the current app cleanly:

1. keep your current app in `/Applications`
2. open the downloaded DMG
3. drag the new `AI Skills Companion.app` into `Applications`
4. choose `Replace` if Finder asks

That replaces the app bundle itself, not your preferences or local skill files.

## What The App Contains

The app has 3 tabs:

- `Hub`
- `Per Agent`
- `Global`

Each tab has a different source of truth and a different job.

## Hub Tab

The `Hub` tab is the `skills.sh` catalog browser.

### What it does

- Searches official skills through the real CLI with `npx skills find <query>`
- Parses structured results from CLI output
- Lets you copy a skill source
- Lets you copy the real install command for a skill or source
- Lets you install directly from:
  - a search result
  - a GitHub shorthand
  - a full URL
  - a local path

### How install works

This app does not try to reimplement the `skills.sh` interactive prompts. Instead, it prepares the real `npx skills add ...` command for you, copies it, and lets you run it in your own terminal.

The expected flow is:

1. choose a skill result or enter a source
2. click the install action
3. the app copies the real install command
4. paste it into your favorite terminal
5. follow the `skills.sh` CLI prompts there

This keeps the upstream CLI flow intact while avoiding fragile terminal-launch behavior from the app.

### Command Output

The `Hub` tab includes a collapsible `Command Output` section so you can inspect the underlying CLI command and output only when you want it.

## Per Agent Tab

The `Per Agent` tab shows skills that already exist inside common agent skill folders.

### Sources it scans

- `~/.agents/skills`
- `~/.codex/skills`
- `~/.claude/skills`
- `~/.gemini/antigravity/skills`

### What it does

- Browses installed skills by source bucket
- Lets you search installed skills with `Search` or `Enter`
- Lets you filter by source using:
  - `All Sources`
  - `Global`
  - `Claude`
  - `Codex`
  - `Anti-Gravity`
- Lets you copy a skill name
- Lets you open the `SKILL.md`
- Lets you open the containing folder

### CLI-backed maintenance actions

The `Per Agent` tab also exposes:

- `Refresh`
- `Check Updates`
- `Update All`

`Check Updates` runs `npx skills check`.

`Update All` runs `npx skills update`.

Like the `Hub` tab, this tab also includes a collapsible `Command Output` section.

## Global Tab

The `Global` tab is your local skill library view for `~/.agents/skills`.

This tab is where the app becomes more than a CLI wrapper. It helps you browse, organize, and manage your own local skills.

### What it does

- Reads local skills from `~/.agents/skills`
- Searches by name and description with `Search` or `Enter`
- Supports optional category grouping through `skills.json`
- Shows category chips when categorization is available
- Can ask Codex to create or update `skills.json` for you
- Keeps disabled skills visible
- Lets you:
  - copy the skill name
  - open `SKILL.md`
  - open the folder
  - disable / re-enable the skill
  - move the skill to Trash

## Local Skill Management

The `Global` tab now supports real file-based management.

### Disable a skill

Disabling a skill moves the folder from:

```bash
~/.agents/skills/<skill-folder>
```

to:

```bash
~/.agents/skills/.disabled/<skill-folder>
```

That means the skill is not only disabled in the app UI. It is also removed from the active skills directory on disk.

### Re-enable a skill

Re-enabling moves the folder back from:

```bash
~/.agents/skills/.disabled/<skill-folder>
```

to:

```bash
~/.agents/skills/<skill-folder>
```

### Delete a skill

The trash button moves the skill folder to the macOS Trash.

This is not an immediate permanent delete from inside the app.

### Disabled skill behavior

Disabled skills:

- stay visible in the `Global` tab
- remain searchable
- remain categorized if `skills.json` maps them
- appear dimmed
- show a disabled state on the card

### Conflict protection

If a disabled skill is restored but a folder with the same name already exists in `~/.agents/skills`, the app blocks the restore instead of overwriting anything.

## Categorization With `skills.json`

If this file exists:

```bash
~/.agents/skills/skills.json
```

the `Global` tab uses it to organize your local skills into categories.

### What the app reads from `skills.json`

The current categorization file supports:

- `scopes`
  - category definitions
  - ordered presentation in the UI
- `skills`
  - per-folder category mappings
  - tags
  - platforms

Skills are matched by folder name, not by display name.

### Category behavior

When `skills.json` loads successfully:

- the `Global` tab groups skills by category
- categories follow the order defined in `scopes`
- category chips appear under the search field
- search still works across name and description
- only matching categories remain visible during filtering
- unmapped skills appear under `Uncategorized`

### If `skills.json` is missing

The app falls back to the normal flat list and shows a highlighted banner that introduces categorization.

That banner includes:

- `Auto Categorize`
- `Categorize`

### If `skills.json` is invalid

The app:

- does not crash
- falls back to the flat list
- shows a caution banner
- offers `Auto Categorize` as a repair path
- still lets you copy the JSON template from the help window

### JSON template help

If you do not have a `skills.json` yet, the app can open a helper modal with:

- a short explanation of what categorization does
- a starter JSON template
- a `Copy JSON Template` action

### Auto Categorize with Codex

If Codex CLI is installed, the `Global` tab can ask Codex to create or update:

```bash
~/.agents/skills/skills.json
```

The app shows `Auto Categorize` when:

- `skills.json` is missing
- `skills.json` is invalid
- valid categorization exists, but some local skills still appear under `Uncategorized`

The app shows `Re-categorize` when:

- `skills.json` is valid
- every discovered local skill is already categorized
- you want Codex to rethink the existing grouping with new guidance

When you run `Auto Categorize`, the app:

- runs `codex exec` directly from the app
- points Codex at `~/.agents/skills`
- asks Codex to preserve existing scopes and mappings
- asks Codex to append only missing skills
- allows Codex to create a new scope only if existing scopes are clearly a poor fit
- includes both active and disabled skills in the categorization pass

When you run `Re-categorize`, the app:

- runs the same `codex exec` flow directly from the app
- points Codex at `~/.agents/skills`
- asks Codex to reconsider existing skill-to-scope mappings using your latest guidance
- keeps the JSON schema valid and ensures every discovered skill is still represented
- preserves useful existing scopes when they still fit naturally

Before the run starts, the `Global` tab keeps the confirmation inside the popover instead of opening a separate system alert. That way, the user can stay in context and immediately inspect the run feedback in the same screen.

That confirmation step also includes an optional custom-instruction field for one-off guidance such as:

- `Keep Stitch skills together, but leave shadcn-ui inside Frontend.`
- `Put all of my ShadCN skills in a dedicated group.`

Those instructions apply to both flows:

- `Auto Categorize` uses them while filling in missing or broken categorization
- `Re-categorize` uses them while revising an already valid taxonomy

The `Global` tab also includes a collapsible `Auto Categorize Output` section. It expands during a run and streams Codex output live so the app does not feel frozen while categorization is in progress.

## Local File Layout

### Active local skills

```bash
~/.agents/skills/
```

### Disabled local skills

```bash
~/.agents/skills/.disabled/
```

### Optional categorization file

```bash
~/.agents/skills/skills.json
```

## Design Notes

The UI is intentionally compact and native.

Important design choices:

- AppKit-based instead of web-wrapped UI
- menu bar first
- command output hidden behind accordions unless needed
- real `skills.sh` install flow preserved instead of cloned
- local `Global` tab separated from CLI-backed views

## Current Limitations

- The app does not embed a terminal emulator.
- Hub installs still rely on the real `skills.sh` CLI flow, but the app now copies the command instead of opening a terminal for you.
- The `Per Agent` tab is inspection and update oriented, not local file management oriented.
- Category grouping currently applies only to the `Global` tab.
- `Auto Categorize` depends on the local Codex CLI being installed and available to GUI apps.
- The app expects the local Swift toolchain and SDK to be aligned for successful builds.

## Troubleshooting

### Hub search or install is unavailable

This usually means GUI-launched apps cannot resolve `npx`.

Check that Node.js is installed and that the app can find `npx`.

### The app copied an install command but nothing happened yet

That is expected. Paste the copied command into your own terminal and follow the `skills.sh` prompts there.

### A skill cannot be restored

The most likely reason is a folder name conflict in `~/.agents/skills`.

### Auto Categorize is unavailable or fails

This usually means the app could not find `codex`, or the Codex run could not write a valid `skills.json`.

Open the `Auto Categorize Output` section in the `Global` tab to inspect the command, stdout, stderr, and exit code.

### `swift test` fails in this environment

If your local toolchain cannot import `XCTest`, align Xcode / Command Line Tools first, then rerun tests.

## Development Validation

Recommended validation commands:

```bash
swift test
./build-app.sh
./compile_and_run.sh
```

The packaged app is generated as:

```bash
AI Skills Companion.app
```

To install that build into `/Applications`:

```bash
cp -r "AI Skills Companion.app" /Applications/
```

## Screenshots

Use this section for product prints and visual walkthroughs.

### Menu Bar

Add your menu bar icon / popover overview screenshot here.

![Menu Bar Overview](docs/screenshots/menu-bar-overview.png)


### Hub Tab

Add a Hub catalog search screenshot here.

![Hub Tab](docs/screenshots/official-tab.png)

### Per Agent Tab

Add an installed-per-agent screenshot here.

![Per Agent Tab](docs/screenshots/per-agent-tab.png)

### Global Tab

Add a categorized global skills screenshot here.

![Skills Tab](docs/screenshots/skills-tab.png)

### Categorization Banner / Auto Categorize

Add the categorization banner, modal, or Codex output screenshot here.

![Auto Categorize](docs/screenshots/auto-categorize.png)

### Categorization Banner / Modal

Add the categorization onboarding banner or JSON template modal here.

![Categorization Help](docs/screenshots/categorization-help.png)

## Logbook for Devs

**A tool from the [Logbook for Devs](https://logbookfordevs.com/)**

*Charting the technical seas, one commit at a time.*

## Support Logbook for Devs

If this project is useful to you, you can support more tools like this here:

- [Buy me a coffee on Ko-fi](https://ko-fi.com/logbookfordevs?amount=5)
- [Buy me lunch on Ko-fi](https://ko-fi.com/logbookfordevs?amount=15)
- [Buy me dinner on Ko-fi](https://ko-fi.com/logbookfordevs?amount=30)
- [Support Logbook for Devs on Ko-fi](https://ko-fi.com/logbookfordevs)
- [Support Logbook for Devs on Buy Me a Coffee](https://buymeacoffee.com/logbookfordevs)
