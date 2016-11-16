path = require 'path'
class Settings
  constructor: (@scope, @config) ->
    # Inject order props to display orderd in setting-view
    for name, i in Object.keys(@config)
      @config[name].order = i

    # Automatically infer and inject `type` of each config parameter.
    for key, object of @config
      object.type = switch
        when Number.isInteger(object.default) then 'integer'
        when typeof(object.default) is 'boolean' then 'boolean'
        when typeof(object.default) is 'string' then 'string'
        when Array.isArray(object.default) then 'array'

  get: (param) ->
    atom.config.get "#{@scope}.#{param}"

  set: (param, value) ->
    atom.config.set "#{@scope}.#{param}", value

module.exports = new Settings 'project-folder',
  projectRootDirectories:
    default: [atom.config.get('core.projectHome')]
    items: type: 'string'
    description: 'Comma separated list of directries to search project dir. e.g `~/.atom/packages, ~/github`'
  gitProjectDirectories:
    default: []
    items: type: 'string'
    description: 'Find git project recursively from directories listed here'
  gitProjectSearchMaxDepth:
    default: 5
    min: 0
  hideLoadedFolderFromAddList:
    default: true
    description: 'Hide already added folders from list when adding.'
  showGroupOnRemoveListCondition:
    default: 'never'
    enum: ['never', 'some-member-was-loaded', 'all-member-was-loaded']
    description: 'Control if group item shows up on remove list'
  closeItemsForRemovedProject:
    default: false
    description: 'close editor when containing project was removed'
  configPath:
    default: path.join(atom.getConfigDirPath(), 'project-folder.cson')
    description: 'filePath for user word group'
