const {SelectListView, $, $$} = require("atom-space-pen-views")
const _ = require("underscore-plus")
const CSON = require("season")
const {normalize, isDirectorySync, existsSync} = require("fs-plus")
const Path = require("path")
const fuzzaldrin = require("fuzzaldrin")

const settings = require("./settings")
const {
  isContained,
  isInProjectList,
  someGroupMemberIsLoaded,
  allGroupMemberIsLoaded,
  highlightMatches,
  getNormalDirectories,
  getGitDirectories,
  tildifyHomeDirectory,
} = require("./utils")

module.exports = class View extends SelectListView {
  initialize() {
    super.initialize()
    this.itemsForGroups = []
    this.addClass("project-folder")
    atom.commands.add(this.element, {
      "project-folder:replace": () => this.replace(),
      "project-folder:switch-action": () => this.switchAction(),
      "project-folder:confirm-and-continue": () => this.confirmAndContinue(),
      "project-folder:open-in-new-window": () => this.openInNewWindow(),
      "project-folder:set-to-top-of-projects": () => this.setToTopOfProjects(),
    })

    this.panel = atom.workspace.addModalPanel({item: this, visible: false})
    this.loadConfig()
    return this
  }

  getNormalDirectories() {
    return getNormalDirectories(settings.get("projectRootDirectories"))
  }

  getGitDirectories() {
    const rootDirs = settings.get("gitProjectDirectories")
    const maxDepth = settings.get("gitProjectSearchMaxDepth")
    return getGitDirectories(rootDirs, maxDepth)
  }

  viewForItem(item) {
    // let basename, iconName, name
    const isGroup = item.dirs.length > 1
    const name = item.name
    const iconName = isGroup ? "briefcase" : "repo"
    const basename = isGroup ? name : Path.basename(name)

    const matches = fuzzaldrin.match(name, this.getFilterQuery())
    return $$(function() {
      const baseOffset = name.length - basename.length
      this.li({class: "two-lines"}, () => {
        this.div({class: `primary-line file icon icon-${iconName}`}, () =>
          highlightMatches(this, basename, matches, baseOffset)
        )
        this.div({class: "secondary-line path no-icon"}, () => highlightMatches(this, name, matches))
      })
    })
  }

  getFilterKey() {
    return "name"
  }

  setGroups(groups) {
    this.itemsForGroups = Object.keys(groups).map(name => ({
      name: name,
      dirs: groups[name].map(normalize),
    }))
  }

  getItemsForGroups() {
    return this.itemsForGroups
  }

  getItems() {
    let dirs, groups

    if (this.action === "add") {
      groups = this.getItemsForGroups()
      dirs = _.uniq([...this.getNormalDirectories(), ...this.getGitDirectories()])
      if (settings.get("hideLoadedFolderFromAddList")) {
        groups = _.reject(groups, allGroupMemberIsLoaded)
        dirs = _.reject(dirs, isInProjectList)
      }
    } else if (this.action === "remove") {
      const condition = settings.get("showGroupOnRemoveListCondition")
      if (condition === "never") {
        groups = []
      } else if (condition === "some-member-was-loaded") {
        groups = this.getItemsForGroups().filter(someGroupMemberIsLoaded)
      } else if (condition === "all-member-was-loaded") {
        groups = this.getItemsForGroups().filter(allGroupMemberIsLoaded)
      }
      dirs = atom.project.getPaths()
    }

    dirs = dirs.map(dir => ({
      name: tildifyHomeDirectory(dir),
      dirs: [dir],
    }))
    return [...groups, ...dirs]
  }

  populateList() {
    super.populateList()
    this.removeClass("add remove")
    this.addClass(this.action)
  }

  // action should be 'add' or 'remove'
  start(action) {
    this.action = action
    this.storeFocusedElement()
    this.setItems(this.getItems())
    this.panel.show()
    this.focusFilterEditor()
  }

  // HACK: See #9, #10
  // When confirmAndContinue, it add/remove project-folder while keeping focus on select-list.
  // But adding very first project-folder or removing very last project-folder unwantedly taken-away
  // focus from select-list, this function aggressively regain focus when it's focus was taken-away.
  withKeepFocusOnSelectList(fn) {
    // HACK: By setting this.cancelling to true, `blur` event on @filterEditorView
    // not cause slect-list canceled.
    this.cancelling = true

    fn()

    // When focus was taken-away as a result of project paths manipulation.
    // regain focus to select-list's mini-editor.
    if (!this.filterEditorView.element.hasFocus()) this.filterEditorView.focus()

    this.cancelling = false // Make it cancelable again
  }

  confirmAndContinue() {
    const selectedItem = this.getSelectedItem()
    if (!selectedItem) return

    this.withKeepFocusOnSelectList(() => {
      this[this.action](...selectedItem.dirs)
    })

    this.items = this.getItems()

    // Sync select-list to underlying model(@items)
    this.list.find("li").each((i, element) => {
      const view = $(element)
      const viewItem = view.data("select-list-item")
      const modelExists = this.items.some(item => _.isEqual(item, viewItem))

      if (!modelExists) {
        if (view.hasClass("selected")) this.selectNextItemView()
        view.remove()
      }
    })
  }

  confirmed(item) {
    this[this.action](...item.dirs)
    this.cancel()
  }

  cancelled() {
    // When invoking `tree-view:toggle-focus` for somooth keyboard navigation.
    // It fire `blur` event afterward on @filterEditorView and cancelled called again.
    // This guard useless 2nd cancelled call.
    if (!this.panel.isVisible()) return

    this.action = null
    this.panel.hide()

    // HACK When no focusable item was exists on workspace, focus tree-view for
    // somooth keyboard navigation.
    if (atom.workspace.getCenter().getPaneItems().length) {
      atom.workspace.getActivePane().activate()
    } else {
      const workspaceElement = atom.views.getView(atom.workspace)
      atom.commands.dispatch(workspaceElement, "tree-view:toggle-focus")
    }
  }

  switchAction() {
    this.action = this.action === "add" ? "remove" : "add"
    this.setItems(this.getItems())
  }

  // Add
  // -------------------------
  add(...dirs) {
    dirs.filter(isDirectorySync).forEach(dir => atom.project.addPath(dir))
  }

  // Remove
  // -------------------------
  remove(...dirs) {
    for (const dir of dirs) {
      atom.project.removePath(dir)

      if (settings.get("closeItemsForRemovedProject")) {
        for (const editor of atom.workspace.getTextEditors()) {
          if (editor.getPath() && editor.getPath().startsWith(dir + Path.sep)) {
            editor.destroy()
          }
        }
      }
    }
  }

  // Replace
  // -------------------------
  replace() {
    const item = this.getSelectedItem()
    if (!item) return

    this.add(...item.dirs)
    this.remove(..._.without(atom.project.getPaths(), ...item.dirs))
    this.cancel()
  }

  // Open in new window
  // -------------------------
  openInNewWindow() {
    const item = this.getSelectedItem()
    if (!item) return

    atom.open({
      pathsToOpen: item.dirs.filter(isDirectorySync),
      newWindow: true,
      devMode: atom.inDevMode(),
    })
    this.cancel()
  }

  setToTopOfProjects() {
    const item = this.getSelectedItem()
    if (!item) return

    const loadedDirs = atom.project.getPaths()
    for (const dir of loadedDirs) atom.project.removePath(dir)

    this.add(...item.dirs, ...loadedDirs)
    this.cancel()
  }

  // User config
  // -------------------------
  loadConfig() {
    const config = this.readConfig()
    if (config.groups) this.setGroups(config.groups)
  }

  getConfigPath() {
    return normalize(settings.get("configPath"))
  }

  readConfig() {
    let config = {}

    const filePath = this.getConfigPath()
    if (!existsSync(filePath)) return config

    try {
      config = CSON.readFileSync(filePath) || {}
    } catch (error) {
      atom.notifications.addError("[project-folder] config file has error", {
        detail: error.message,
      })
    }
    return config
  }
}
