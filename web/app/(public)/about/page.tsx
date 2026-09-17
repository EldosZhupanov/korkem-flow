import Link from "next/link";
import { 
  Layers, 
  ShieldCheck, 
  Cpu, 
  Target, 
  MapPin, 
  Mail, 
  Phone, 
  Server, 
  CheckCircle2,
  ArrowRight
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function AboutPage() {
  return (
    <div className="py-12 md:py-20">
      <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Hero */}
        <div className="max-w-3xl mx-auto text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            О проекте KORKEM Flow
          </Badge>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-foreground">
            Миссия: цифровая трансформация мебельного производства
          </h1>
          <p className="mt-4 text-base sm:text-lg text-muted-foreground leading-relaxed">
            Мы создаем программное обеспечение, устраняющее пропасть между проектированием мебели, станками с ЧПУ и складским учетом.
          </p>
        </div>

        {/* Narrative / Problem Statement */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center mb-20">
          <div className="lg:col-span-6 space-y-4">
            <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-foreground">
              Почему обычные CRM и Excel больше не справляются?
            </h2>
            <p className="text-sm text-muted-foreground leading-relaxed">
              Мебельное производство — одна из самых сложных отраслей малого и среднего бизнеса. Здесь нельзя просто продать товар со склада: каждое изделие состоит из десятков деталей ЛДСП разной толщины, метров кромочной ленты, петель, ручек и крепежа.
            </p>
            <p className="text-sm text-muted-foreground leading-relaxed">
              Универсальные CRM не знают, что такое направление текстуры дерева, толщина пропила пилы 4.2 мм или кромка ПВХ 2 мм с фрезеровкой. Технологи тратят часы на перенос данных из конструкторских программ в таблицы, а на складе образуются горы неучтенного обрезка.
            </p>
            <p className="text-sm text-muted-foreground leading-relaxed font-medium text-foreground">
              KORKEM объединяет весь этот путь в единый цифровой конвейер без двойного ввода данных.
            </p>
          </div>

          <div className="lg:col-span-6 rounded-2xl border border-border/80 bg-muted/30 p-8">
            <h3 className="text-lg font-bold text-foreground mb-4 flex items-center gap-2">
              <Target className="h-5 w-5 text-primary" />
              Ключевые принципы платформы
            </h3>
            <div className="space-y-4 text-xs">
              <div className="flex items-start gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0 mt-0.5" />
                <div>
                  <h4 className="font-semibold text-foreground">Практичность для цеха</h4>
                  <p className="text-muted-foreground mt-0.5">Интерфейсы спроектированы так, чтобы мастер у станка или замерщик на пыльном объекте мог внести данные в 2 нажатия.</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0 mt-0.5" />
                <div>
                  <h4 className="font-semibold text-foreground">Честная изоляция данных</h4>
                  <p className="text-muted-foreground mt-0.5">Строгая мультитенантность: ни одна компания не может увидеть заказы или складские запасы конкурента.</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0 mt-0.5" />
                <div>
                  <h4 className="font-semibold text-foreground">Надежный фундамент ERPNext</h4>
                  <p className="text-muted-foreground mt-0.5">В ядре системы работает промышленная платформа Frappe/ERPNext с открытыми стандартами и отказоустойчивой базой данных MariaDB.</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Technical Architecture Overview */}
        <div className="rounded-2xl border border-border/80 bg-card p-8 sm:p-12 mb-20 shadow-sm">
          <div className="max-w-2xl mb-8">
            <h3 className="text-2xl font-bold text-foreground">Архитектура системы</h3>
            <p className="mt-2 text-xs text-muted-foreground">
              Как взаимодействуют компоненты облака, цеховых компьютеров и мобильных устройств
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-xs">
            <div className="rounded-xl border bg-muted/20 p-5 space-y-2">
              <div className="flex items-center gap-2 text-primary font-bold">
                <Server className="h-4 w-4" />
                <span>Облачный сервер ERPNext</span>
              </div>
              <p className="text-muted-foreground">
                Центральное хранилище данных, авторизация по защищенным сессиям, реестр складов, номенклатуры и пользователей.
              </p>
            </div>
            <div className="rounded-xl border bg-muted/20 p-5 space-y-2">
              <div className="flex items-center gap-2 text-primary font-bold">
                <Cpu className="h-4 w-4" />
                <span>Десктоп & Мобильные клиенты</span>
              </div>
              <p className="text-muted-foreground">
                Кроссплатформенный движок Flutter: моментальный расчет раскроя, работа со сканерами, автономность при сбоях связи.
              </p>
            </div>
            <div className="rounded-xl border bg-muted/20 p-5 space-y-2">
              <div className="flex items-center gap-2 text-primary font-bold">
                <Layers className="h-4 w-4" />
                <span>Веб-портал KORKEM</span>
              </div>
              <p className="text-muted-foreground">
                Next.js 15 веб-приложение: управление предприятием, складские операции, настройки прав команды и аналитика из любого браузера.
              </p>
            </div>
          </div>
        </div>

        {/* Contacts */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="rounded-xl border border-border/60 p-6 bg-card space-y-2">
            <MapPin className="h-5 w-5 text-primary" />
            <h4 className="font-bold text-foreground text-sm">Локация</h4>
            <p className="text-xs text-muted-foreground">Республика Казахстан, г. Алматы / г. Астана</p>
          </div>
          <div className="rounded-xl border border-border/60 p-6 bg-card space-y-2">
            <Mail className="h-5 w-5 text-primary" />
            <h4 className="font-bold text-foreground text-sm">Электронная почта</h4>
            <p className="text-xs text-muted-foreground">support@korkem.asia</p>
          </div>
          <div className="rounded-xl border border-border/60 p-6 bg-card space-y-2">
            <Phone className="h-5 w-5 text-primary" />
            <h4 className="font-bold text-foreground text-sm">Техническая поддержка</h4>
            <p className="text-xs text-muted-foreground">Ежедневно с 09:00 до 20:00 (GMT+5)</p>
          </div>
        </div>
      </div>
    </div>
  );
}
