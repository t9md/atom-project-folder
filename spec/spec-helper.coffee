fs = require 'fs-plus'
_path = require 'path'

setConfig = (name, value) ->
  atom.config.set("project-folder.#{name}", value)

getPath = (file, useTildeAsHome=false) ->
  filePath = _path.join "#{__dirname}/fixtures", file
  p = fs.normalize(filePath)
  if useTildeAsHome
    p.replace fs.getHomeDirectory(), '~'
  else
    p

addProject = (dirs...) ->
  for dir in dirs
    atom.project.addPath(dir)

openFile = (filePath) ->
  waitsForPromise ->
    atom.workspace.open(filePath)

module.exports = {setConfig, getPath, addProject, openFile}
