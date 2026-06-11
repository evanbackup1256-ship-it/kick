// url=https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK/Alleral-UI-Design-System
// source=ui/windui/aller.luau
// component=Notify
import figma from "figma"
const instance = figma.selectedInstance

const title = instance.getString("Title")
const content = instance.getString("Content")
const type = instance.getEnum("Type", {
  Info: "info",
  Success: "success",
  Warn: "warn",
  Error: "error",
})

export default {
  example: figma.code`
WindUI:Notify({
  Title = "${title}",
  Content = "${content}",
  Type = "${type}",
  Duration = 4,
})
  `,
  id: "aller-notification",
  metadata: { nestable: true, props: { title, content, type } },
}
