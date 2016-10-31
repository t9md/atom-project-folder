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

# Copied & modified from fuzzy-finder's code.
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
  context.text path.substring(lastIndex) # Remaining characters are plain text

module.exports =
class View extends SelectListView
  groups: null

  initialize: ->
    super
    @addClass('project-folder')
    atom.commands.add @element,
      'project-folder:replace': => @replace()
      'project-folder:switch-action': => @switchAction()
      'project-folder:confirm-and-continue': => @confirmAndContinue()
      'project-folder:open-in-new-window': => @openInNewWindow()

    @panel ?= atom.workspace.addModalPanel(item: this, visible: false)
    this

  viewForItem: (item) ->
    matches = match(item.dir, @getFilterQuery())
    iconName = switch item.type
      when 'group' then 'briefcase'
      when 'directory' then 'repo'

    basename = _path.basename(item.dir)
    $$ ->
      baseOffset = item.dir.length - basename.length
      @li class: 'two-lines', =>
        @div {class: "primary-line file icon icon-#{iconName}", 'data-name': basename, 'data-path': item.dir}, =>
          highlightMatches(this, basename, matches, baseOffset)
        @div {class: 'secondary-line path no-icon'}, =>
          highlightMatches(this, item.dir, matches)

  getFilterKey: ->
    "dir"

  setGroups: (@groups) ->
    @itemsForGroups = null # invalidate cache

  getItemsForGroups: ->
    @itemsForGroups ?= do =>
      items = []
      for groupName, dirs of @groups when _.isArray(dirs)
        item = {dir: groupName, type: "group", dirs: dirs}
        items.push(item)
      items

  getItems: ->
    items = []
    items.push(@getItemsForGroups()...)

    loadedDirs = atom.project.getPaths()
    switch @action
      when 'remove'
        dirs = loadedDirs
      when 'add'
        dirs = _.uniq([@getNormalDirectories()..., @getGitDirectories()...])
        if settings.get('hideLoadedFolderFromAddList')
          dirs = _.reject(dirs, (dir) -> dir in loadedDirs)

    homeDir = fs.getHomeDirectory()
    for dir in dirs
      items.push(dir: dir.replace(homeDir, '~'), type: "directory")
    items

  getNormalDirectories: ->
    dirs = []
    for dir in settings.get('projectRootDirectories')
      for path in fs.listSync(fs.normalize(dir)) when fs.isDirectorySync(path)
        dirs.push(path)
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
          dirs.push(path) if isGitRepository(path)
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
    @items = @items.filter (item) -> item isnt selectedItem

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
    switch item.type
      when 'group'
        type = "directory"
        @add({dir, type}) for dir in item.dirs

      when 'directory'
        dir = fs.normalize(item.dir)
        if fs.isDirectorySync(dir)
          atom.project.addPath(dir)

  # Remove
  # -------------------------
  remove: (item) ->
    switch item.type
      when 'group'
        type = "directory"
        @remove({dir, type}) for dir in item.dirs

      when 'directory'
        dir = fs.normalize(item.dir)
        if settings.get('closeItemsForRemovedProject')
          directory = _.detect(atom.project.getDirectories(), (d) -> d.getPath() is dir)
          editors = atom.workspace.getTextEditors()
          for editor in editors when directory.contains(editor.getPath())
            editor.destroy()

        atom.project.removePath(dir)

  # Replace
  # -------------------------
  replace: ->
    item = @getSelectedItem()
    @add(item)

    switch item.type
      when 'directory'
        dirs = [fs.normalize(item.dir)]
      when 'group'
        dirs = (fs.normalize(dir) for dir in item.dirs)

    type = 'directory'
    for dir in atom.project.getPaths() when dir not in dirs
      @remove({dir, type})
    @cancel()

  # Open in new window
  # -------------------------
  openInNewWindow: ->
    item = @getSelectedItem()
    switch item.type
      when 'directory'
        dirs = [fs.normalize(item.dir)]
      when 'group'
        dirs = (fs.normalize(dir) for dir in item.dirs)

    atom.open(pathsToOpen: dirs, newWindow: true)
    @cancel()
