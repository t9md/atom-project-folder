path = require 'path'
class Settings
  constructor: (@scope, @config) ->
    # Inject order props to display orderd in setting-view
    for name, i in Object.keys(@config)
      @config[name].order = i

  get: (param) ->
    atom.config.get "#{@scope}.#{param}"

  set: (param, value) ->
    atom.config.set "#{@scope}.#{param}", value

module.exports = new Settings 'project-folder',
  projectRootDirectories:
    type: 'array'
    items:
      type: 'string'
    default: [atom.config.get('core.projectHome')]
    description: 'Comma separated list of directries to search project dir. e.g `~/.atom/packages, ~/github`'
  gitProjectDirectories:
    type: 'array'
    items:
      type: 'string'
    default: []
    description: 'Find git project recursively from directories listed here'
  gitProjectSearchMaxDepth:
    type:    'integer'
    min:     0
    default: 5
  hideLoadedFolderFromAddList:
    type: 'boolean'
    default: true
    description: 'Hide already added folders from list when adding.'
  closeItemsForRemovedProject:
    type: 'boolean'
    default: false
    description: 'close editor when containing project was removed'
  configPath:
    type: 'string'
    default: path.join(atom.getConfigDirPath(), 'project-folder.cson')
    description: 'filePath for user word group'
