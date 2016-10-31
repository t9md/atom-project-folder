{SelectListView, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
_ = require 'underscore-plus'
_path = require 'path'
{match} = require 'fuzzaldrin'

settings = require './settings'

# Utils
# -------------------------
getPathDepth = (path) ->
  path.split(_path.sep).length

isGitRepository = (path) ->
  fs.isDirectorySync _path.join(path, '.git')

highlightMatches = (context, path, matches, offsetIndex=0) ->
  lastIndex = 0
  matchedChars = [] # Build up a set of matched chars to be more semantic

  for matchIndex in matches
    matchIndex -= offsetIndex
    continue if matchIndex < 0 # If marking up the basename, omit path matches
    unmatched = path.substring(lastIndex, matchIndex)
    if unmatched
      context.span matchedChars.join(''), class: 'character-match' if matchedChars.length
      matchedChars = []
      context.text unmatched
    matchedChars.push(path[matchIndex])
    lastIndex = matchIndex + 1

  context.span matchedChars.join(''), class: 'character-match' if matchedChars.length
  # Remaining characters are plain text
  context.text path.substring(lastIndex)

class View extends SelectListView
  groups: null

  # Copied from FuzzzyFinder's and modified a little.
  initialize: ->
    super
    @addClass('project-folder')
    atom.commands.add @element,
      'project-folder:replace': => @replace()
      'project-folder:switch-action': => @switchAction()
      'project-folder:confirm-and-continue': => @confirmAndContinue()
      'project-folder:open-in-new-window': => @openInNewWindow()

    @panel ?= atom.workspace.addModalPanel({item: this, visible: false})
    this

  viewForItem: (item) ->
    {itemPath, itemType} = item
    matches  = match(itemPath, @getFilterQuery())
    iconName = switch itemType
      when 'group' then 'briefcase'
      when 'directory' then 'repo'

    basename = _path.basename(itemPath)
    $$ ->
      baseOffset = itemPath.length - basename.length
      @li class: 'two-lines', =>
        @div {class: "primary-line file icon icon-#{iconName}", 'data-name': basename, 'data-path': itemPath}, =>
          highlightMatches(this, basename, matches, baseOffset)
        @div {class: 'secondary-line path no-icon'}, =>
          highlightMatches(this, itemPath, matches)

  getFilterKey: ->
    "itemPath"

  setGroups: (@groups) ->
    @itemsForGroups = null

  getItemsForGroups: ->
    return @itemsForGroups if @itemsForGroups?

    items = []
    for groupName, dirs of @groups when _.isArray(dirs)
      item = {itemPath: groupName, itemType: "group", dirs: dirs}
      items.push(item)
    @itemsForGroups = items

  getItems: ->
    loadedPaths = atom.project.getPaths()
    items = []
    items.push(@getItemsForGroups()...)

    switch @action
      when 'remove'
        dirs = loadedPaths
      when 'add'
        dirs = _.uniq @getNormalDirectories().concat(@getGitDirectories())
        if settings.get('hideLoadedFolderFromAddList')
          dirs = _.reject(dirs, (path) -> path in loadedPaths)

    for dir in dirs
      item = {itemPath: dir.replace(fs.getHomeDirectory(), '~'), itemType: "directory"}
      items.push(item)
    items

  getNormalDirectories: ->
    dirs = []
    for dir in settings.get('projectRootDirectories')
      for path in fs.listSync(fs.normalize(dir)) when fs.isDirectorySync(path)
        dirs.push path
    dirs

  getGitDirectories: ->
    maxDepth = settings.get('gitProjectSearchMaxDepth')

    dirs = []
    for dir in settings.get('gitProjectDirectories')
      dir = fs.normalize(dir)
      continue unless fs.isDirectorySync(dir)

      baseDepth = getPathDepth(dir)
      fs.traverseTreeSync dir, (->), (path) ->
        if (getPathDepth(path) - baseDepth) > maxDepth
          false
        else
          dirs.push path if isGitRepository(path)
          true
    dirs

  populateList: ->
    super
    @removeClass('add remove')
    @addClass(@action)

  # @action should be 'add' or 'remove'
  start: (@action) ->
    @storeFocusedElement()
    @setItems(@getItems())
    @panel.show()
    @focusFilterEditor()

  confirmAndContinue: ->
    selectedItem = @getSelectedItem()
    return unless selectedItem?
    this[@action](selectedItem)

    selectedItemView = @getSelectedItemView()
    @selectNextItemView()
    selectedItemView.remove()
    @items = (item for item in @items when item isnt selectedItem)

  confirmed: (item) ->
    this[@action](item)
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
  add: (item) ->
    switch item.itemType
      when 'directory' then @addProject(item.itemPath)
      when 'group' then @addProject(dir) for dir in item.dirs

  addProject: (directory) ->
    directory = fs.normalize(directory)
    if fs.isDirectorySync(directory)
      atom.project.addPath(directory)

  # Remove
  # -------------------------
  remove: (item) ->
    switch item.itemType
      when 'directory' then @removeProject(item.itemPath)
      when 'group' then @removeProject(dir) for dir in item.dirs

  removeProject: (directory) ->
    directory = fs.normalize(directory)
    if settings.get('closeItemsForRemovedProject')
      dir = _.detect(atom.project.getDirectories(), (d) -> d.getPath() is directory)
      for e in atom.workspace.getTextEditors() when dir.contains(e.getPath())
        e.destroy()

    atom.project.removePath(directory)

  # Replace
  # -------------------------
  replace: ->
    selected = @getSelectedItem()
    @add(selected)

    itemPaths = switch selected.itemType
      when 'directory' then [fs.normalize(selected.itemPath)]
      when 'group' then (fs.normalize(dir) for dir in selected.dirs)

    for loadedProjectPath in atom.project.getPaths() when loadedProjectPath not in itemPaths
      item = {itemPath: loadedProjectPath, itemType: "directory"}
      @remove(item)
    @cancel()

  # Open in new window
  # -------------------------
  openInNewWindow: ->
    selected = @getSelectedItem()
    itemPaths = switch selected.itemType
      when 'directory' then [fs.normalize(selected.itemPath)]
      when 'group' then (fs.normalize(dir) for dir in selected.dirs)

    atom.open(pathsToOpen: itemPaths, newWindow: true)
    @cancel()

module.exports = View
