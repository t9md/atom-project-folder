{SelectListView, $, $$} = require 'atom-space-pen-views'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{normalize} = fs
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
} = require './utils'

module.exports =
class View extends SelectListView
  groups: null
  itemsForGroups: null

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

  getNormalDirectories: ->
    getNormalDirectories(settings.get('projectRootDirectories'))

  getGitDirectories: ->
    rootDirs = settings.get('gitProjectDirectories')
    maxDepth = settings.get('gitProjectSearchMaxDepth')
    getGitDirectories(rootDirs, maxDepth)

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
      ({name, dirs: dirs.map(normalize)} for name, dirs of @groups)

  getItems: ->
    switch @action
      when 'add'
        groups = @getItemsForGroups()
        dirs = _.uniq([@getNormalDirectories()..., @getGitDirectories()...])
        if settings.get('hideLoadedFolderFromAddList')
          groups = _.reject(groups, allGroupMemberIsLoaded)
          dirs = _.reject(dirs, isInProjectList)

      when 'remove'
        # We show group if at least one dir was loaded from the group.
        groups = @getItemsForGroups().filter(someGroupMemberIsLoaded)
        dirs = atom.project.getPaths()

    home = fs.getHomeDirectory()
    dirs = dirs.map (dir) -> {name: dir.replace(home, '~'), dirs: [dir]}
    [groups..., dirs...]

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
    for dir in dirs when fs.isDirectorySync(dir)
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

  # Replace
  # -------------------------
  replace: ->
    item = @getSelectedItem()
    @add(item.dirs...)
    @remove(_.without(atom.project.getPaths(), item.dirs...)...)
    @cancel()

  # Open in new window
  # -------------------------
  openInNewWindow: ->
    atom.open(pathsToOpen: @getSelectedItem().dirs, newWindow: true)
    @cancel()
