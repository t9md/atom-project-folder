_ = require 'underscore-plus'
fs = require 'fs-plus'
{normalize} = fs
_path = require 'path'

# Utils
# -------------------------
getPathDepth = (path) ->
  path.split(_path.sep).length

isGitRepository = (path) ->
  fs.isDirectorySync _path.join(path, '.git')

# Check if contained by deep compaison
isContained = (items, target) ->
  for item in items when _.isEqual(item, target)
    return true
  false

isInProjectList = (dir) ->
  dir in atom.project.getPaths()

someGroupMemberIsLoaded = ({dirs}) ->
  dirs.some (dir) -> isInProjectList(dir)

allGroupMemberIsLoaded = ({dirs}) ->
  dirs.every (dir) -> isInProjectList(dir)

# Copied & modified from fuzzy-finder's code.
highlightMatches = (context, path, matches, offsetIndex=0) ->
  lastIndex = 0
  matchedChars = [] # Build up a set of matched chars to be more semantic

  for matchIndex in matches
    matchIndex -= offsetIndex
    continue if matchIndex < 0 # If marking up the basename, omit path matches
    unmatched = path.substring(lastIndex, matchIndex)
    if unmatched
      context.span matchedChars.join(''), class: 'character-match' if matchedChars.length
      matchedChars = []
      context.text unmatched
    matchedChars.push(path[matchIndex])
    lastIndex = matchIndex + 1

  context.span matchedChars.join(''), class: 'character-match' if matchedChars.length
  context.text path.substring(lastIndex) # Remaining characters are plain text

getNormalDirectories = (rootDirs) ->
  dirs = []
  for rootDir in rootDirs
    for dir in fs.listSync(normalize(rootDir)) when fs.isDirectorySync(dir)
      dirs.push(dir)
  dirs

getGitDirectories = (rootDirs, maxDepth) ->
  dirs = []
  for dir in rootDirs
    dir = normalize(dir)
    continue unless fs.isDirectorySync(dir)

    baseDepth = getPathDepth(dir)
    fs.traverseTreeSync dir, (->), (path) ->
      if (getPathDepth(path) - baseDepth) > maxDepth
        false
      else
        dirs.push(path) if isGitRepository(path)
        true
  dirs

addProjects = (dirs...) ->
  for dir in dirs when fs.isDirectorySync(dir)
    atom.project.addPath(dir)

removeProjects = (dirs...) ->
  for dir in dirs
    atom.project.removePath(dir)

module.exports = {
  isContained
  isInProjectList
  someGroupMemberIsLoaded
  allGroupMemberIsLoaded
  highlightMatches
  getNormalDirectories
  getGitDirectories
  addProjects
  removeProjects
}
