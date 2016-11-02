# project-folder [![Build Status](https://travis-ci.org/t9md/atom-project-folder.svg?branch=master)](https://travis-ci.org/t9md/atom-project-folder)

Quickly add/remove project folder.

![gif](https://raw.githubusercontent.com/t9md/t9md/c9cbeb79d3e8f86fc60efb52e696d4340012e4da/img/atom-project-folder.gif)

# What is this?

Atom provide `application:add-project-folder` to add your project to project list.  
And you can right click and chose `Remove Project Folder` to remove project from list.  
This package enables you to quickly do above actions and provide extra commands to manipulate project list.

# Features

* Quickly add/remove project folder, or open in new window(`ctrl-enter` in select-list)
* Can switch action between `add`/`remove` with `tab` and UI color reflect current action.
* Replace all project folders with selected item(`ctrl-r` in select-list).
* Hide already loaded folders from select list when adding.
* Continuously adding, removing without closing select list(`space` in select-list).
* Find Git project recursively from specified directory.
* User defined project-group(add/remove set of project by defined group).

# Command

* `project-folder:add`: Add project folder.
* `project-folder:remove`: Remove project folder.
* `project-folder:open-config`: Open user-config to define project-group as CSON format.

In mini editor
* `project-folder:replace`: Remove project except selected.
* `project-folder:switch-action`: Switch action 'add' / 'remove'. CSS style changes depending on action add(`blue`), remove(`red`), so that you can understand what you are doing.
* `project-folder:confirm-and-continue`: Confirm action without closing select list, you can continue to add/remove next project folder.
* `project-folder:open-in-new-window`: Open selected project in new window.
* `project-folder:set-to-top-of-projects`: Set selected project to top of project list.

# How to use

Here is training course from Basic(step-1) to step3.

## Basic.

1. Start `project-folder:add` from command palette or from keymap.
2. Chose folder you want to add.
3. Project folder added and listed in tree-view.

## Switch action by `tab`, Confirm and continue with `space`.

1. Start `project-folder:add` from command palette or from keymap.
2. Type `space` key on item you want to add, and continue to add next item with `space`.
3. Then type `tab`, selected items color change to `red` background to indicate action changed to `remove`. Then type `space` to continuously remove folder from project list.

## Replace project list by `ctrl-r`.

1. Start `project-folder:add` from command palette or from keymap.
2. Add multiple folder by typing `space` several times.
3. Then type `ctrl-r` on item you want to replace.
4. Project folders you added on 2. was replaced with only item you just replaced.

## User defined project-group and open it in new-window.

This tutorial assume you've cloned git repositories `atom`, `text-buffer` and `atom-keymap` to `~/github`.

1. From command paletter execute `project-folder:open-config`.
2. Paste following text in opened editor and save it.
```coffeescript
groups:
  atom: [
    "~/github/atom"
    "~/github/text-buffer"
    "~/github/atom-keymap"
  ]
```
3. `project-folder:add`, you can see "atom" group shows up in top of list with different icon.
4. `ctrl-enter` to open `atom` group in new window.
5. Three directories defined in group have opened in new window!(You can also remove set of directories in same way)

# Keymap

Following keymap is defined for project-folder's select-list mini editor.

```coffeescript
'.project-folder atom-text-editor[mini]':
  'ctrl-r': 'project-folder:replace'
  'tab': 'project-folder:switch-action'
  'space': 'project-folder:confirm-and-continue'
  'ctrl-enter': 'project-folder:open-in-new-window'
  'ctrl-t': 'project-folder:set-to-top-of-projects'
```

To start `project-folder:add` or `project-folder:remove`, invoke from command pallete, or set keymap by yourself.

e.g. My setting.(I'm not setting `project-folder:remove` since I can switch to it by `tab`)

```coffeescript
'atom-workspace:not([mini])':
  'cmd-p': 'project-folder:add'
```

# Config

* `projectRootDirectories`: Comma separated list of directries to search project directories.

e.g
`~/.atom/packages, ~/github`

If you want to directly edit `config.cson`, see blow.

```coffeescript
"project-folder":
  projectRootDirectories: [
    "~/.atom/packages"
    "~/github"
  ]
```
