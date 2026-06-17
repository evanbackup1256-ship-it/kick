import type { Metadata, Viewport } from "next";
import { JetBrains_Mono, Space_Grotesk, Geist } from "next/font/google";
import { Toaster } from "sonner";
import "./globals.css";
import { cn } from "@/lib/utils";

const geist = Geist({subsets:['latin'],variable:'--font-sans'});

const space = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-space",
  display: "swap",
  preload: true,
});

const jetbrains = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-mono",
  display: "swap",
  preload: false,
});

export const metadata: Metadata = {
  title: "Alleral — Script Hub",
  description: "Roblox scripts that stay updated. Live game status, one loadstring, executor list from WEAO.",
};

export const viewport: Viewport = {
  themeColor: "#010102",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={cn(space.variable, jetbrains.variable, "font-sans", geist.variable)}>
      <body className="site-body hub-shell">
        {children}
        <Toaster
          theme="dark"
          position="bottom-right"
          visibleToasts={3}
          gap={8}
          toastOptions={{
            unstyled: true,
            classNames: {
              toast: "panel-raised px-4 py-3 text-sm border-accent/20",
            },
          }}
        />
      </body>
    </html>
  );
}
