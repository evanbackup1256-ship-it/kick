// url=https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK/Alleral-UI-Design-System
// source=ui/windui/aller.luau
// component=Toggle
import figma from "figma"
const instance = figma.selectedInstance

const title = instance.getString("Title")
const description = instance.getString("Description")
const defaultOn = instance.getBoolean("Default")

export default {
  example: figma.code`
section:Toggle("${title}", ${defaultOn}, "${description}", function(value)
  -- handler
end)
  `,
  id: "aller-toggle",
  metadata: { nestable: true, props: { title, description, defaultOn } },
}
