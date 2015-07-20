{CompositeDisposable} = require 'atom'

config =
  projectHome:
    order: 1
    type: 'string'
    default: atom.config.get('core.projectHome')

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
