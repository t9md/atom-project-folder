# Refactoring status: 100%
class Settings
  constructor: (@scope, @config) ->

  get: (param) ->
    atom.config.get "#{@scope}.#{param}"

  set: (param, value) ->
    atom.config.set "#{@scope}.#{param}", value

module.exports = new Settings 'project-folder',
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
  closeItemsForRemovedProject:
    order: 5
    type: 'boolean'
    default: true
