{CompositeDisposable} = require 'atom'
settings = require './settings'

module.exports =
  config: settings.config

  activate: ->
    @view = new (require './view')
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'project-folder:add': => @view.start('add')
      'project-folder:remove': => @view.start('remove')

  deactivate: ->
    @subscriptions.dispose()
    @view?.destroy?()
    {@subscriptions, @view} = {}
