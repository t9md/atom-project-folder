_path = require 'path'

fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'

{setConfig, getPath, addProject, openFile} = require './spec-helper'

describe "project-folder", ->
  [main, view, workspaceElement] = []

  normalRoot = getPath('normal')
  normalDir1 = getPath('normal/dir-1')
  normalDir2 = getPath('normal/dir-2')
  normalDirs = [normalDir1, normalDir2]

  gitRoot = fs.realpathSync(temp.mkdirSync('git'))
  fixturesPath = "#{__dirname}/fixtures"
  wrench.copyDirSyncRecursive(
    _path.join(fixturesPath, "git"),
    gitRoot,
    forceDelete: true
  )
  gitDir1   = _path.join(gitRoot, 'dir-1')
  gitDir2   = _path.join(gitRoot, 'dir-2')
  gitDir3   = _path.join(gitRoot, 'dir-3')
  gitDepth2 = _path.join(gitRoot, 'dir-3/depth2')
  gitDepth3 = _path.join(gitRoot, 'dir-3/depth2/depth3')
  fs.mkdirSync _path.join(gitRoot, 'dir-1/.git')
  fs.mkdirSync _path.join(gitRoot, 'dir-2/.git')
  fs.mkdirSync _path.join(gitRoot, 'dir-3/depth2/depth3/.git')
  gitDirs  = [gitDir1, gitDir2, gitDir3]

  dispatchCommand = (command) ->
    atom.commands.dispatch(workspaceElement, "project-folder:#{command}")

  dispatchSelectListCommand = (command) ->
    element = view.filterEditorView.element
    atom.commands.dispatch(element, command)

  getProjectPaths = ->
    atom.project.getPaths()

  addCustomMatchers = (spec) ->
    spec.addMatchers
      toBeEqualItem: (expected) ->
        line1 = @actual.find('div').eq(0).text()
        line2 = @actual.find('div').eq(1).text()
        (line1 is _path.basename(expected)) and (line2 is getPath(expected, true))

  beforeEach ->
    addCustomMatchers(this)
    fixturesDir = getProjectPaths()[0]
    atom.project.removePath(fixturesDir)

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)
    setConfig('projectRootDirectories', [normalRoot])
    activationPromise = null
    runs ->
      activationPromise = atom.packages.activatePackage('project-folder').then (pack) ->
        main = pack.mainModule
      atom.commands.dispatch(workspaceElement, "project-folder:add")

    waitsForPromise -> activationPromise
    waitsFor -> # wait for view get available
      main.view?

    runs ->
      view = main.view
      view.cancel()

  afterEach ->
    if view.isVisible()
      view.cancel()

  describe "project-folder:add", ->
    beforeEach ->
      dispatchCommand('add')
      expect(view).toHaveClass('add')
      items = view.list.find("li")
      expect(items).toHaveLength 2
      expect(items.eq(0)).toBeEqualItem('normal/dir-1')
      expect(items.eq(1)).toBeEqualItem('normal/dir-2')

    it "add confirmed paths to projects 1st", ->
      dispatchSelectListCommand 'core:confirm'
      expect(getProjectPaths()).toEqual([normalDir1])

    it "add confirmed paths to projects 2nd", ->
      dispatchSelectListCommand 'core:move-down'
      dispatchSelectListCommand 'core:confirm'
      expect(getProjectPaths()).toEqual([normalDir2])

    describe "confirmAndContinue", ->
      it "allow continuously add paths to projects", ->
        expect(getProjectPaths()).toEqual([])
        dispatchSelectListCommand 'project-folder:confirm-and-continue'
        expect(getProjectPaths()).toEqual([normalDir1])
        dispatchSelectListCommand 'project-folder:confirm-and-continue'
        expect(getProjectPaths()).toEqual([normalDir1, normalDir2])

  describe "hideLoadedFolderFromAddList", ->
    beforeEach ->
      spyOn(view, "getEmptyMessage").andCallThrough()

    describe 'hideLoadedFolderFromAddList is true(default)', ->
      it "hide already added paths from add list case-2", ->
        addProject(normalDir1)
        dispatchCommand('add')
        items = view.list.find("li")
        expect(items).toHaveLength 1
        expect(items.eq(0)).toBeEqualItem('normal/dir-2')

      it "hide already added paths from add list case-1", ->
        addProject(normalDir1, normalDir2)
        dispatchCommand('add')
        expect(view).toHaveClass('add')
        expect(view.getEmptyMessage).toHaveBeenCalled()

    describe 'hideLoadedFolderFromAddList is false', ->
      it "not hide already added paths from add list", ->
        setConfig('hideLoadedFolderFromAddList', false)
        addProject(normalDir1, normalDir2)
        dispatchCommand('add')
        expect(view.list.find("li")).toHaveLength 2

  describe "project-folder:remove", ->
    beforeEach ->
      addProject(normalDir1, normalDir2)
      expect(getProjectPaths()).toEqual([normalDir1, normalDir2])
      dispatchCommand('remove')
      expect(view).toHaveClass('remove')
      items = view.list.find("li")
      expect(items).toHaveLength 2
      expect(items.eq(0)).toBeEqualItem('normal/dir-1')
      expect(items.eq(1)).toBeEqualItem('normal/dir-2')

    it "remove confirmed paths from projects 1st", ->
      dispatchSelectListCommand 'core:confirm'
      expect(getProjectPaths()).toEqual([normalDir2])

    it "add confirmed paths to projects 2nd", ->
      dispatchSelectListCommand 'core:move-down'
      dispatchSelectListCommand 'core:confirm'
      expect(getProjectPaths()).toEqual([normalDir1])

    describe "confirmAndContinue", ->
      it "allow continuously remove paths from projects", ->
        dispatchSelectListCommand 'project-folder:confirm-and-continue'
        expect(getProjectPaths()).toEqual([normalDir2])
        dispatchSelectListCommand 'project-folder:confirm-and-continue'
        expect(getProjectPaths()).toEqual([])

  describe "view::add", ->
    it "add directory to project", ->
      view.add(normalDir1)
      view.add(normalDir2)
      expect(getProjectPaths()).toEqual([normalDir1, normalDir2])

  describe "view::remove", ->
    it "remove directory from project", ->
      addProject(normalDir1, normalDir2)
      view.remove(normalDir1)
      expect(getProjectPaths()).toEqual [normalDir2]
      view.remove(normalDir2)
      expect(getProjectPaths()).toEqual []

  describe "closeItemsForRemovedProject", ->
    file1 = getPath('normal/dir-1/dir-1.coffee')
    file2 = getPath('normal/dir-2/dir-2.coffee')

    beforeEach ->
      setConfig('closeItemsForRemovedProject', true)
      addProject(normalDir1, normalDir2)
      openFile file1
      openFile file2

      runs ->
        files = atom.workspace.getTextEditors().map (e) -> e.getPath()
        expect(files).toEqual([file1, file2])

    it "close editor for removed project", ->
      view.remove(normalDir2)
      files = atom.workspace.getTextEditors().map (e) -> e.getPath()
      expect(files).toEqual([file1])

  describe "view::replace", ->
    it "remove all project except passed one", ->
      addProject(normalDir1, normalDir2)
      spyOn(view, "getSelectedItem").andReturn(gitDir1)
      view.replace()
      expect(getProjectPaths()).toEqual([gitDir1])

  describe "view::newWindow", ->
    it "opens the project folder in a new atom window", ->
      spyOn(view, "getSelectedItem").andReturn(normalDir1)
      view.newWindow()
      # How to check if the new window opened with the directory?

  describe "view::getNormalDirectories", ->
    it "get directories case-1", ->
      setConfig 'projectRootDirectories', [normalRoot]
      expect(view.getNormalDirectories()).toEqual(normalDirs)

    it "get directories case-2", ->
      setConfig('projectRootDirectories', [normalRoot, gitRoot])
      expect(view.getNormalDirectories()).toEqual(normalDirs.concat(gitDirs))

  describe "view::getGitDirectories", ->
    describe "gitProjectDirectories config is empty(default)", ->
      it "return empty list", ->
        expect(view.getGitDirectories()).toEqual([])

    describe "gitProjectDirectories is set", ->
      it "return directories which contains .git", ->
        setConfig('gitProjectDirectories', [gitRoot])
        expect(view.getGitDirectories()).toEqual([gitDir1, gitDir2, gitDepth3])

    describe "gitProjectSearchMaxDepth is 2", ->
      it "search .git directory 2 depth at maximum", ->
        setConfig('gitProjectDirectories', [gitRoot])
        setConfig('gitProjectSearchMaxDepth', 1)
        expect(view.getGitDirectories()).toEqual([gitDir1, gitDir2])
