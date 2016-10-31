{CompositeDisposable} = require 'atom'
fs = require 'fs-plus'
settings = require './settings'
CSON = null

configTemplate = """
# groups:
#   atom: [
#     "~/github/atom"
#     "~/github/text-buffer"
#     "~/github/atom-keymap"
#   ]
#   sample: [
#     "~/dir/hello-project"
#     "~/dir/world-project"
#   ]
"""

module.exports =
  config: settings.config

  activate: ->
    @view = new (require './view')
    @loadGroups() # set @view.groups.
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'project-folder:add': => @view.start('add')
      'project-folder:remove': => @view.start('remove')
      'project-folder:open-config': => @openUserConfig()

  deactivate: ->
    @subscriptions.dispose()
    @view?.destroy?()
    {@subscriptions, @view} = {}

  readConfig: ->
    filePath = @getUserConfigPath()
    config = {}
    return config unless fs.existsSync(filePath)

    try
      CSON ?= require 'season'
      config = CSON.readFileSync(filePath) or {}
    catch error
      atom.notifications.addError('[project-folder] config file has error', detail: error.message)
    config

  getUserConfigPath: ->
    fs.normalize(settings.get('configPath'))

  loadGroups: ->
    if groups = @readConfig().groups
      @view.setGroups(groups)

  openUserConfig: ->
    filePath = @getUserConfigPath()

    atom.workspace.open(filePath, searchAllPanes: true).then (editor) =>
      unless fs.existsSync(filePath)
        editor.setText(configTemplate)
        editor.save()
      @subscriptions.add editor.onDidSave =>
        @loadGroups()
