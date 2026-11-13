import type { Metadata } from 'next';
import { Manrope, Golos_Text, JetBrains_Mono } from 'next/font/google';
import './globals.css';

const display = Manrope({
  subsets: ['cyrillic', 'latin'],
  weight: ['500', '600', '700', '800'],
  variable: '--font-display',
  display: 'swap',
});

const sans = Golos_Text({
  subsets: ['cyrillic', 'latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-sans',
  display: 'swap',
});

const mono = JetBrains_Mono({
  subsets: ['cyrillic', 'latin'],
  weight: ['400', '500', '600'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: {
    default: 'KORKEM Flow — Операционная система мебельного производства',
    template: '%s | KORKEM Flow',
  },
  description:
    'Единая AI-native система для мебельных фабрик и цехов: заказы МДФ, раскладка на вакуумный пресс, отдел плёнки ПВХ, импорт из БАЗИС-Мебельщик, склад и сдельная оплата.',
  keywords: [
    'мебельное производство',
    'ERP для мебели',
    'раскладка на пресс',
    'заказы МДФ',
    'плёнка ПВХ',
    'БАЗИС-Мебельщик',
    'KORKEM Flow',
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ru" className={`h-full scroll-smooth ${display.variable} ${sans.variable} ${mono.variable}`}>
      <body className="min-h-full bg-background text-foreground antialiased flex flex-col font-sans selection:bg-[#C9A25B]/30 selection:text-[#F7F5EE]">
        {children}
      </body>
    </html>
  );
}
