import Link from "next/link";
import { 
  ArrowRight, 
  CheckCircle2, 
  Layers, 
  Cpu, 
  Boxes, 
  Users, 
  Smartphone, 
  Laptop, 
  Globe, 
  ShieldCheck, 
  Download, 
  Sparkles,
  BarChart3,
  FileSpreadsheet,
  Workflow
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";

export default function HomePage() {
  return (
    <div className="flex flex-col">
      {/* Hero Section */}
      <section className="relative overflow-hidden border-b border-border/40 bg-gradient-to-b from-muted/30 via-background to-background py-20 md:py-32">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 text-center relative z-10">
          <div className="inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/5 px-4 py-1.5 text-xs font-medium text-primary mb-6 animate-in fade-in slide-in-from-bottom-2">
            <Sparkles className="h-3.5 w-3.5" />
            <span>KORKEM Cloud & Desktop Suite 2026</span>
          </div>

          <h1 className="text-4xl sm:text-5xl md:text-6xl font-extrabold tracking-tight text-foreground max-w-4xl mx-auto leading-[1.15]">
            Умное управление мебельным производством{" "}
            <span className="bg-gradient-to-r from-primary to-blue-600 bg-clip-text text-transparent">
              без хаоса и потерь
            </span>
          </h1>

          <p className="mt-6 text-lg sm:text-xl text-muted-foreground max-w-2xl mx-auto leading-relaxed">
            Единая цифровая среда для фабрик и мебельных цехов: от замера и автоматического раскроя до управления складом, станками ЧПУ и отгрузкой клиенту.
          </p>

          {/* CTA Buttons */}
          <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            <Button size="lg" className="w-full sm:w-auto gap-2 text-base px-8 h-12 shadow-md" asChild>
              <Link href="/register">
                <span>Попробовать бесплатно</span>
                <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
            <Button size="lg" variant="outline" className="w-full sm:w-auto gap-2 text-base px-8 h-12" asChild>
              <Link href="/download">
                <Download className="h-4 w-4" />
                <span>Скачать приложения</span>
              </Link>
            </Button>
          </div>

          {/* Value Badges */}
          <div className="mt-12 flex flex-wrap items-center justify-center gap-6 text-xs text-muted-foreground">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-emerald-600" />
              <span>Android APK & Windows Desktop</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-emerald-600" />
              <span>Оптимизация карт раскроя до 94%</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-emerald-600" />
              <span>Изолированная база данных компании</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-emerald-600" />
              <span>Синхронизация с ERPNext</span>
            </div>
          </div>
        </div>

        {/* Decorative background glow */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[300px] bg-primary/5 blur-[120px] pointer-events-none -z-0 rounded-full" />
      </section>

      {/* Ecosystem Architecture (Mobile + Desktop + Web) */}
      <section className="py-16 md:py-24 bg-muted/20 border-b border-border/40">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-3xl mx-auto mb-16">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-primary mb-2">
              Кроссплатформенная экосистема
            </h2>
            <h3 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
              Каждый сотрудник работает в удобном инструменте
            </h3>
            <p className="mt-4 text-sm text-muted-foreground">
              KORKEM объединяет все участки мебельного предприятия в единую синхронную сеть.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Platform 1: Mobile */}
            <Card className="border-border/60 hover:shadow-md transition-shadow relative overflow-hidden">
              <div className="h-2 bg-emerald-500 w-full" />
              <CardHeader>
                <div className="h-12 w-12 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center mb-2">
                  <Smartphone className="h-6 w-6" />
                </div>
                <CardTitle className="text-xl">Мобильное приложение</CardTitle>
                <CardDescription>Android & iOS смартфоны и планшеты</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3 text-sm text-muted-foreground">
                <p>
                  Для замерщиков, дизайнеров и мастеров цеха. Быстрый прием заказов, фотофиксация объектов, сканирование штрихкодов деталей и отметка этапов сборки.
                </p>
                <ul className="space-y-1.5 pt-2 text-xs text-foreground">
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" /> Замерный лист и фото с объекта
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" /> Контроль статуса заказа в цеху
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" /> Автономная работа при перебоях сети
                  </li>
                </ul>
              </CardContent>
            </Card>

            {/* Platform 2: Desktop */}
            <Card className="border-border/60 hover:shadow-md transition-shadow relative overflow-hidden">
              <div className="h-2 bg-blue-500 w-full" />
              <CardHeader>
                <div className="h-12 w-12 rounded-xl bg-blue-500/10 text-blue-600 flex items-center justify-center mb-2">
                  <Laptop className="h-6 w-6" />
                </div>
                <CardTitle className="text-xl">Десктопная станция</CardTitle>
                <CardDescription>Windows x64 & macOS рабочие места</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3 text-sm text-muted-foreground">
                <p>
                  Для технологов, конструкторов и операторов распиловочных центров. Высокопроизводительный расчет карт раскроя, работа с ЧПУ и печать этикеток.
                </p>
                <ul className="space-y-1.5 pt-2 text-xs text-foreground">
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-blue-500" /> Генерация раскроя плит ЛДСП
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-blue-500" /> Прямой экспорт G-code для ЧПУ
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-blue-500" /> Печать бирок со штрихкодами
                  </li>
                </ul>
              </CardContent>
            </Card>

            {/* Platform 3: Web Portal */}
            <Card className="border-border/60 hover:shadow-md transition-shadow relative overflow-hidden">
              <div className="h-2 bg-primary w-full" />
              <CardHeader>
                <div className="h-12 w-12 rounded-xl bg-primary/10 text-primary flex items-center justify-center mb-2">
                  <Globe className="h-6 w-6" />
                </div>
                <CardTitle className="text-xl">Веб-портал KORKEM</CardTitle>
                <CardDescription>Доступ из любого браузера 24/7</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3 text-sm text-muted-foreground">
                <p>
                  Для владельцев фабрик, директоров и начальников складов. Комплексный обзор бизнеса, складской учет, управление командой и настройка процессов.
                </p>
                <ul className="space-y-1.5 pt-2 text-xs text-foreground">
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-primary" /> Профиль фабрики и реквизиты
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-primary" /> Управление складами и остатками
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-3.5 w-3.5 text-primary" /> Контроль персонала и ролей
                  </li>
                </ul>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* 4 Core Furniture Modules */}
      <section className="py-20 md:py-28">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-3xl mx-auto mb-16">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-primary mb-2">
              Функциональные возможности
            </h2>
            <h3 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
              Специализированные инструменты для мебельного бизнеса
            </h3>
            <p className="mt-4 text-sm text-muted-foreground">
              В отличие от универсальных таблиц, KORKEM изначально спроектирован под специфику раскроя, плитных материалов, фурнитуры и цеховых участков.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {/* Card 1 */}
            <div className="rounded-2xl border border-border/60 bg-card p-8 shadow-sm hover:border-primary/40 transition-colors">
              <div className="flex items-center gap-4 mb-4">
                <div className="h-10 w-10 rounded-lg bg-blue-500/10 text-blue-600 flex items-center justify-center">
                  <Workflow className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-foreground">CRM и расчет мебельных заказов</h4>
                  <p className="text-xs text-muted-foreground">От лида до готового изделия</p>
                </div>
              </div>
              <p className="text-sm text-muted-foreground mb-4 leading-relaxed">
                Быстрое формирование спецификации корпусной мебели: габариты, материалы корпуса, фасады, кромка и фурнитура. Автоматический расчет себестоимости с учетом норм расхода и трудоемкости.
              </p>
              <div className="flex flex-wrap gap-2 text-xs">
                <Badge variant="secondary">Спецификация изделия</Badge>
                <Badge variant="secondary">Договоры и КП</Badge>
                <Badge variant="secondary">Kaspi & WhatsApp</Badge>
              </div>
            </div>

            {/* Card 2 */}
            <div className="rounded-2xl border border-border/60 bg-card p-8 shadow-sm hover:border-primary/40 transition-colors">
              <div className="flex items-center gap-4 mb-4">
                <div className="h-10 w-10 rounded-lg bg-purple-500/10 text-purple-600 flex items-center justify-center">
                  <Cpu className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-foreground">Оптимизация раскроя и ЧПУ</h4>
                  <p className="text-xs text-muted-foreground">Минимум отходов листовых материалов</p>
                </div>
              </div>
              <p className="text-sm text-muted-foreground mb-4 leading-relaxed">
                Умный алгоритм 2D-раскроя учитывает текстуру дерева, ширину пропила пилы и кромку. Создает наглядные карты раскроя для распиловщика и экспортирует программы для фрезерных и присадочных ЧПУ станков.
              </p>
              <div className="flex flex-wrap gap-2 text-xs">
                <Badge variant="secondary">Выход годного до 94%</Badge>
                <Badge variant="secondary">Учет направления волокон</Badge>
                <Badge variant="secondary">ЧПУ G-Code</Badge>
              </div>
            </div>

            {/* Card 3 */}
            <div className="rounded-2xl border border-border/60 bg-card p-8 shadow-sm hover:border-primary/40 transition-colors">
              <div className="flex items-center gap-4 mb-4">
                <div className="h-10 w-10 rounded-lg bg-amber-500/10 text-amber-600 flex items-center justify-center">
                  <Boxes className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-foreground">Складской учет материалов и делового остатка</h4>
                  <p className="text-xs text-muted-foreground">Точный баланс ЛДСП, кромки и петель</p>
                </div>
              </div>
              <p className="text-sm text-muted-foreground mb-4 leading-relaxed">
                Многоскладской учет: разделение основного склада плит, склада фурнитуры и зоны готовой продукции. Регистрация делового обрезка для повторного использования в будущих заказах.
              </p>
              <div className="flex flex-wrap gap-2 text-xs">
                <Badge variant="secondary">Многоскладской учет</Badge>
                <Badge variant="secondary">Учет делового обрезка</Badge>
                <Badge variant="secondary">Автосписание под заказ</Badge>
              </div>
            </div>

            {/* Card 4 */}
            <div className="rounded-2xl border border-border/60 bg-card p-8 shadow-sm hover:border-primary/40 transition-colors">
              <div className="flex items-center gap-4 mb-4">
                <div className="h-10 w-10 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
                  <Users className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-foreground">Команда и роли в производстве</h4>
                  <p className="text-xs text-muted-foreground">Четкое распределение обязанностей</p>
                </div>
              </div>
              <p className="text-sm text-muted-foreground mb-4 leading-relaxed">
                Гибкие права доступа для директора, технолога-конструктора, снабженца, мастера смены и сборщика. Каждый сотрудник видит только свой объем работы без лишней информации.
              </p>
              <div className="flex flex-wrap gap-2 text-xs">
                <Badge variant="secondary">Ролевая модель</Badge>
                <Badge variant="secondary">Приглашения по email</Badge>
                <Badge variant="secondary">Аудит действий</Badge>
              </div>
            </div>
          </div>

          <div className="mt-12 text-center">
            <Button variant="outline" size="lg" asChild>
              <Link href="/features" className="gap-2">
                <span>Подробный обзор всех модулей</span>
                <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Security & Multi-tenancy Callout */}
      <section className="py-16 bg-muted/40 border-y border-border/40">
        <div className="container mx-auto max-w-5xl px-4 text-center">
          <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600 mb-4">
            <ShieldCheck className="h-6 w-6" />
          </div>
          <h3 className="text-2xl font-bold tracking-tight text-foreground sm:text-3xl">
            Безопасность и полная конфиденциальность
          </h3>
          <p className="mt-3 text-sm text-muted-foreground max-w-2xl mx-auto">
            Каждое производство изолировано на уровне сущностей ERPNext и базы данных. Ваши клиенты, себестоимость материалов, чертежи и контакты поставщиков доступны только авторизованным сотрудникам вашей компании.
          </p>
        </div>
      </section>

      {/* Bottom CTA Banner */}
      <section className="py-20">
        <div className="container mx-auto max-w-5xl px-4">
          <div className="rounded-3xl bg-gradient-to-r from-primary/95 to-blue-700 p-8 sm:p-12 text-center text-primary-foreground shadow-xl">
            <h2 className="text-3xl font-extrabold sm:text-4xl tracking-tight">
              Автоматизируйте свой мебельный цех уже сегодня
            </h2>
            <p className="mt-4 text-base sm:text-lg text-primary-foreground/80 max-w-xl mx-auto">
              Зарегистрируйтесь за 2 минуты, добавьте склады и начните оптимизировать производство с KORKEM Flow.
            </p>
            <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
              <Button size="lg" variant="secondary" className="w-full sm:w-auto text-base font-semibold px-8 h-12 text-foreground" asChild>
                <Link href="/register">Создать компанию</Link>
              </Button>
              <Button size="lg" variant="outline" className="w-full sm:w-auto text-base px-8 h-12 border-primary-foreground/30 text-white hover:bg-white/10" asChild>
                <Link href="/download">Загрузить на устройства</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
