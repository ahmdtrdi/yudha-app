import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Yudha App - Admin Content Quality & Triage',
  description: 'Server-managed administrative portal for question quality review, distractor analysis, triage cases, and inventory management.'
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className="antialiased">{children}</body>
    </html>
  );
}
