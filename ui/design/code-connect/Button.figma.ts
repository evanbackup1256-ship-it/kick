// url=https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK/Alleral-UI-Design-System
// source=ui/windui/aller.luau
// component=Button
import figma from "figma"
const instance = figma.selectedInstance

const title = instance.getString("Title")
const description = instance.getString("Description")

export default {
  example: figma.code`
section:Button({
  Title = "${title}",
  Desc = "${description}",
  Callback = function()
    -- action
  end,
})
  `,
  id: "aller-button",
  metadata: { nestable: true, props: { title, description } },
}
