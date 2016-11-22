{SelectListView, $, $$} = require 'atom-space-pen-views'
_ = require 'underscore-plus'
CSON = require 'season'
{normalize, isDirectorySync, existsSync} = require 'fs-plus'
_path = require 'path'
{match} = require 'fuzzaldrin'

settings = require './settings'
{
  isContained
  isInProjectList
  someGroupMemberIsLoaded
  allGroupMemberIsLoaded
  highlightMatches
  getNormalDirectories
  getGitDirectories
  tildifyHomeDirectory
} = require './utils'

module.exports =
class View extends SelectListView
  itemsForGroups: []

  initialize: ->
    super
    @addClass('project-folder')
    atom.commands.add @element,
      'project-folder:replace': => @replace()
      'project-folder:switch-action': => @switchAction()
      'project-folder:confirm-and-continue': => @confirmAndContinue()
      'project-folder:open-in-new-window': => @openInNewWindow()
      'project-folder:set-to-top-of-projects': => @setToTopOfProjects()

    @panel ?= atom.workspace.addModalPanel(item: this, visible: false)
    @loadConfig()
    this

  getNormalDirectories: ->
    getNormalDirectories(settings.get('projectRootDirectories'))

  getGitDirectories: ->
    rootDirs = settings.get('gitProjectDirectories')
    maxDepth = settings.get('gitProjectSearchMaxDepth')
    getGitDirectories(rootDirs, maxDepth)

  viewForItem: (item) ->
    if item.dirs.length > 1 # isGroup
      name = item.name
      iconName = 'briefcase'
      basename = name
    else
      name = item.name
      iconName = 'repo'
      basename = _path.basename(name)

    matches = match(name, @getFilterQuery())
    $$ ->
      baseOffset = name.length - basename.length
      @li class: 'two-lines', =>
        @div {class: "primary-line file icon icon-#{iconName}"}, =>
          highlightMatches(this, basename, matches, baseOffset)
        @div {class: 'secondary-line path no-icon'}, =>
          highlightMatches(this, name, matches)

  getFilterKey: ->
    'name'

  setGroups: (groups) ->
    @itemsForGroups = ({name, dirs: dirs.map(normalize)} for name, dirs of groups)

  getItemsForGroups: ->
    @itemsForGroups

  getItems: ->
    switch @action
      when 'add'
        groups = @getItemsForGroups()
        dirs = _.uniq([@getNormalDirectories()..., @getGitDirectories()...])
        if settings.get('hideLoadedFolderFromAddList')
          groups = _.reject(groups, allGroupMemberIsLoaded)
          dirs = _.reject(dirs, isInProjectList)

      when 'remove', 'removeEverythingButOne'
        switch settings.get('showGroupOnRemoveListCondition')
          when 'never'
            groups = []
          when 'some-member-was-loaded'
            groups = @getItemsForGroups().filter(someGroupMemberIsLoaded)
          when 'all-member-was-loaded'
            groups = @getItemsForGroups().filter(allGroupMemberIsLoaded)
        dirs = atom.project.getPaths()

    dirs = dirs.map (dir) -> {name: tildifyHomeDirectory(dir), dirs: [dir]}
    [groups..., dirs...]

  populateList: ->
    super
    @removeClass('add remove removeEverythingButOne')
    @addClass(@action)

  # @action should be 'add' or 'remove'
  start: (@action) ->
    @storeFocusedElement()
    @setItems(@getItems())
    @panel.show()
    @focusFilterEditor()

  confirmAndContinue: ->
    return unless selectedItem = @getSelectedItem()
    this[@action](selectedItem.dirs...)

    @items = @getItems()
    # Sync select-list to underlying model(@items)
    @list.find('li').each (i, element) =>
      view = $(element)
      item = view.data('select-list-item')
      unless isContained(@items, item)
        @selectNextItemView() if view.hasClass('selected')
        view.remove()

  confirmed: (item) ->
    this[@action](item.dirs...)
    @cancel()

  cancelled: ->
    @action = null
    @panel.hide()

    if atom.workspace.getPaneItems().length
      atom.workspace.getActivePane().activate()
    else
      # For smooth navigation.
      workspaceElement = atom.views.getView(atom.workspace)
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')

  switchAction: ->
    @action = if @action is 'add' then 'remove' else 'add'
    @setItems(@getItems())

  # Add
  # -------------------------
  add: (dirs...) ->
    for dir in dirs when isDirectorySync(dir)
      atom.project.addPath(dir)

  # Remove
  # -------------------------
  remove: (dirs...) ->
    for dir in dirs
      atom.project.removePath(dir)

      if settings.get('closeItemsForRemovedProject')
        editors = atom.workspace.getTextEditors()
        for editor in editors when editor.getPath()?.startsWith?(dir)
          editor.destroy()

  # Remove Everything But One
  # -------------------------
  removeEverythingButOne: (dirs...) ->
    allDirs = atom.project.getPaths()

    for dir in allDirs
      if dirs.some((d) -> d != dir)
        atom.project.removePath(dir)

        if settings.get('closeItemsForRemovedProject')
          editors = atom.workspace.getTextEditors()
          for editor in editors when editor.getPath()?.startsWith?(dir)
            editor.destroy()

  # Replace
  # -------------------------
  replace: ->
    return unless item = @getSelectedItem()

    @add(item.dirs...)
    @remove(_.without(atom.project.getPaths(), item.dirs...)...)
    @cancel()

  # Open in new window
  # -------------------------
  openInNewWindow: ->
    return unless item = @getSelectedItem()

    dirs = item.dirs.filter (dir) -> isDirectorySync(dir)
    atom.open(pathsToOpen: dirs, newWindow: true, devMode: atom.inDevMode())
    @cancel()

  setToTopOfProjects: ->
    return unless item = @getSelectedItem()

    loadedDirs = atom.project.getPaths()
    atom.project.removePath(dir) for dir in loadedDirs
    @add([item.dirs..., loadedDirs...]...)
    @cancel()

  # User config
  # -------------------------
  loadConfig: ->
    config = @readConfig()
    if config.groups?
      @setGroups(config.groups)

  getConfigPath: ->
    normalize(settings.get('configPath'))

  readConfig: ->
    config = {}

    filePath = @getConfigPath()
    return config unless existsSync(filePath)

    try
      config = CSON.readFileSync(filePath) or {}
    catch error
      atom.notifications.addError('[project-folder] config file has error', detail: error.message)
    config
