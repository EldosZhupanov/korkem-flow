import Link from "next/link";
import { Layers, ShieldCheck, Heart } from "lucide-react";

export function PublicFooter() {
  return (
    <footer className="border-t border-border/60 bg-muted/30">
      <div className="container mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8 lg:py-16">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 lg:gap-12">
          {/* Brand Col */}
          <div className="space-y-4 md:col-span-1">
            <Link href="/" className="flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground shadow-sm">
                <Layers className="h-4 w-4" />
              </div>
              <span className="text-lg font-bold tracking-tight text-foreground">
                KORKEM
              </span>
            </Link>
            <p className="text-xs text-muted-foreground leading-relaxed">
              Единая операционная система для мебельных производств: от расчета спецификации и раскроя до управления цехом, складом и отгрузкой.
            </p>
            <div className="flex items-center gap-2 text-xs text-muted-foreground pt-1">
              <ShieldCheck className="h-4 w-4 text-emerald-600" />
              <span>Корпоративная изоляция данных</span>
            </div>
          </div>

          {/* Col 1: Решения */}
          <div className="space-y-3">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-foreground">
              Платформа
            </h4>
            <ul className="space-y-2 text-xs text-muted-foreground">
              <li>
                <Link href="/features" className="hover:text-foreground transition-colors">
                  Возможности системы
                </Link>
              </li>
              <li>
                <Link href="/download" className="hover:text-foreground transition-colors">
                  Центр загрузок (Android & Windows)
                </Link>
              </li>
              <li>
                <Link href="/about" className="hover:text-foreground transition-colors">
                  О платформе и архитектуре
                </Link>
              </li>
              <li>
                <Link href="/app" className="hover:text-foreground transition-colors">
                  Веб-кабинет компании
                </Link>
              </li>
            </ul>
          </div>

          {/* Col 2: Возможности цеха */}
          <div className="space-y-3">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-foreground">
              Модули цеха
            </h4>
            <ul className="space-y-2 text-xs text-muted-foreground">
              <li>
                <span className="hover:text-foreground transition-colors">
                  Оптимизация раскроя и ЧПУ
                </span>
              </li>
              <li>
                <span className="hover:text-foreground transition-colors">
                  Склад ЛДСП, кромки и фурнитуры
                </span>
              </li>
              <li>
                <span className="hover:text-foreground transition-colors">
                  Договоры, спецификации и счета
                </span>
              </li>
              <li>
                <span className="hover:text-foreground transition-colors">
                  Интеграция Kaspi Pay и WhatsApp
                </span>
              </li>
            </ul>
          </div>

          {/* Col 3: Доступ */}
          <div className="space-y-3">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-foreground">
              Аккаунт
            </h4>
            <ul className="space-y-2 text-xs text-muted-foreground">
              <li>
                <Link href="/login" className="hover:text-foreground transition-colors">
                  Вход в систему
                </Link>
              </li>
              <li>
                <Link href="/register" className="hover:text-foreground transition-colors">
                  Регистрация производства
                </Link>
              </li>
              <li>
                <Link href="/forgot-password" className="hover:text-foreground transition-colors">
                  Восстановление доступа
                </Link>
              </li>
              <li>
                <a 
                  href="https://api.korkem.asia" 
                  target="_blank" 
                  rel="noreferrer"
                  className="hover:text-foreground transition-colors"
                >
                  ERPNext Core API
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-12 border-t border-border/40 pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-muted-foreground">
          <p>© {new Date().getFullYear()} KORKEM Flow. Все права защищены. Казахстан.</p>
          <div className="flex items-center gap-1">
            <span>Создано для мебельных мастеров и фабрик</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
