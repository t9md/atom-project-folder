const {existsSync} = require("fs")
const {CompositeDisposable} = require("atom")
const View = require("./view")
const settings = require("./settings")

const CONFIG_TEMPLATE = `\
# groups:
#   atom: [
#     "~/github/atom"
#     "~/github/text-buffer"
#     "~/github/atom-keymap"
#   ]
#   sample: [
#     "~/dir/hello-project"
#     "~/dir/world-project"
#   ]\
`

module.exports = {
  config: settings.config,

  activate() {
    this.view = new View()
    this.subscriptions = new CompositeDisposable(
      atom.commands.add("atom-workspace", {
        "project-folder:add": () => this.view.start("add"),
        "project-folder:remove": () => this.view.start("remove"),
        "project-folder:open-config": () => this.openConfig(),
      })
    )
  },

  deactivate() {
    this.subscriptions.dispose()
  },

  async openConfig() {
    const filePath = this.view.getConfigPath()
    const editor = await atom.workspace.open(filePath, {searchAllPanes: true})
    if (!existsSync(filePath)) {
      editor.setText(CONFIG_TEMPLATE)
      editor.save()
    }
    editor.onDidSave(() => this.view.loadConfig())
    return editor
  },
}
