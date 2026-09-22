import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Syllogism Technology Africa",
  description: "Africa-first App Store & SaaS ecosystem",
  manifest: "/manifest.json",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}