{SelectListView} = require 'atom-space-pen-views'
fs = require 'fs-plus'
path = require 'path'

module.exports =
class View extends SelectListView
  initialize: ->
    super
    @addClass('overlay from-top')
    @panel ?= atom.workspace.addModalPanel(item: this, visible: false)
    this

  viewForItem: (item) ->
    "<li>#{path.basename(item)}</li>"

  confirmed: (item) ->
    if @action is 'add'
      atom.project.addPath(item)
    else if @action is 'remove'
      atom.project.removePath(item)
    @cancel()

  populateProjectList: ->
    projectHome = atom.config.get('project-folder.projectHome')
    dirs = fs.listSync(projectHome).filter (path) -> fs.isDirectorySync(path)
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
