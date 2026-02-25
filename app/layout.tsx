import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "CenterHub",
  description: "CenterHub childcare management app"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
