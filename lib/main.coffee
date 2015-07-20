{CompositeDisposable} = require 'atom'

config =
  projectRootDirectories:
    order: 1
    type: 'array'
    items:
      type: 'string'
    default: [atom.config.get('core.projectHome')]
    description: 'Comma separated list of directries to search project dir. e.g `~/.atom/packages, ~/github`'

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
