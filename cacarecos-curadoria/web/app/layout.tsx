import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cacarecos · Curadoria",
  description: "Triagem de peças de leilão pré-selecionadas para revenda curada.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body className="font-sans">{children}</body>
    </html>
  );
}
