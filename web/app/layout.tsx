import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: {
    default: 'KORKEM — Платформа автоматизации мебельного производства',
    template: '%s | KORKEM',
  },
  description:
    'Комплексная цифровая экосистема для мебельных фабрик и цехов: управление заказами, складом, раскроем, станками ЧПУ и персоналом.',
  keywords: [
    'мебельное производство',
    'ERP для мебели',
    'раскрой ЛДСП',
    'ЧПУ',
    'управление складом',
    'мебельный цех',
    'KORKEM',
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ru" className="h-full scroll-smooth">
      <body className="min-h-full bg-background text-foreground antialiased flex flex-col font-sans">
        {children}
      </body>
    </html>
  );
}
