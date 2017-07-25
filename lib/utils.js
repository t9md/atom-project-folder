const _ = require("underscore-plus")
const {
  normalize,
  getHomeDirectory,
  isDirectorySync,
  listSync,
  traverseTreeSync,
} = require("fs-plus")
const _path = require("path")

// Utils
// -------------------------
function getPathDepth(path) {
  return path.split(_path.sep).length
}

function isGitRepository(dir) {
  return isDirectorySync(_path.join(dir, ".git"))
}

const HomeDirectoryRegexp = new RegExp(`^${_.escapeRegExp(getHomeDirectory())}`)
function tildifyHomeDirectory(dir) {
  return dir.replace(HomeDirectoryRegexp, "~")
}

function isInProjectList(dir) {
  return atom.project.getPaths().includes(dir)
}

function someGroupMemberIsLoaded({dirs}) {
  return dirs.some(isInProjectList)
}

function allGroupMemberIsLoaded({dirs}) {
  return dirs.every(isInProjectList)
}

// Copied & modified from fuzzy-finder's code.
function highlightMatches(context, path, matches, offsetIndex = 0) {
  let lastIndex = 0
  let matchedChars = [] // Build up a set of matched chars to be more semantic

  for (let matchIndex of matches) {
    matchIndex -= offsetIndex
    if (matchIndex < 0) {
      continue
    } // If marking up the basename, omit path matches
    const unmatched = path.substring(lastIndex, matchIndex)
    if (unmatched) {
      if (matchedChars.length) {
        context.span(matchedChars.join(""), {class: "character-match"})
      }
      matchedChars = []
      context.text(unmatched)
    }
    matchedChars.push(path[matchIndex])
    lastIndex = matchIndex + 1
  }

  if (matchedChars.length) {
    context.span(matchedChars.join(""), {class: "character-match"})
  }
  context.text(path.substring(lastIndex)) // Remaining characters are plain text
}

function getNormalDirectories(rootDirs) {
  const dirs = []
  for (const rootDir of rootDirs.map(normalize)) {
    dirs.push(...listSync(rootDir).filter(isDirectorySync))
  }
  return dirs
}

function getGitDirectories(rootDirs, maxDepth) {
  const dirs = []
  for (const rootDir of rootDirs.map(normalize).filter(isDirectorySync)) {
    const baseDepth = getPathDepth(rootDir)
    traverseTreeSync(
      rootDir,
      () => {},
      path => {
        if (getPathDepth(path) - baseDepth > maxDepth) {
          return false
        } else {
          if (isGitRepository(path)) dirs.push(path)
          return true
        }
      }
    )
  }
  return dirs
}

module.exports = {
  isInProjectList,
  someGroupMemberIsLoaded,
  allGroupMemberIsLoaded,
  highlightMatches,
  getNormalDirectories,
  getGitDirectories,
  tildifyHomeDirectory,
}
