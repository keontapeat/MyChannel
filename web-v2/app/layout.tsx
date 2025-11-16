import type { Metadata } from "next";
import "./globals.css";
import { MiniPlayerProvider } from "@/contexts/MiniPlayerContext";

export const metadata: Metadata = {
  title: "MyChannel - Your Channel. Your Future.",
  description: "The next-generation video platform combining YouTube + Twitch + DraftKings + UFC",
  keywords: ["video", "streaming", "live", "gaming", "content creation", "vs matches"],
  authors: [{ name: "MyChannel" }],
  viewport: "width=device-width, initial-scale=1",
  themeColor: "#FF0000",
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased bg-white">
        <MiniPlayerProvider>
          {children}
        </MiniPlayerProvider>
      </body>
    </html>
  );
}
