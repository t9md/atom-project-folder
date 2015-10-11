{SelectListView, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
path = require 'path'
_ = require 'underscore-plus'
{match} = require 'fuzzaldrin'

module.exports =
class View extends SelectListView
  # Copied from FuzzzyFinder's and modified a little.
  @highlightMatches: (context, path, matches, offsetIndex=0) ->
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

  initialize: ->
    super
    @addClass('project-folder')
    atom.commands.add @element,
      'project-folder:replace': => @replace()
      'project-folder:switch-action': => @switchAction()
      'project-folder:confirm-and-continue': => @confirmAndContinue()

    @panel ?= atom.workspace.addModalPanel(item: this, visible: false)
    this

  viewForItem: (item) ->
    matches  = match(item, @getFilterQuery())
    basename = path.basename(item)
    $$ ->
      baseOffset = item.length - basename.length
      @li class: 'two-lines', =>
        @div class: "primary-line file icon icon-repo", 'data-name': basename, 'data-path': item, =>
          View.highlightMatches(this, basename, matches, baseOffset)
        @div class: 'secondary-line path no-icon', =>
          View.highlightMatches(this, item, matches)

  getItems: ->
    loadedPaths = atom.project.getPaths()
    switch @action
      when 'remove'
        dirs = loadedPaths
      when 'add'
        dirs = _.uniq @getNormalDirectories().concat(@getGitDirectories())
        if atom.config.get('project-folder.hideLoadedFolderFromAddList')
          dirs = _.reject dirs, (_path) ->
            _path in loadedPaths

    dirs.map (dir) ->
      dir.replace fs.getHomeDirectory(), '~'

  getNormalDirectories: ->
    dirs = []
    for dir in atom.config.get('project-folder.projectRootDirectories')
      dir = fs.normalize dir
      for _path in fs.listSync(dir) when fs.isDirectorySync(_path)
        dirs.push _path
    dirs

  getGitDirectories: ->
    maxDepth = atom.config.get('project-folder.gitProjectSearchMaxDepth')

    dirs = []
    for dir in atom.config.get('project-folder.gitProjectDirectories')
      dir = fs.normalize dir
      return unless fs.isDirectorySync(dir)
      baseDepth = @getPathDepth(dir)
      fs.traverseTreeSync dir, (->), (_path) =>
        if (@getPathDepth(_path) - baseDepth) > maxDepth
          false
        else
          dirs.push _path if @isGitRepository(_path)
          true
    dirs

  getPathDepth: (_path) ->
    _path.split(path.sep).length

  isGitRepository: (_path) ->
    fs.isDirectorySync path.join(_path,'.git')

  showItems: ->
    @setItems @getItems()

  populateList: ->
    super
    @removeClass 'add remove'
    @addClass @action

  start: (@action) ->
    @storeFocusedElement()
    @showItems()
    @panel.show()
    @focusFilterEditor()

  confirmAndContinue: ->
    selectedItem = @getSelectedItem()
    this[@action](selectedItem)

    selectedItemView = @getSelectedItemView()
    @selectNextItemView()
    selectedItemView.remove()
    @items = (item for item in @items when item isnt selectedItem)

  confirmed: (item) ->
    this[@action] item
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

  isDirectoryContain: (directory, file) ->
    file.substr(directory.length)[0] is path.sep

  destroyItemsForProject: (_path) ->
    for editor in atom.workspace.getTextEditors() when @isDirectoryContain(_path, editor.getPath())
      editor.destroy()

  replace: ->
    selected = @getSelectedItem()
    @add selected
    @removeAll except: selected

    @cancel()

  switchAction: ->
    @action = if @action is 'add' then 'remove' else 'add'
    @showItems()

  # Utility
  add: (_path) ->
    atom.project.addPath fs.normalize(_path)

  remove: (_path) ->
    _path = fs.normalize(_path)
    if atom.config.get('project-folder.closeItemsForRemovedProject')
      @destroyItemsForProject _path
    atom.project.removePath _path

  removeAll: ({except}={})->
    except = fs.normalize(except)
    for _path in atom.project.getPaths() when _path isnt except
      @remove _path
