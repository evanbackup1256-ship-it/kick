// url=https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK/Alleral-UI-Design-System?node-id=0-1
// source=ui/windui/aller.luau
// component=CreateWindow
import figma from "figma"
const instance = figma.selectedInstance

const title = instance.getString("Title")
const subtitle = instance.getString("Subtitle")
const profile = instance.getEnum("Profile", {
  Auto: "auto",
  Desktop: "desktop",
  Mobile: "mobile",
  Compact: "compact",
  Performance: "performance",
})

export default {
  example: figma.code`
local window = WindUI:CreateWindow({
  Title = "${title}",
  SubTitle = "${subtitle}",
  Theme = "Alleral",
  UICorner = 10,
  UIPadding = 24,
  SideBarWidth = 276,
  ElementPadding = 16,
  Resizable = true,
})
WindUI:ApplyProfile("${profile}")
WindUI:PolishWindow(window)
  `,
  imports: [],
  id: "aller-window",
  metadata: {
    nestable: false,
    props: { title, subtitle, profile },
  },
}
