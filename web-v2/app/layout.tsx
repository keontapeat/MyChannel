import type { Metadata, Viewport } from "next";
import "./globals.css";
import { MiniPlayerProvider } from "@/contexts/MiniPlayerContext";
import { AuthProvider } from "@/contexts/AuthContext";

export const metadata: Metadata = {
  title: "MyChannel - Your Channel. Your Future.",
  description: "The next-generation video platform combining YouTube + Twitch + DraftKings + UFC",
  keywords: ["video", "streaming", "live", "gaming", "content creation", "vs matches"],
  authors: [{ name: "MyChannel" }],
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/icon.svg", type: "image/svg+xml" },
    ],
    apple: "/apple-icon.svg",
  },
  manifest: "/manifest.json",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#FF0000",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased bg-white">
        <AuthProvider>
          <MiniPlayerProvider>
            {children}
          </MiniPlayerProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
