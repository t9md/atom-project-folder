## 1.1.0
- Improve: `confirm-and-continue` immediately sync select-list item to underlying model.
  - e.g. When all directory was removed from project-list, immediately remove corresponding group from select-list.
- New: `set-to-top-of-projects`(`ctrl-t` in select-list) command to move selectedItem to top-of-project-list.

## 1.0.0
- New: Support user defined project-group(add/remove set of project). See README.md for how-to-use. #5

## 0.2.0
- New: New `project-folder:open-in-new-window` command mapped to `ctrl-enter` by default.

## 0.1.9 - FIX
- Fix: Do nothing when not item was selected. #2

## 0.1.8 - FIX
- [FIX] Replace was not worked for new project(not listed project list).

## 0.1.7 - Improve
- Add spec
- Minor refactoring

## 0.1.6 - FIX
- Replace home directory to `~` wasn'nt implemented on delete list.
- Refactoring.

## 0.1.5 - FIX
- Loaded folder not hidden for Git directory.

## 0.1.4 - Improve
- Replace home directory to `~`.
- New gif on README.md

## 0.1.3 - Find Git project recursively
- New config `gitProjectDirectories` and `gitProjectSearchMaxDepth`.

## 0.1.2 - Greatly improved.
- replace, confirm-and-continue, switch-action introduced.
- Now style change on action switched.
- Update doc.

## 0.1.1 - Improve
- Search project directories from multiple directories.
- Highlight matching query text(copied from symbols-view).

## 0.1.0 - First Release
* Every feature added
* Every bug fixed
