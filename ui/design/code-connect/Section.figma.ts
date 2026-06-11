// url=https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK/Alleral-UI-Design-System
// source=ui/windui/aller.luau
// component=Section
import figma from "figma"
const instance = figma.selectedInstance

const title = instance.getString("Title")
const side = instance.getEnum("Side", {
  Left: "Left",
  Right: "Right",
  Full: "Full",
})

export default {
  example: figma.code`
local section = tab:Section({
  Title = "${title}",
  Side = "${side}",
})
  `,
  id: "aller-section",
  metadata: { nestable: true, props: { title, side } },
}
