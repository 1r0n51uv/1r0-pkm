import "./globals.css";
import type { ReactNode } from "react";

export const metadata = {
  title: "1r0-pkm",
  description: "1r0-gym, 1r0-diet, 1r0-note e altri moduli — dashboard",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="it">
      <body>{children}</body>
    </html>
  );
}
