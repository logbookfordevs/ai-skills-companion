# My Agent Skills

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="My Agent Skills icon">
</p>

<p align="center">
  <strong>Native macOS menu bar companion for <code>skills.sh</code> and your local agent skills</strong><br>
  Search official skills, inspect per-agent installs, and organize your personal skill library from one compact AppKit app.
</p>

## Why This Exists

`skills.sh` is powerful, but the day-to-day experience of remembering commands, checking what is installed where, and browsing your own local skill library is still easier when it lives in the menu bar.

My Agent Skills gives you:

- a native macOS menu bar interface
- official `skills.sh` search without leaving the app
- quick visibility into skills installed per agent
- a dedicated local `~/.agents/skills` browser
- optional categorization through `skills.json`
- local skill management actions such as disable, re-enable, and move to Trash

## Quick Start

### Requirements

- macOS
- Swift / Xcode Command Line Tools for building the app
- Node.js with `npx` available if you want the `Official` and `Per Agent` CLI-backed features
- `skills.sh` available through `npx skills ...`

### Build

```bash
swift build
./build-app.sh
```

### Run

```bash
open "My Agent Skills.app"
```

### Menu Bar Behavior

- Left click the menu bar icon to open or close the app popover.
- Right click the menu bar icon to open a small menu with `Quit My Agent Skills`.
- Clicking outside the popover closes it automatically.
- Pressing `Esc` closes the popover too.

## What The App Contains

The app has 3 tabs:

- `Official`
- `Per Agent`
- `Skills`

Each tab has a different source of truth and a different job.

## Official Tab

The `Official` tab is the `skills.sh` catalog browser.

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

The `Official` tab includes a collapsible `Command Output` section so you can inspect the underlying CLI command and output only when you want it.

## Per Agent Tab

The `Per Agent` tab shows skills that already exist inside common agent skill folders.

### Sources it scans

- `~/.agents/skills`
- `~/.codex/skills`
- `~/.claude/skills`
- `~/.gemini/antigravity/skills`

### What it does

- Browses installed skills by source bucket
- Lets you search installed skills
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

Like the `Official` tab, this tab also includes a collapsible `Command Output` section.

## Skills Tab

The `Skills` tab is your local skill library view for `~/.agents/skills`.

This tab is where the app becomes more than a CLI wrapper. It helps you browse, organize, and manage your own local skills.

### What it does

- Reads local skills from `~/.agents/skills`
- Searches by name and description
- Supports optional category grouping through `skills.json`
- Shows category chips when categorization is available
- Keeps disabled skills visible
- Lets you:
  - copy the skill name
  - open `SKILL.md`
  - open the folder
  - disable / re-enable the skill
  - move the skill to Trash

## Local Skill Management

The `Skills` tab now supports real file-based management.

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

- stay visible in the `Skills` tab
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

the `Skills` tab uses it to organize your local skills into categories.

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

- the `Skills` tab groups skills by category
- categories follow the order defined in `scopes`
- category chips appear under the search field
- search still works across name and description
- only matching categories remain visible during filtering
- unmapped skills appear under `Uncategorized`

### If `skills.json` is missing

The app falls back to the normal flat list and shows a highlighted banner that introduces categorization.

That banner includes a `Categorize` button.

### If `skills.json` is invalid

The app:

- does not crash
- falls back to the flat list
- shows a caution banner
- still lets you copy the JSON template from the help window

### JSON template help

If you do not have a `skills.json` yet, the app can open a helper modal with:

- a short explanation of what categorization does
- a starter JSON template
- a `Copy JSON Template` action

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
- local `Skills` tab separated from CLI-backed views

## Current Limitations

- The app does not embed a terminal emulator.
- Official installs still rely on the real `skills.sh` CLI flow, but the app now copies the command instead of opening a terminal for you.
- The `Per Agent` tab is inspection and update oriented, not local file management oriented.
- Category grouping currently applies only to the `Skills` tab.
- The app expects the local Swift toolchain and SDK to be aligned for successful builds.

## Troubleshooting

### Official search or install is unavailable

This usually means GUI-launched apps cannot resolve `npx`.

Check that Node.js is installed and that the app can find `npx`.

### The app copied an install command but nothing happened yet

That is expected. Paste the copied command into your own terminal and follow the `skills.sh` prompts there.

### A skill cannot be restored

The most likely reason is a folder name conflict in `~/.agents/skills`.

### `swift test` fails in this environment

If your local toolchain cannot import `XCTest`, align Xcode / Command Line Tools first, then rerun tests.

## Development Validation

Recommended validation commands:

```bash
swift build
swift test
./build-app.sh
```

The packaged app is generated as:

```bash
My Agent Skills.app
```

## Screenshots

Use this section for product prints and visual walkthroughs.

### Menu Bar

Add your menu bar icon / popover overview screenshot here.

```md
![Menu Bar Overview](docs/screenshots/menu-bar-overview.png)
```

### Official Tab

Add an official catalog search screenshot here.

```md
![Official Tab](docs/screenshots/official-tab.png)
```

### Per Agent Tab

Add an installed-per-agent screenshot here.

```md
![Per Agent Tab](docs/screenshots/per-agent-tab.png)
```

### Skills Tab

Add a categorized local skills screenshot here.

```md
![Skills Tab](docs/screenshots/skills-tab.png)
```

### Categorization Banner / Modal

Add the categorization onboarding banner or JSON template modal here.

```md
![Categorization Help](docs/screenshots/categorization-help.png)
```
