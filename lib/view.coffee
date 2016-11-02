{SelectListView, $, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
{normalize} = fs
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

# Check if contained by deep compaison
isContained = (items, target) ->
  for item in items when _.isEqual(item, target)
    return true
  false

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
    name = item.name
    if item.dirs.length > 1 # isGroup
      iconName = 'briefcase'
      basename = name
    else
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

  setGroups: (@groups) ->
    @itemsForGroups = null # invalidate cache

  getItemsForGroups: ->
    @itemsForGroups ?= do =>
      for name, dirs of @groups when _.isArray(dirs)
        {name, dirs: dirs.map(normalize)}

  getItems: ->
    switch @action
      when 'add'
        groups = @getItemsForGroups()
        dirs = _.uniq([@getNormalDirectories()..., @getGitDirectories()...])

        if settings.get('hideLoadedFolderFromAddList')
          groups = _.reject(groups, @allGroupMemberIsLoaded.bind(this))
          dirs = _.reject(dirs, @isInProjectList.bind(this))

      when 'remove'
        # We show group if at least one dir was loaded from the group.
        groups = @getItemsForGroups().filter(@someGroupMemberIsLoaded.bind(this))
        dirs = atom.project.getPaths()

    home = fs.getHomeDirectory()
    dirs = dirs.map (dir) -> {name: dir.replace(home, '~'), dirs: [dir]}
    [groups..., dirs...]

  getNormalDirectories: ->
    dirs = []
    for rootDir in settings.get('projectRootDirectories')
      for dir in fs.listSync(normalize(rootDir)) when fs.isDirectorySync(dir)
        dirs.push(dir)
    dirs

  getGitDirectories: ->
    maxDepth = settings.get('gitProjectSearchMaxDepth')

    dirs = []
    for dir in settings.get('gitProjectDirectories')
      dir = normalize(dir)
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

  someGroupMemberIsLoaded: (groupItem) ->
    groupItem.dirs.some (dir) =>
      @isInProjectList(dir)

  allGroupMemberIsLoaded: (groupItem) ->
    groupItem.dirs.every (dir) =>
      @isInProjectList(dir)

  isInProjectList: (dir) ->
    normalize(dir) in atom.project.getPaths()

  confirmAndContinue: ->
    selectedItem = @getSelectedItem()
    return unless selectedItem?
    this[@action](selectedItem)

    @items = @getItems()
    # Sync select-list to underlying model(@items)
    @list.find('li').each (i, element) =>
      view = $(element)
      item = view.data('select-list-item')
      unless isContained(@items, item)
        @selectNextItemView() if view.hasClass('selected')
        view.remove()

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
    for dir in item.dirs
      dir = normalize(dir)
      if fs.isDirectorySync(dir)
        atom.project.addPath(dir)

  # Remove
  # -------------------------
  remove: (item) ->
    for dir in item.dirs
      dir = normalize(dir)
      if settings.get('closeItemsForRemovedProject')
        if directory = _.detect(atom.project.getDirectories(), (d) -> d.getPath() is dir)
          # In case group is passed to remove, it might included non existing directory
          # E.g gropus inluding three directory, but one directory is already unloaded.
          editors = atom.workspace.getTextEditors()
          for editor in editors when directory.contains(editor.getPath())
            editor.destroy()

      atom.project.removePath(dir)

  # Replace
  # -------------------------
  replace: ->
    item = @getSelectedItem()
    @add(item)
    for dir in atom.project.getPaths() when dir not in item.dirs
      @remove(name: 'fake', dirs: [dir])
    @cancel()

  # Open in new window
  # -------------------------
  openInNewWindow: ->
    atom.open(pathsToOpen: @getSelectedItem().dirs, newWindow: true)
    @cancel()
