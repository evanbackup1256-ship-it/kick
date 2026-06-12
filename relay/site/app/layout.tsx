import type { Metadata } from "next";
import { Outfit, IBM_Plex_Mono } from "next/font/google";
import { LenisProvider } from "@/components/providers/LenisProvider";
import { HomePage } from "@/components/HomePage";
import "./globals.css";

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
  display: "swap",
});

const plexMono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Alleral",
  description: "Roblox scripts with live status, auto-updates, and a cinematic hub experience.",
  themeColor: "#030508",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${outfit.variable} ${plexMono.variable}`}>
      <body className="site-body">
        <LenisProvider>{children}</LenisProvider>
      </body>
    </html>
  );
}
