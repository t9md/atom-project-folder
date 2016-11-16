_ = require 'underscore-plus'
{normalize, getHomeDirectory, isDirectorySync, listSync, traverseTreeSync} = require 'fs-plus'
_path = require 'path'

# Utils
# -------------------------
getPathDepth = (path) ->
  path.split(_path.sep).length

isGitRepository = (dir) ->
  isDirectorySync(_path.join(dir, '.git'))

# Check if contained by deep compaison
isContained = (items, target) ->
  for item in items when _.isEqual(item, target)
    return true
  false

HomeDirectoryRegexp = ///^#{_.escapeRegExp(getHomeDirectory())}///
tildifyHomeDirectory = (dir) ->
  dir.replace(HomeDirectoryRegexp, '~')

isInProjectList = (dir) ->
  dir in atom.project.getPaths()

someGroupMemberIsLoaded = ({dirs}) ->
  dirs.some(isInProjectList)

allGroupMemberIsLoaded = ({dirs}) ->
  dirs.every(isInProjectList)

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
  for rootDir in rootDirs.map(normalize)
    dirs.push(dir) for dir in listSync(rootDir) when isDirectorySync(dir)
  dirs

getGitDirectories = (rootDirs, maxDepth) ->
  dirs = []
  for rootDir in rootDirs.map(normalize) when isDirectorySync(rootDir)
    baseDepth = getPathDepth(rootDir)
    traverseTreeSync rootDir, (->), (path) ->
      if (getPathDepth(path) - baseDepth) > maxDepth
        false
      else
        dirs.push(path) if isGitRepository(path)
        true
  dirs

module.exports = {
  isContained
  isInProjectList
  someGroupMemberIsLoaded
  allGroupMemberIsLoaded
  highlightMatches
  getNormalDirectories
  getGitDirectories
  tildifyHomeDirectory
}
