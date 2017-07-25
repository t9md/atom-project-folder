const {existsSync} = require("fs")
const {CompositeDisposable} = require("atom")
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
    this.view = new (require("./view"))()
    this.subscriptions = new CompositeDisposable()
    this.subscriptions.add(
      atom.commands.add("atom-workspace", {
        "project-folder:add": () => this.view.start("add"),
        "project-folder:remove": () => this.view.start("remove"),
        "project-folder:open-config": () => this.openConfig(),
      })
    )
  },

  deactivate() {
    this.subscriptions.dispose()
    this.subscriptions = null
    this.view = null
  },

  openConfig() {
    const filePath = this.view.getConfigPath()
    return atom.workspace.open(filePath, {searchAllPanes: true}).then(editor => {
      if (!existsSync(filePath)) {
        editor.setText(CONFIG_TEMPLATE)
        editor.save()
      }
      editor.onDidSave(() => this.view.loadConfig())
    })
  },
}
