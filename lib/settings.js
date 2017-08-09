const path = require("path")

function inferType(value) {
  if (Number.isInteger(value)) return "integer"
  if (typeof value === "boolean") return "boolean"
  if (typeof value === "string") return "string"
  if (Array.isArray(value)) return "array"
}

class Settings {
  constructor(scope, config) {
    // Inject order props to display orderd in setting-view
    this.scope = scope
    this.config = config
    const names = Object.keys(this.config)
    for (let i = 0; i < names.length; i++) {
      const name = names[i]
      this.config[name].order = i
    }

    // Automatically infer and inject `type` of each config parameter.
    for (let key in this.config) {
      const value = this.config[key]
      if (value.type == null) {
        value.type = inferType(value.default)
      }
    }
  }

  get(param) {
    return atom.config.get(`${this.scope}.${param}`)
  }

  set(param, value) {
    return atom.config.set(`${this.scope}.${param}`, value)
  }
}

module.exports = new Settings("project-folder", {
  projectRootDirectories: {
    default: [atom.config.get("core.projectHome")],
    items: {
      type: "string",
    },
    description: "Comma separated list of directries to search project dir. e.g `~/.atom/packages, ~/github`",
  },
  gitProjectDirectories: {
    default: [],
    items: {
      type: "string",
    },
    description: "Find git project recursively from directories listed here",
  },
  gitProjectSearchMaxDepth: {
    default: 5,
    min: 0,
  },
  hideLoadedFolderFromAddList: {
    default: true,
    description: "Hide already added folders from list when adding.",
  },
  showGroupOnRemoveListCondition: {
    default: "never",
    enum: ["never", "some-member-was-loaded", "all-member-was-loaded"],
    description: "Control if group item shows up on remove list",
  },
  closeItemsForRemovedProject: {
    default: false,
    description: "close editor when containing project was removed",
  },
  configPath: {
    default: path.join(atom.getConfigDirPath(), "project-folder.cson"),
    description: "filePath for user word group",
  },
})
