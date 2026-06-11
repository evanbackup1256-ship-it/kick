// url=https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK/Alleral-UI-Design-System
// source=ui/windui/aller.luau
// component=Tab
import figma from "figma"
const instance = figma.selectedInstance

const name = instance.getString("Label")
const icon = instance.getString("Icon")

export default {
  example: figma.code`
local tab = window:Tab({
  Title = "${name}",
  Icon = "${icon}",
})
  `,
  id: "aller-tab",
  metadata: { nestable: true, props: { name, icon } },
}
