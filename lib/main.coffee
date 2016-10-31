{CompositeDisposable} = require 'atom'
fs = require 'fs-plus'
settings = require './settings'

configTemplate = """
# projectGroups:
#   "atom": [
#     "atom"
#     "text-buffer"
#     "atom-keymap"
#   ]
#   "sample": [
#     "hello-project"
#     "world-project"
#   ]
"""

module.exports =
  config: settings.config

  activate: ->
    @view = new (require './view')
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'project-folder:add': => @view.start('add')
      'project-folder:remove': => @view.start('remove')
      'project-folder:open-config': => @openUserConfig()

  deactivate: ->
    @subscriptions.dispose()
    @view?.destroy?()
    {@subscriptions, @view} = {}

  loadConfig: ->
    console.log "load!"

  openUserConfig: ->
    filePath = fs.normalize(settings.get('configPath'))
    disposable = null
    loadConfig = @loadConfig.bind(this)
    atom.workspace.open(filePath, searchAllPanes: true).then (editor) ->
      unless fs.existsSync(filePath)
        editor.setText(configTemplate)
        editor.save()
      editor.onDidSave(loadConfig)
