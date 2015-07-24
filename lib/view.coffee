{SelectListView, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
path = require 'path'
_ = require 'underscore-plus'
{match} = require 'fuzzaldrin'

module.exports =
class View extends SelectListView
  # Copied from symbols-view's SymbolsView class
  @highlightMatches: (context, name, matches, offsetIndex=0) ->
    lastIndex = 0
    matchedChars = [] # Build up a set of matched chars to be more semantic

    for matchIndex in matches
      matchIndex -= offsetIndex
      continue if matchIndex < 0 # If marking up the basename, omit name matches
      unmatched = name.substring(lastIndex, matchIndex)
      if unmatched
        context.span matchedChars.join(''), class: 'character-match' if matchedChars.length
        matchedChars = []
        context.text unmatched
      matchedChars.push(name[matchIndex])
      lastIndex = matchIndex + 1

    context.span matchedChars.join(''), class: 'character-match' if matchedChars.length

    # Remaining characters are plain text
    context.text name.substring(lastIndex)

  initialize: ->
    super
    @addClass('project-folder')
    atom.commands.add @element,
      'project-folder:replace':              => @replace()
      'project-folder:switch-action':        => @switchAction()
      'project-folder:confirm-and-continue': => @confirmAndContinue()

    @panel ?= atom.workspace.addModalPanel(item: this, visible: false)
    this

  viewForItem: (item) ->
    basename = path.basename(item)
    matches = match(basename, @getFilterQuery())
    $$ ->
      @li class: 'two-lines', =>
        @div class: 'primary-line', => View.highlightMatches(this, basename, matches)
        @div item, class: 'secondary-line'

  getItems: ->
    loadedPaths = atom.project.getPaths()
    if @action is 'remove'
      loadedPaths
    else if @action is 'add'
      hideLoadedFolder = atom.config.get('project-folder.hideLoadedFolderFromAddList')

      dirs = []
      for dir in atom.config.get('project-folder.projectRootDirectories')
        for _path in fs.listSync(fs.normalize(dir)) when fs.isDirectorySync(_path)
          continue if hideLoadedFolder and (_path in loadedPaths)
          dirs.push _path
      _.uniq (dirs.concat @getGitDirectories())

  getGitDirectories: ->
    gitProjectDirectories = atom.config.get('project-folder.gitProjectDirectories')
    gitProjectDirectories = gitProjectDirectories.map (dir) -> fs.normalize(dir)
    gitProjectDirectories = gitProjectDirectories.filter (dir) ->
      fs.isDirectorySync(dir)

    maxDepth = atom.config.get('project-folder.gitProjectSearchMaxDepth')
    dirs = []
    for dir in gitProjectDirectories
      baseDepth = @getPathDepth(dir)
      fs.traverseTreeSync dir, (->), (_path) =>
        return false if (@getPathDepth(_path) - baseDepth) > maxDepth
        if @isGitRepository(_path)
          dirs.push _path
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

  replace: ->
    @removeAll()
    @add @getSelectedItem()
    @cancel()

  switchAction: ->
    @action = if @action is 'add' then 'remove' else 'add'
    @showItems()

  # Utility
  add: (_path) ->
    atom.project.addPath _path

  remove: (_path) ->
    atom.project.removePath _path

  removeAll: ->
    for _path in atom.project.getPaths()
      @remove _path
