{CompositeDisposable} = require 'atom'

config =
  projectRootDirectories:
    order: 1
    type: 'array'
    items:
      type: 'string'
    default: [atom.config.get('core.projectHome')]
    description: 'Comma separated list of directries to search project dir. e.g `~/.atom/packages, ~/github`'
  gitProjectDirectories:
    order: 2
    type: 'array'
    items:
      type: 'string'
    default: []
    description: 'Find git project recursively from directories listed here'
  gitProjectSearchMaxDepth:
    order:   3
    type:    'integer'
    min:     0
    default: 5
  hideLoadedFolderFromAddList:
    order: 4
    type: 'boolean'
    default: true
    description: 'Hide already added folders from list when adding.'
  closeAllPaneItemsOnReplace:
    order: 5
    type: 'boolean'
    default: true
    description: 'Close all pane items on replace'

module.exports =
  config: config
  subscriptions: null
  view: null

  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'project-folder:add':    => @getView().start('add')
      'project-folder:remove': => @getView().start('remove')

  deactivate: ->
    @subscriptions.dispose()
    @subscriptions = null
    @view?.destroy()
    @view = null

  getView: ->
    @view ?= new (require './view')
