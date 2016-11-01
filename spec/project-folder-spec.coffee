_path = require 'path'

fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'

# Utility functions
# -------------------------
setConfig = (name, value) ->
  atom.config.set("project-folder.#{name}", value)

getConfig = (name) ->
  atom.config.get("project-folder.#{name}")

getPath = (file, useTildeAsHome=false) ->
  filePath = joinPath("#{__dirname}/fixtures", file)
  path = fs.normalize(filePath)
  if useTildeAsHome
    path.replace(fs.getHomeDirectory(), '~')
  else
    path

addProject = (dirs...) ->
  atom.project.addPath(dir) for dir in dirs

openFile = (filePath) ->
  waitsForPromise ->
    atom.workspace.open(filePath)

joinPath = (paths...) ->
  _path.join(paths...)

dispatchCommand = (target, command) ->
  atom.commands.dispatch(target, command)

getProjectPaths = ->
  atom.project.getPaths()

getEditor = ->
  atom.workspace.getActiveTextEditor()

# Main
# -------------------------
describe "project-folder", ->
  [main, view, filterEditorElement, workspaceElement] = []

  tempHome = fs.realpathSync(temp.mkdirSync('home'))
  configPath = joinPath(tempHome, 'project-folder.cson')

  # Normal
  normalRoot = getPath('normal')
  normalDir1 = getPath('normal/dir-1')
  normalDir2 = getPath('normal/dir-2')
  normalDirs = [normalDir1, normalDir2]

  # Git
  gitRoot = fs.realpathSync(temp.mkdirSync('git'))
  gitRootSource = getPath('git')
  wrench.copyDirSyncRecursive(gitRootSource, gitRoot, forceDelete: true)

  gitDir1 = joinPath(gitRoot, 'dir-1')
  gitDir2 = joinPath(gitRoot, 'dir-2')
  gitDir3 = joinPath(gitRoot, 'dir-3/depth2/depth3')
  fs.mkdirSync joinPath(gitRoot, 'dir-1/.git')
  fs.mkdirSync joinPath(gitRoot, 'dir-2/.git')
  fs.mkdirSync joinPath(gitRoot, 'dir-3/depth2/depth3/.git')
  gitDirs = [gitDir1, gitDir2, gitDir3]
  gitRootDirs = [gitDir1, gitDir2, joinPath(gitRoot, 'dir-3')]

  addCustomMatchers = (spec) ->
    spec.addMatchers
      toBeEqualItem: (expected) ->
        line1 = @actual.find('div').eq(0).text()
        line2 = @actual.find('div').eq(1).text()
        (line1 is _path.basename(expected)) and (line2 is getPath(expected, true))

  ensureProjectPaths = ({dirs, panelIsVisible}) ->
    if not dirs? or not panelIsVisible?
      throw new Error('Spec erro')

    expect(getProjectPaths()).toEqual(dirs)
    expect(view.panel.isVisible()).toBe(panelIsVisible)

  beforeEach ->
    addCustomMatchers(this)
    setConfig('configPath', configPath)
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
      filterEditorElement = view.filterEditorView.element
      view.cancel()

  afterEach ->
    if view.panel.isVisible()
      view.cancel()

  describe "project-folder:add", ->
    beforeEach ->
      dispatchCommand(workspaceElement, 'project-folder:add')
      expect(view).toHaveClass('add')
      expect(view).not.toHaveClass('remove')
      items = view.list.find("li")
      expect(items).toHaveLength 2
      expect(items.eq(0)).toBeEqualItem('normal/dir-1')
      expect(items.eq(1)).toBeEqualItem('normal/dir-2')

    it "add confirmed paths to projects 1st item", ->
      dispatchCommand(filterEditorElement, 'core:confirm')
      ensureProjectPaths(dirs: [normalDir1], panelIsVisible: false)

    it "add confirmed paths to projects 2nd item", ->
      dispatchCommand(filterEditorElement, 'core:move-down')
      dispatchCommand(filterEditorElement, 'core:confirm')
      ensureProjectPaths(dirs: [normalDir2], panelIsVisible: false)

    describe "confirmAndContinue", ->
      it "allow continuously add paths to projects", ->
        ensureProjectPaths(dirs: [], panelIsVisible: true)
        dispatchCommand(filterEditorElement, 'project-folder:confirm-and-continue')
        ensureProjectPaths(dirs: [normalDir1], panelIsVisible: true)
        dispatchCommand(filterEditorElement, 'project-folder:confirm-and-continue')
        ensureProjectPaths(dirs: [normalDir1, normalDir2], panelIsVisible: true)

  describe "hideLoadedFolderFromAddList", ->
    beforeEach ->
      spyOn(view, "getEmptyMessage").andCallThrough()

    describe 'hideLoadedFolderFromAddList is true(default)', ->
      it "hide already added paths from add list case-2", ->
        addProject(normalDir1)
        dispatchCommand(workspaceElement, 'project-folder:add')
        items = view.list.find("li")
        expect(items).toHaveLength 1
        expect(items.eq(0)).toBeEqualItem('normal/dir-2')

      it "hide already added paths from add list case-1", ->
        addProject(normalDir1, normalDir2)
        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')
        expect(view.getEmptyMessage).toHaveBeenCalled()

    describe 'hideLoadedFolderFromAddList is false', ->
      it "not hide already added paths from add list", ->
        setConfig('hideLoadedFolderFromAddList', false)
        addProject(normalDir1, normalDir2)
        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view.list.find("li")).toHaveLength 2

  describe "project-folder:remove", ->
    beforeEach ->
      addProject(normalDir1, normalDir2)
      expect(getProjectPaths()).toEqual([normalDir1, normalDir2])
      dispatchCommand(workspaceElement, 'project-folder:remove')
      expect(view).toHaveClass('remove')
      items = view.list.find("li")
      expect(items).toHaveLength 2
      expect(items.eq(0)).toBeEqualItem('normal/dir-1')
      expect(items.eq(1)).toBeEqualItem('normal/dir-2')

    it "remove confirmed paths from projects 1st", ->
      dispatchCommand(filterEditorElement, 'core:confirm')
      expect(getProjectPaths()).toEqual([normalDir2])

    it "add confirmed paths to projects 2nd", ->
      dispatchCommand(filterEditorElement, 'core:move-down')
      dispatchCommand(filterEditorElement, 'core:confirm')
      expect(getProjectPaths()).toEqual([normalDir1])

    describe "confirmAndContinue", ->
      it "allow continuously remove paths from projects", ->
        dispatchCommand(filterEditorElement, 'project-folder:confirm-and-continue')
        expect(getProjectPaths()).toEqual([normalDir2])
        dispatchCommand(filterEditorElement, 'project-folder:confirm-and-continue')
        expect(getProjectPaths()).toEqual([])

  describe "view::add", ->
    it "add directory to project", ->
      view.add(dir: normalDir1, type: 'directory')
      view.add(dir: normalDir2, type: 'directory')
      expect(getProjectPaths()).toEqual([normalDir1, normalDir2])

  describe "view::remove", ->
    it "remove directory from project", ->
      addProject(normalDir1, normalDir2)
      view.remove(dir: normalDir1, type: 'directory')
      expect(getProjectPaths()).toEqual [normalDir2]
      view.remove(dir: normalDir2, type: 'directory')
      expect(getProjectPaths()).toEqual []

  describe "closeItemsForRemovedProject", ->
    file1 = getPath('normal/dir-1/dir-1.coffee')
    file2 = getPath('normal/dir-2/dir-2.coffee')

    beforeEach ->
      setConfig('closeItemsForRemovedProject', true)
      addProject(normalDir1, normalDir2)
      openFile(file1)
      openFile(file2)

      runs ->
        files = atom.workspace.getTextEditors().map (e) -> e.getPath()
        expect(files).toEqual([file1, file2])

    it "close editor for removed project", ->
      view.remove(dir: normalDir2, type: 'directory')
      files = atom.workspace.getTextEditors().map (e) -> e.getPath()
      expect(files).toEqual([file1])

  describe "view::replace", ->
    it "remove all project except passed one", ->
      addProject(normalDir1, normalDir2)
      spyOn(view, "getSelectedItem").andReturn(dir: gitDir1, type: 'directory')
      view.replace()
      expect(getProjectPaths()).toEqual([gitDir1])

  describe "view::getNormalDirectories", ->
    it "get directories case-1", ->
      setConfig('projectRootDirectories', [normalRoot])
      expect(view.getNormalDirectories()).toEqual(normalDirs)

    it "get directories case-2", ->
      setConfig('projectRootDirectories', [normalRoot, gitRoot])
      expect(view.getNormalDirectories()).toEqual(normalDirs.concat(gitRootDirs))

  describe "view::getGitDirectories", ->
    describe "gitProjectDirectories config is empty(default)", ->
      it "return empty list", ->
        expect(view.getGitDirectories()).toEqual([])

    describe "gitProjectDirectories is set", ->
      it "return directories which contains .git", ->
        setConfig('gitProjectDirectories', [gitRoot])
        expect(view.getGitDirectories()).toEqual([gitDir1, gitDir2, gitDir3])

    describe "gitProjectSearchMaxDepth is 2", ->
      it "search .git directory 2 depth at maximum", ->
        setConfig('gitProjectDirectories', [gitRoot])
        setConfig('gitProjectSearchMaxDepth', 1)
        expect(view.getGitDirectories()).toEqual([gitDir1, gitDir2])

  describe "view::openInNewWindow", ->
    it "open selected project in new window", ->
      spyOn(view, "getSelectedItem").andReturn(dir: normalDir1, type: 'directory')
      spyOn(atom, "open")
      view.openInNewWindow()
      expect(atom.open).toHaveBeenCalledWith({pathsToOpen: [normalDir1], newWindow: true})

  describe "user defined project-group", ->
    userConfigEditor = null

    ensureSelectListItems = (expectedItems) ->
      items = []
      for item in view.getItems()
        item.dir = fs.normalize(item.dir)
        items.push(item)
      expect(items).toEqual(expectedItems)

    beforeEach ->
      waitsForPromise ->
        main.openConfig()
      runs ->
        userConfigEditor = getEditor()

    describe "user config file", ->
      it "opens editor in configPath", ->
        expect(userConfigEditor.getPath()).toBe(configPath)

      it "load config on save", ->
        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')

        ensureSelectListItems [
          {dir: normalDir1, type: 'directory'},
          {dir: normalDir2, type: 'directory'}
        ]

        view.cancel()

        userConfigText = """
          groups:
            atom: [
              "~/github/atom.org"
              "~/github/text-buffer"
              "~/github/atom-keymap"
            ]
            sample: [
              "~/dir/hello-project"
              "~/dir/world-project"
            ]
          """
        userConfigEditor.setText(userConfigText)

        expect(view.groups).toBe(null)
        userConfigEditor.save()
        expect(view.groups).toEqual
          atom: [
            "~/github/atom.org"
            "~/github/text-buffer"
            "~/github/atom-keymap"
          ]
          sample: [
            "~/dir/hello-project"
            "~/dir/world-project"
          ]

        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')
        ensureSelectListItems [
          {dir: 'atom', type: 'group', dirs: view.groups.atom},
          {dir: 'sample', type: 'group', dirs: view.groups.sample},
          {dir: normalDir1, type: 'directory'},
          {dir: normalDir2, type: 'directory'},
        ]

    describe "add/remove groups of project", ->
      loadUserConfig = ->
        userConfigText = """
          groups:
            sample1: [
              "#{normalDir1}"
              "#{normalDir2}"
            ]
            sample2: [
              "#{gitDir1}"
              "#{gitDir2}"
            ]
          """
        userConfigEditor.setText(userConfigText)
        userConfigEditor.save()
        expect(view.groups).not.toBe(null)

      beforeEach ->
        setConfig('gitProjectDirectories', [gitRoot])
        loadUserConfig()

      it "add/remove set of project defined in groups", ->
        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')
        ensureSelectListItems [
          {dir: 'sample1', type: 'group', dirs: [normalDir1, normalDir2]},
          {dir: 'sample2', type: 'group', dirs: [gitDir1, gitDir2]},
          {dir: normalDir1, type: 'directory'},
          {dir: normalDir2, type: 'directory'},
          {dir: gitDir1, type: 'directory'},
          {dir: gitDir2, type: 'directory'},
          {dir: gitDir3, type: 'directory'},
        ]

        ensureProjectPaths(dirs: [], panelIsVisible: true)
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(dirs: [normalDir1, normalDir2], panelIsVisible: false)

        dispatchCommand(workspaceElement, 'project-folder:add')
        dispatchCommand(filterEditorElement, 'core:move-down')
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(dirs: [normalDir1, normalDir2, gitDir1, gitDir2], panelIsVisible: false)

        dispatchCommand(workspaceElement, 'project-folder:remove')
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(dirs: [gitDir1, gitDir2], panelIsVisible: false)

        dispatchCommand(workspaceElement, 'project-folder:remove')
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(dirs: [], panelIsVisible: false)

      it "show up on removal list as long as at least one member was loaded", ->
        addProject(normalDir1, normalDir2, gitDir1, gitDir2)
        dispatchCommand(workspaceElement, 'project-folder:remove')
        expect(view).toHaveClass('remove')

        itemGroupSample1 = {dir: 'sample1', type: 'group', dirs: [normalDir1, normalDir2]}
        itemGroupSample2 = {dir: 'sample2', type: 'group', dirs: [gitDir1, gitDir2]}
        itemDirNormalDir1 = {dir: normalDir1, type: 'directory'}
        itemDirNormalDir2 = {dir: normalDir2, type: 'directory'}
        itemDirGitDir1 = {dir: gitDir1, type: 'directory'}
        itemDirGitDir2 = {dir: gitDir2, type: 'directory'}

        ensureSelectListItems [
          itemGroupSample1
          itemGroupSample2
          itemDirNormalDir1
          itemDirNormalDir2
          itemDirGitDir1
          itemDirGitDir2
        ]

        view.remove(itemDirNormalDir1)
        view.remove(itemDirGitDir1)
        ensureSelectListItems [
          itemGroupSample1
          itemGroupSample2
          itemDirNormalDir2
          itemDirGitDir2
        ]

        view.remove(itemDirGitDir2)
        ensureSelectListItems [
          itemGroupSample1
          itemDirNormalDir2
        ]

        view.remove(itemDirNormalDir2)
        ensureSelectListItems []
