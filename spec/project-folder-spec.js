"use babel"

const _path = require("path")

const {
  it,
  fit,
  ffit,
  fffit,
  emitterEventPromise,
  beforeEach,
  afterEach,
} = require("./async-spec-helpers")

const fs = require("fs-plus")
const fsx = require("fs-extra")
const {normalize} = fs
const temp = require("temp")

// Utility functions
// -------------------------
const setConfig = (name, value) => atom.config.set(`project-folder.${name}`, value)

const getConfig = name => atom.config.get(`project-folder.${name}`)

const getPath = file => normalize(joinPath(`${__dirname}/fixtures`, file))

const addProject = (...dirs) => dirs.map(dir => atom.project.addPath(dir))

const joinPath = _path.join

const dispatchCommand = (target, command) => atom.commands.dispatch(target, command)

const getProjectPaths = () => atom.project.getPaths()

function unindent(strings, ...values) {
  let result = ""
  let i = 0
  for (let rawString of strings.raw) {
    result += rawString.replace(/\\{2}/g, "\\") + (values.length ? values.shift() : "")
  }

  const lines = result.split(/\n/)
  lines.shift()
  lines.pop()

  const minIndent = lines.reduce((minIndent, line) => {
    return !line.match(/\S/) ? minIndent : Math.min(line.match(/ */)[0].length, minIndent)
  }, Infinity)
  return lines.map(line => line.slice(minIndent)).join("\n")
}

global.beforeEach(function() {
  this.addMatchers({
    toBeEqualItem(expected) {
      const line1 = this.actual.find("div").eq(0).text()
      const line2 = this.actual.find("div").eq(1).text()
      return line1 === _path.basename(expected) && normalize(line2) === getPath(expected)
    },
  })
})

// Main
// -------------------------
describe("project-folder", () => {
  let mainModule, view, filterEditorElement, workspaceElement

  const tempHome = fs.realpathSync(temp.mkdirSync("home"))
  const configPath = joinPath(tempHome, "project-folder.cson")

  // Normal
  const normalRoot = getPath("normal")
  const normalDir1 = getPath("normal/dir-1")
  const normalDir2 = getPath("normal/dir-2")
  const normalDirs = [normalDir1, normalDir2]

  // Git
  const gitRoot = fs.realpathSync(temp.mkdirSync("git"))
  const gitRootSource = getPath("git")
  fsx.copySync(gitRootSource, gitRoot)

  const gitDir1 = joinPath(gitRoot, "dir-1")
  const gitDir2 = joinPath(gitRoot, "dir-2")
  const gitDir3 = joinPath(gitRoot, "dir-3/depth2/depth3")
  fs.mkdirSync(joinPath(gitRoot, "dir-1/.git"))
  fs.mkdirSync(joinPath(gitRoot, "dir-2/.git"))
  fs.mkdirSync(joinPath(gitRoot, "dir-3/depth2/depth3/.git"))
  const gitDirs = [gitDir1, gitDir2, gitDir3]
  const gitRootDirs = [gitDir1, gitDir2, joinPath(gitRoot, "dir-3")]

  const itemGroupNormal = {name: "normal", dirs: [normalDir1, normalDir2]}
  const itemGroupGit = {name: "git", dirs: [gitDir1, gitDir2]}
  const itemDirNormalDir1 = {name: normalDir1, dirs: [normalDir1]}
  const itemDirNormalDir2 = {name: normalDir2, dirs: [normalDir2]}
  const itemDirGitDir1 = {name: gitDir1, dirs: [gitDir1]}
  const itemDirGitDir2 = {name: gitDir2, dirs: [gitDir2]}
  const itemDirGitDir3 = {name: gitDir3, dirs: [gitDir3]}

  function ensureSelectListItems(expectedItems) {
    const items = []
    for (let item of view.getItems()) {
      item.name = normalize(item.name)
      items.push(item)
    }
    expect(items).toEqual(expectedItems)
  }

  function ensureProjectPaths(...dirs) {
    expect(atom.project.getPaths()).toEqual(dirs)
  }

  beforeEach(async () => {
    setConfig("configPath", configPath)
    const fixturesDir = atom.project.getPaths()[0]
    atom.project.removePath(fixturesDir)

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)
    setConfig("projectRootDirectories", [normalRoot])

    const activationPromise = atom.packages.activatePackage("project-folder")
    atom.commands.dispatch(workspaceElement, "project-folder:add")
    mainModule = (await activationPromise).mainModule
    view = mainModule.view
    filterEditorElement = view.filterEditorView.element
    view.cancel()
  })

  afterEach(() => {
    if (view.panel.isVisible()) view.cancel()
  })

  describe("project-folder:add", () => {
    beforeEach(() => {
      dispatchCommand(workspaceElement, "project-folder:add")
      expect(view).toHaveClass("add")
      expect(view).not.toHaveClass("remove")
      const items = view.list.find("li")
      expect(items).toHaveLength(2)
      expect(items.eq(0)).toBeEqualItem("normal/dir-1")
      expect(items.eq(1)).toBeEqualItem("normal/dir-2")
    })
    it("add confirmed paths to projects 1st item", () => {
      dispatchCommand(filterEditorElement, "core:confirm")
      ensureProjectPaths(normalDir1)
      expect(view.panel.isVisible()).toBe(false)
    })
    it("add confirmed paths to projects 2nd item", () => {
      dispatchCommand(filterEditorElement, "core:move-down")
      dispatchCommand(filterEditorElement, "core:confirm")
      ensureProjectPaths(normalDir2)
      expect(view.panel.isVisible()).toBe(false)
    })

    describe("confirmAndContinue", () => {
      it("allow continuously add paths to projects", () => {
        ensureProjectPaths()
        expect(view.panel.isVisible()).toBe(true)
        dispatchCommand(filterEditorElement, "project-folder:confirm-and-continue")
        ensureProjectPaths(normalDir1)
        dispatchCommand(filterEditorElement, "project-folder:confirm-and-continue")
        ensureProjectPaths(normalDir1, normalDir2)
        expect(view.panel.isVisible()).toBe(true)
      })
    })
  })

  describe("hideLoadedFolderFromAddList", () => {
    beforeEach(() => spyOn(view, "getEmptyMessage").andCallThrough())

    describe("hideLoadedFolderFromAddList is true(default)", () => {
      it("hide already added paths from add list case-2", () => {
        addProject(normalDir1)
        dispatchCommand(workspaceElement, "project-folder:add")
        const items = view.list.find("li")
        expect(items).toHaveLength(1)
        expect(items.eq(0)).toBeEqualItem("normal/dir-2")
      })

      it("hide already added paths from add list case-1", () => {
        addProject(normalDir1, normalDir2)
        dispatchCommand(workspaceElement, "project-folder:add")
        expect(view).toHaveClass("add")
        expect(view.getEmptyMessage).toHaveBeenCalled()
      })
    })

    describe("hideLoadedFolderFromAddList is false", () => {
      it("not hide already added paths from add list", () => {
        setConfig("hideLoadedFolderFromAddList", false)
        addProject(normalDir1, normalDir2)
        dispatchCommand(workspaceElement, "project-folder:add")
        expect(view.list.find("li")).toHaveLength(2)
      })
    })
  })

  describe("project-folder:remove", () => {
    beforeEach(() => {
      addProject(normalDir1, normalDir2)
      expect(atom.project.getPaths()).toEqual([normalDir1, normalDir2])
      ensureProjectPaths(normalDir1, normalDir2)
      dispatchCommand(workspaceElement, "project-folder:remove")
      expect(view).toHaveClass("remove")
      const items = view.list.find("li")
      expect(items).toHaveLength(2)
      expect(items.eq(0)).toBeEqualItem("normal/dir-1")
      expect(items.eq(1)).toBeEqualItem("normal/dir-2")
    })

    it("remove confirmed paths from projects 1st", () => {
      dispatchCommand(filterEditorElement, "core:confirm")
      expect(atom.project.getPaths()).toEqual([normalDir2])
    })

    it("add confirmed paths to projects 2nd", () => {
      dispatchCommand(filterEditorElement, "core:move-down")
      dispatchCommand(filterEditorElement, "core:confirm")
      expect(atom.project.getPaths()).toEqual([normalDir1])
    })

    describe("confirmAndContinue", () => {
      it("allow continuously remove paths from projects", () => {
        dispatchCommand(filterEditorElement, "project-folder:confirm-and-continue")
        expect(atom.project.getPaths()).toEqual([normalDir2])
        dispatchCommand(filterEditorElement, "project-folder:confirm-and-continue")
        expect(atom.project.getPaths()).toEqual([])
      })
    })
  })

  describe("view::add", () => {
    it("add directory to project", () => {
      view.add(normalDir1)
      view.add(normalDir2)
      expect(atom.project.getPaths()).toEqual([normalDir1, normalDir2])
    })
  })

  describe("view::remove", () => {
    it("remove directory from project", () => {
      addProject(normalDir1, normalDir2)
      view.remove(normalDir1)
      expect(atom.project.getPaths()).toEqual([normalDir2])
      view.remove(normalDir2)
      expect(atom.project.getPaths()).toEqual([])
    })
  })

  describe("closeItemsForRemovedProject", () => {
    const file1 = getPath("normal/dir-1/dir-1.js")
    const file2 = getPath("normal/dir-2/dir-2.js")

    beforeEach(async () => {
      setConfig("closeItemsForRemovedProject", true)
      addProject(normalDir1, normalDir2)
      await atom.workspace.open(file1)
      await atom.workspace.open(file2)
      const files = atom.workspace.getTextEditors().map(e => e.getPath())
      expect(files).toEqual([file1, file2])
    })

    it("close editor for removed project", () => {
      view.remove(normalDir2)
      const files = atom.workspace.getTextEditors().map(e => e.getPath())
      expect(files).toEqual([file1])
    })

    it("focus remaining editor when originally focused editor was destrouyed", () => {
      const pane = atom.workspace.getActivePane()
      const editor1 = pane.itemForURI(file1)
      const editor2 = pane.itemForURI(file2)
      pane.activateItem(editor1)
      expect(editor1.element.hasFocus()).toBe(true)

      dispatchCommand(workspaceElement, "project-folder:remove")
      ensureSelectListItems([itemDirNormalDir1, itemDirNormalDir2])
      dispatchCommand(filterEditorElement, "core:confirm")
      dispatchCommand(filterEditorElement, "core:cancel")

      const files = atom.workspace.getTextEditors().map(e => e.getPath())
      expect(files).toEqual([file2])
      expect(editor1.isAlive()).toBe(false)
      expect(editor2.element.hasFocus()).toBe(true)
    })
  })

  describe("view::replace", () => {
    it("remove all project except passed one", () => {
      addProject(normalDir1, normalDir2)
      spyOn(view, "getSelectedItem").andReturn(itemDirGitDir1)
      view.replace()
      expect(atom.project.getPaths()).toEqual([gitDir1])
    })
  })

  describe("view::getNormalDirectories", () => {
    it("get directories case-1", () => {
      setConfig("projectRootDirectories", [normalRoot])
      expect(view.getNormalDirectories()).toEqual(normalDirs)
    })

    it("get directories case-2", () => {
      setConfig("projectRootDirectories", [normalRoot, gitRoot])
      expect(view.getNormalDirectories()).toEqual(normalDirs.concat(gitRootDirs))
    })
  })

  describe("view::getGitDirectories", () => {
    describe("gitProjectDirectories config is empty(default)", () => {
      it("return empty list", () => {
        expect(view.getGitDirectories()).toEqual([])
      })
    })

    describe("gitProjectDirectories is set", () => {
      it("return directories which contains .git", () => {
        setConfig("gitProjectDirectories", [gitRoot])
        expect(view.getGitDirectories()).toEqual([gitDir1, gitDir2, gitDir3])
      })
    })

    describe("gitProjectSearchMaxDepth is 2", () => {
      it("search .git directory 2 depth at maximum", () => {
        setConfig("gitProjectDirectories", [gitRoot])
        setConfig("gitProjectSearchMaxDepth", 1)
        expect(view.getGitDirectories()).toEqual([gitDir1, gitDir2])
      })
    })
  })

  describe("view::openInNewWindow", () => {
    it("open selected project in new window", () => {
      spyOn(view, "getSelectedItem").andReturn(itemDirNormalDir1)
      spyOn(atom, "open")
      view.openInNewWindow()
      expect(atom.open).toHaveBeenCalledWith({
        pathsToOpen: [normalDir1],
        newWindow: true,
        devMode: atom.inDevMode(),
      })
    })
  })

  describe("user defined project-group", () => {
    let userConfigEditor = null

    beforeEach(async () => {
      userConfigEditor = await mainModule.openConfig()
    })

    describe("user config file", () => {
      it("opens editor in configPath", () => {
        expect(userConfigEditor.getPath()).toBe(configPath)
      })
      it("load config on save", async () => {
        dispatchCommand(workspaceElement, "project-folder:add")
        expect(view).toHaveClass("add")

        ensureSelectListItems([itemDirNormalDir1, itemDirNormalDir2])

        view.cancel()
        expect(view.getItemsForGroups()).toEqual([])
        userConfigEditor.setText(unindent`
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
        `)

        await userConfigEditor.save()

        const itemGroupAtom = {
          name: "atom",
          dirs: ["~/github/atom.org", "~/github/text-buffer", "~/github/atom-keymap"].map(
            normalize
          ),
        }

        const itemGroupHello = {
          name: "hello",
          dirs: ["~/dir/hello-project", "~/dir/world-project"].map(normalize),
        }

        expect(view.getItemsForGroups()).toEqual([itemGroupAtom, itemGroupHello])

        dispatchCommand(workspaceElement, "project-folder:add")
        expect(view).toHaveClass("add")
        ensureSelectListItems([itemGroupAtom, itemGroupHello, itemDirNormalDir1, itemDirNormalDir2])
      })
    })

    describe("add/remove groups of project", () => {
      beforeEach(async () => {
        setConfig("gitProjectDirectories", [gitRoot])

        // By changing showGroupOnRemoveListCondition from default 'never' to
        // 'some-member-was-loaded', we can test removal of group.
        setConfig("showGroupOnRemoveListCondition", "some-member-was-loaded")

        userConfigEditor.setText(unindent`
          groups:
            normal: [
              "${normalDir1}"
              "${normalDir2}"
            ]
            git: [
              "${gitDir1}"
              "${gitDir2}"
            ]
        `)
        await Promise.resolve(userConfigEditor.save())
        expect(view.getItemsForGroups()).toHaveLength(2)
      })

      it("add/remove set of project defined in groups", () => {
        dispatchCommand(workspaceElement, "project-folder:add")
        expect(view).toHaveClass("add")
        ensureSelectListItems([
          itemGroupNormal,
          itemGroupGit,
          itemDirNormalDir1,
          itemDirNormalDir2,
          itemDirGitDir1,
          itemDirGitDir2,
          itemDirGitDir3,
        ])

        // Confirm group 'normal'
        ensureProjectPaths()
        expect(view.panel.isVisible()).toBe(true)
        dispatchCommand(filterEditorElement, "core:confirm")
        ensureProjectPaths(normalDir1, normalDir2)

        // Confirm group 'git'
        dispatchCommand(workspaceElement, "project-folder:add")
        dispatchCommand(filterEditorElement, "core:confirm")
        ensureProjectPaths(normalDir1, normalDir2, gitDir1, gitDir2)

        // Remove group 'normal'
        dispatchCommand(workspaceElement, "project-folder:remove")
        dispatchCommand(filterEditorElement, "core:confirm")
        ensureProjectPaths(gitDir1, gitDir2)

        // Remove group 'git'
        dispatchCommand(workspaceElement, "project-folder:remove")
        dispatchCommand(filterEditorElement, "core:confirm")
        ensureProjectPaths()
      })

      it("by default(hideLoadedFolderFromAddList is true) hide from add list if all member is already loaded", () => {
        dispatchCommand(workspaceElement, "project-folder:add")
        expect(view).toHaveClass("add")

        ensureSelectListItems([
          itemGroupNormal,
          itemGroupGit,
          itemDirNormalDir1,
          itemDirNormalDir2,
          itemDirGitDir1,
          itemDirGitDir2,
          itemDirGitDir3,
        ])

        view.add(normalDir1)
        ensureSelectListItems([
          itemGroupNormal,
          itemGroupGit,
          itemDirNormalDir2,
          itemDirGitDir1,
          itemDirGitDir2,
          itemDirGitDir3,
        ])

        view.add(normalDir2)
        ensureSelectListItems([itemGroupGit, itemDirGitDir1, itemDirGitDir2, itemDirGitDir3])

        view.add(gitDir1)
        ensureSelectListItems([itemGroupGit, itemDirGitDir2, itemDirGitDir3])

        view.add(gitDir2)
        ensureSelectListItems([itemDirGitDir3])
      })

      describe("showGroupOnRemoveListCondition", () => {
        describe("never", () => {
          beforeEach(() => {
            setConfig("showGroupOnRemoveListCondition", "never")
          })

          it("doesn't show group on removal list", () => {
            addProject(normalDir1, normalDir2, gitDir1, gitDir2)
            dispatchCommand(workspaceElement, "project-folder:remove")
            expect(view).toHaveClass("remove")

            ensureSelectListItems([
              itemDirNormalDir1,
              itemDirNormalDir2,
              itemDirGitDir1,
              itemDirGitDir2,
            ])

            view.remove(normalDir1)
            view.remove(gitDir1)
            ensureSelectListItems([itemDirNormalDir2, itemDirGitDir2])

            view.remove(gitDir2)
            ensureSelectListItems([itemDirNormalDir2])
            view.remove(normalDir2)
            ensureSelectListItems([])
          })
        })

        describe("some-member-was-loaded", () => {
          beforeEach(() => setConfig("showGroupOnRemoveListCondition", "some-member-was-loaded"))
          it("show up on removal list as long as at least one member was loaded", () => {
            addProject(normalDir1, normalDir2, gitDir1, gitDir2)
            dispatchCommand(workspaceElement, "project-folder:remove")
            expect(view).toHaveClass("remove")

            ensureSelectListItems([
              itemGroupNormal,
              itemGroupGit,
              itemDirNormalDir1,
              itemDirNormalDir2,
              itemDirGitDir1,
              itemDirGitDir2,
            ])

            view.remove(normalDir1)
            view.remove(gitDir1)
            ensureSelectListItems([
              itemGroupNormal,
              itemGroupGit,
              itemDirNormalDir2,
              itemDirGitDir2,
            ])

            view.remove(gitDir2)
            ensureSelectListItems([itemGroupNormal, itemDirNormalDir2])

            view.remove(normalDir2)
            ensureSelectListItems([])
          })
        })

        describe("all-member-was-loaded", () => {
          beforeEach(() => setConfig("showGroupOnRemoveListCondition", "all-member-was-loaded"))
          it("show group if all member project of that group was loaded", () => {
            addProject(normalDir1, normalDir2, gitDir1, gitDir2)
            dispatchCommand(workspaceElement, "project-folder:remove")
            expect(view).toHaveClass("remove")

            ensureSelectListItems([
              itemGroupNormal,
              itemGroupGit,
              itemDirNormalDir1,
              itemDirNormalDir2,
              itemDirGitDir1,
              itemDirGitDir2,
            ])

            view.remove(normalDir1)
            ensureSelectListItems([itemGroupGit, itemDirNormalDir2, itemDirGitDir1, itemDirGitDir2])

            view.remove(gitDir1)
            ensureSelectListItems([itemDirNormalDir2, itemDirGitDir2])

            view.remove(normalDir2)
            view.remove(gitDir2)
            ensureSelectListItems([])
          })
        })
      })
    })
  })

  describe("project-folder:set-to-top-of-projects", () => {
    const originalProjects = [normalDir1, normalDir2, gitDir1, gitDir2, gitDir3]
    beforeEach(() => {
      addProject(...originalProjects)
      expect(atom.project.getPaths()).toEqual(originalProjects)
    })

    it("move selected directory or directories(group) to top of project-list", () => {
      spyOn(view, "getSelectedItem").andReturn(itemDirGitDir1)
      view.setToTopOfProjects()
      expect(atom.project.getPaths()).toEqual([gitDir1, normalDir1, normalDir2, gitDir2, gitDir3])
      jasmine.unspy(view, "getSelectedItem")

      spyOn(view, "getSelectedItem").andReturn(itemDirNormalDir2)
      view.setToTopOfProjects()
      expect(atom.project.getPaths()).toEqual([normalDir2, gitDir1, normalDir1, gitDir2, gitDir3])
      jasmine.unspy(view, "getSelectedItem")

      spyOn(view, "getSelectedItem").andReturn(itemGroupGit)
      view.setToTopOfProjects()
      expect(atom.project.getPaths()).toEqual([gitDir1, gitDir2, normalDir2, normalDir1, gitDir3])
    })
  })
})
