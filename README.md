# project-folder

Quickly add/remove project folder.

# Command

* `project-folder:add`
* `project-folder:remove`

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
