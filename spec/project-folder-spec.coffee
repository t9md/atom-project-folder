_path = require 'path'

fs = require 'fs-plus'
fsx = require 'fs-extra'
{normalize} = fs
temp = require 'temp'

# Utility functions
# -------------------------
setConfig = (name, value) ->
  atom.config.set("project-folder.#{name}", value)

getConfig = (name) ->
  atom.config.get("project-folder.#{name}")

getPath = (file) ->
  normalize(joinPath("#{__dirname}/fixtures", file))

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
  fsx.copySync(gitRootSource, gitRoot)

  gitDir1 = joinPath(gitRoot, 'dir-1')
  gitDir2 = joinPath(gitRoot, 'dir-2')
  gitDir3 = joinPath(gitRoot, 'dir-3/depth2/depth3')
  fs.mkdirSync joinPath(gitRoot, 'dir-1/.git')
  fs.mkdirSync joinPath(gitRoot, 'dir-2/.git')
  fs.mkdirSync joinPath(gitRoot, 'dir-3/depth2/depth3/.git')
  gitDirs = [gitDir1, gitDir2, gitDir3]
  gitRootDirs = [gitDir1, gitDir2, joinPath(gitRoot, 'dir-3')]

  itemGroupNormal = {name: 'normal', dirs: [normalDir1, normalDir2]}
  itemGroupGit = {name: 'git', dirs: [gitDir1, gitDir2]}
  itemDirNormalDir1 = {name: normalDir1, dirs: [normalDir1]}
  itemDirNormalDir2 = {name: normalDir2, dirs: [normalDir2]}
  itemDirGitDir1 = {name: gitDir1, dirs: [gitDir1]}
  itemDirGitDir2 = {name: gitDir2, dirs: [gitDir2]}
  itemDirGitDir3 = {name: gitDir3, dirs: [gitDir3]}

  addCustomMatchers = (spec) ->
    spec.addMatchers
      toBeEqualItem: (expected) ->
        line1 = @actual.find('div').eq(0).text()
        line2 = @actual.find('div').eq(1).text()
        (line1 is _path.basename(expected)) and (normalize(line2) is getPath(expected))

  ensureProjectPaths = (dirs...) ->
    expect(getProjectPaths()).toEqual(dirs)

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
      ensureProjectPaths(normalDir1)
      expect(view.panel.isVisible()).toBe(false)


    it "add confirmed paths to projects 2nd item", ->
      dispatchCommand(filterEditorElement, 'core:move-down')
      dispatchCommand(filterEditorElement, 'core:confirm')
      ensureProjectPaths(normalDir2)
      expect(view.panel.isVisible()).toBe(false)

    describe "confirmAndContinue", ->
      it "allow continuously add paths to projects", ->
        ensureProjectPaths()
        expect(view.panel.isVisible()).toBe(true)
        dispatchCommand(filterEditorElement, 'project-folder:confirm-and-continue')
        ensureProjectPaths(normalDir1)
        dispatchCommand(filterEditorElement, 'project-folder:confirm-and-continue')
        ensureProjectPaths(normalDir1, normalDir2)
        expect(view.panel.isVisible()).toBe(true)

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
      ensureProjectPaths(normalDir1, normalDir2)
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
      openFile(file1)
      openFile(file2)

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
      spyOn(view, "getSelectedItem").andReturn(itemDirGitDir1)
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
      spyOn(view, "getSelectedItem").andReturn(itemDirNormalDir1)
      spyOn(atom, "open")
      view.openInNewWindow()
      expect(atom.open).toHaveBeenCalledWith(pathsToOpen: [normalDir1], newWindow: true, devMode: atom.inDevMode())

  describe "user defined project-group", ->
    userConfigEditor = null

    ensureSelectListItems = (expectedItems) ->
      items = []
      for item in view.getItems()
        item.name = normalize(item.name)
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
          itemDirNormalDir1
          itemDirNormalDir2
        ]

        view.cancel()
        expect(view.getItemsForGroups()).toEqual([])
        userConfigEditor.setText """
          groups:
            atom: [
              "~/github/atom.org"
              "~/github/text-buffer"
              "~/github/atom-keymap"
            ]
            hello: [
              "~/dir/hello-project"
              "~/dir/world-project"
            ]
          """
        userConfigEditor.save()

        itemGroupAtom =
          name: 'atom'
          dirs: ["~/github/atom.org", "~/github/text-buffer", "~/github/atom-keymap"].map(normalize)

        itemGroupHello =
          name: 'hello'
          dirs: ["~/dir/hello-project", "~/dir/world-project"].map(normalize)

        expect(view.getItemsForGroups()).toEqual [
          itemGroupAtom
          itemGroupHello
        ]

        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')
        ensureSelectListItems [
          itemGroupAtom
          itemGroupHello
          itemDirNormalDir1
          itemDirNormalDir2
        ]

    describe "add/remove groups of project", ->
      loadUserConfig = ->
        userConfigEditor.setText """
          groups:
            normal: [
              "#{normalDir1}"
              "#{normalDir2}"
            ]
            git: [
              "#{gitDir1}"
              "#{gitDir2}"
            ]
          """
        userConfigEditor.save()
        expect(view.groups).not.toBe(null)

      beforeEach ->
        setConfig('gitProjectDirectories', [gitRoot])

        # By changing showGroupOnRemoveListCondition from default 'never' to
        # 'some-member-was-loaded', we can test removal of group.
        setConfig('showGroupOnRemoveListCondition', 'some-member-was-loaded')
        loadUserConfig()

      it "add/remove set of project defined in groups", ->
        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')
        ensureSelectListItems [
          itemGroupNormal
          itemGroupGit
          itemDirNormalDir1
          itemDirNormalDir2
          itemDirGitDir1
          itemDirGitDir2
          itemDirGitDir3
        ]

        # Confirm group 'normal'
        ensureProjectPaths()
        expect(view.panel.isVisible()).toBe(true)
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(normalDir1, normalDir2)

        # Confirm group 'git'
        dispatchCommand(workspaceElement, 'project-folder:add')
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(normalDir1, normalDir2, gitDir1, gitDir2)

        # Remove group 'normal'
        dispatchCommand(workspaceElement, 'project-folder:remove')
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths(gitDir1, gitDir2)

        # Remove group 'git'
        dispatchCommand(workspaceElement, 'project-folder:remove')
        dispatchCommand(filterEditorElement, 'core:confirm')
        ensureProjectPaths()

      it "by default(hideLoadedFolderFromAddList is true) hide from add list if all member is already loaded", ->
        dispatchCommand(workspaceElement, 'project-folder:add')
        expect(view).toHaveClass('add')

        ensureSelectListItems [
          itemGroupNormal
          itemGroupGit
          itemDirNormalDir1, itemDirNormalDir2
          itemDirGitDir1, itemDirGitDir2
          itemDirGitDir3
        ]

        view.add(normalDir1)
        ensureSelectListItems [
          itemGroupNormal
          itemGroupGit
          itemDirNormalDir2
          itemDirGitDir1, itemDirGitDir2
          itemDirGitDir3
        ]

        view.add(normalDir2)
        ensureSelectListItems [
          itemGroupGit
          itemDirGitDir1, itemDirGitDir2
          itemDirGitDir3
        ]

        view.add(gitDir1)
        ensureSelectListItems [
          itemGroupGit
          itemDirGitDir2
          itemDirGitDir3
        ]

        view.add(gitDir2)
        ensureSelectListItems [
          itemDirGitDir3
        ]

      describe "showGroupOnRemoveListCondition", ->
        describe "never", ->
          beforeEach ->
            setConfig('showGroupOnRemoveListCondition', 'never')

          it "doesn't show group on removal list", ->
            addProject(normalDir1, normalDir2, gitDir1, gitDir2)
            dispatchCommand(workspaceElement, 'project-folder:remove')
            expect(view).toHaveClass('remove')

            ensureSelectListItems [
              itemDirNormalDir1, itemDirNormalDir2
              itemDirGitDir1, itemDirGitDir2
            ]

            view.remove(normalDir1)
            view.remove(gitDir1)
            ensureSelectListItems [
              itemDirNormalDir2
              itemDirGitDir2
            ]

            view.remove(gitDir2)
            ensureSelectListItems [
              itemDirNormalDir2
            ]
            view.remove(normalDir2)
            ensureSelectListItems []

        describe "some-member-was-loaded", ->
          beforeEach ->
            setConfig('showGroupOnRemoveListCondition', 'some-member-was-loaded')
          it "show up on removal list as long as at least one member was loaded", ->
            addProject(normalDir1, normalDir2, gitDir1, gitDir2)
            dispatchCommand(workspaceElement, 'project-folder:remove')
            expect(view).toHaveClass('remove')

            ensureSelectListItems [
              itemGroupNormal
              itemGroupGit
              itemDirNormalDir1, itemDirNormalDir2
              itemDirGitDir1, itemDirGitDir2
            ]

            view.remove(normalDir1)
            view.remove(gitDir1)
            ensureSelectListItems [
              itemGroupNormal
              itemGroupGit
              itemDirNormalDir2
              itemDirGitDir2
            ]

            view.remove(gitDir2)
            ensureSelectListItems [
              itemGroupNormal
              itemDirNormalDir2
            ]

            view.remove(normalDir2)
            ensureSelectListItems []

        describe "all-member-was-loaded", ->
          beforeEach ->
            setConfig('showGroupOnRemoveListCondition', 'all-member-was-loaded')
          it "show group if all member project of that group was loaded", ->
            addProject(normalDir1, normalDir2, gitDir1, gitDir2)
            dispatchCommand(workspaceElement, 'project-folder:remove')
            expect(view).toHaveClass('remove')

            ensureSelectListItems [
              itemGroupNormal
              itemGroupGit
              itemDirNormalDir1, itemDirNormalDir2
              itemDirGitDir1, itemDirGitDir2
            ]

            view.remove(normalDir1)
            ensureSelectListItems [
              itemGroupGit
              itemDirNormalDir2
              itemDirGitDir1, itemDirGitDir2
            ]

            view.remove(gitDir1)
            ensureSelectListItems [
              itemDirNormalDir2
              itemDirGitDir2
            ]

            view.remove(normalDir2)
            view.remove(gitDir2)
            ensureSelectListItems []

  describe "project-folder:set-to-top-of-projects", ->
    originalProjects = [normalDir1, normalDir2, gitDir1, gitDir2, gitDir3]
    beforeEach ->
      addProject(originalProjects...)
      expect(getProjectPaths()).toEqual(originalProjects)

    it "move selected directory or directories(group) to top of project-list", ->
      spyOn(view, "getSelectedItem").andReturn(itemDirGitDir1)
      view.setToTopOfProjects()
      expect(getProjectPaths()).toEqual([gitDir1, normalDir1, normalDir2, gitDir2, gitDir3])
      jasmine.unspy(view, 'getSelectedItem')

      spyOn(view, "getSelectedItem").andReturn(itemDirNormalDir2)
      view.setToTopOfProjects()
      expect(getProjectPaths()).toEqual([normalDir2, gitDir1, normalDir1, gitDir2, gitDir3])
      jasmine.unspy(view, 'getSelectedItem')

      spyOn(view, "getSelectedItem").andReturn(itemGroupGit)
      view.setToTopOfProjects()
      expect(getProjectPaths()).toEqual([gitDir1, gitDir2, normalDir2, normalDir1, gitDir3])
