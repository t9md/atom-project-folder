{SelectListView, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
path = require 'path'
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
    @panel ?= atom.workspace.addModalPanel(item: this, visible: false)
    this

  viewForItem: (item) ->
    basename = path.basename(item)
    matches = match(basename, @getFilterQuery())
    $$ ->
      @li class: 'two-lines', =>
        @div class: 'primary-line', => View.highlightMatches(this, basename, matches)
        @div item, class: 'secondary-line'

  confirmed: (item) ->
    if @action is 'add'
      atom.project.addPath(item)
    else if @action is 'remove'
      atom.project.removePath(item)
    @cancel()

  populateProjectList: ->
    projectRootDirectories = atom.config.get('project-folder.projectRootDirectories')
    dirs = []
    for dir in projectRootDirectories
      for _path in fs.listSync(fs.normalize(dir)) when fs.isDirectorySync(_path)
        dirs.push _path
    @setItems(dirs)

  populateLoadedProjectList: ->
    dirs = atom.project.getDirectories().map (dir) ->
      dir.path
    @setItems(dirs)

  cancelled: ->
    @action = null
    @panel.hide()

  start: (@action) ->
    @storeFocusedElement()

    switch @action
      when 'add'    then @populateProjectList()
      when 'remove' then @populateLoadedProjectList()

    @panel.show()
    @focusFilterEditor()
