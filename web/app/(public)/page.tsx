import Link from "next/link";
import {
  ArrowRight,
  Bot,
  Boxes,
  CheckCircle2,
  Cpu,
  Download,
  FileSpreadsheet,
  Globe,
  Laptop,
  Layers,
  Lock,
  Scissors,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Tablet,
  Users,
  Wallet,
  XCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { LandingHeroCockpit } from "@/components/landing-hero-cockpit";

const LIFECYCLE_STEPS = [
  { num: "01", title: "Заявка и замер", desc: "Фото, адреса и размеры с телефона" },
  { num: "02", title: "КП и Заказ МДФ", desc: "Авто-прайс фрезеровка × отделка" },
  { num: "03", title: "БАЗИС и Пресс", desc: "XML-спецификация и раскладка MaxRects" },
  { num: "04", title: "Склад и Обрезки", desc: "Резерв плёнки, ЛДСП и деловой остаток" },
  { num: "05", title: "Цех и PIN", desc: "Сдельная оплата по факту этапа" },
  { num: "06", title: "Выдача и 1С", desc: "Касса, долги, монтаж и гарантия" },
];

const FAQ_ITEMS = [
  {
    q: "Нужно ли переучивать технологов, если мы работаем в БАЗИС-Мебельщик?",
    a: "Нет. Технологи продолжают проектировать в БАЗИС 10.1 / 10.4 как привыкли. KORKEM рекурсивно читает выгрузку XML (блоки, ящики, детали, кромку) и сам переносит состав в заказ и склад.",
  },
  {
    q: "Что будет, если в цеху пропадёт интернет или отключат ИИ?",
    a: "Система спроектирована по принципу Local-First и правилу R7: все заказы, склад, раскладка на пресс и PIN-терминал цеха работают без LLM и без облачной зависимости. ИИ ускоряет работу, но не является точкой отказа.",
  },
  {
    q: "Где хранятся наши базы клиентов, цены и чертежи?",
    a: "Данные каждой компании строго изолированы (R6). Вы можете развернуть узел на своём мини-ПК/сервере в цеху или использовать выделенный изолированный контур на api.korkem.asia.",
  },
  {
    q: "Сколько времени занимает запуск в реальном цеху?",
    a: "Базовый запуск — за один день: заводите компанию, загружаете прайс МДФ/плёнки, раздаёте сотрудникам ссылки-приглашения и запускаете Windows-клиент или Android APK.",
  },
];

export default function HomePage() {
  return (
    <div className="flex flex-col bg-[#060911] text-slate-100">
      {/* 1. HERO SECTION */}
      <section className="relative overflow-hidden border-b border-white/10 bg-grid-slate pt-16 pb-20 md:pt-24 md:pb-28">
        {/* Radial spotlights */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-40 left-1/2 h-[520px] w-[900px] -translate-x-1/2 rounded-full bg-sky-500/15 blur-[140px]"
        />
        <div
          aria-hidden="true"
          className="pointer-events-none absolute top-40 right-1/4 h-[300px] w-[420px] rounded-full bg-amber-500/10 blur-[130px]"
        />

        <div className="container relative z-10 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 text-center">
          <div className="inline-flex items-center gap-2 rounded-full border border-sky-400/25 bg-sky-500/10 px-4 py-1.5 text-xs font-medium text-sky-300 backdrop-blur-md">
            <Sparkles className="h-3.5 w-3.5 text-amber-300" />
            <span>KORKEM Flow OS · v0.7.8 · Local-First &amp; AI-Native</span>
          </div>

          <h1 className="mx-auto mt-7 max-w-4xl text-4xl font-extrabold tracking-tight text-white sm:text-5xl md:text-6xl lg:text-[64px] lg:leading-[1.08]">
            Операционная система мебельного цеха{" "}
            <span className="bg-gradient-to-r from-sky-400 via-cyan-300 to-amber-300 bg-clip-text text-transparent">
              от звонка до монтажа
            </span>
          </h1>

          <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-slate-300 sm:text-lg">
            Заказы МДФ, умная раскладка на вакуумный пресс, отдел плёнки ПВХ,
            импорт из БАЗИС-Мебельщик, склад с обрезками и AI-администратор —
            в одном быстром окне, без хаоса таблиц и блокнотов.
          </p>

          {/* Primary CTAs */}
          <div className="mt-9 flex flex-col items-center justify-center gap-3.5 sm:flex-row">
            <Button
              size="lg"
              className="h-12 w-full sm:w-auto gap-2 rounded-xl bg-sky-500 px-8 text-base font-semibold text-slate-950 shadow-[0_0_32px_-6px_rgba(14,165,233,0.75)] hover:bg-sky-400"
              asChild
            >
              <Link href="/register">
                <span>Создать пространство цеха</span>
                <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="h-12 w-full sm:w-auto gap-2 rounded-xl border-white/15 bg-white/[0.03] px-8 text-base text-white hover:bg-white/10"
              asChild
            >
              <Link href="/download">
                <Download className="h-4 w-4 text-sky-400" />
                <span>Скачать Windows / Android</span>
              </Link>
            </Button>
          </div>

          {/* Trust Pills */}
          <div className="mt-8 flex flex-wrap items-center justify-center gap-x-6 gap-y-2.5 text-xs text-slate-400">
            <span className="inline-flex items-center gap-1.5">
              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
              Windows Desktop &amp; Android APK
            </span>
            <span className="inline-flex items-center gap-1.5">
              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
              Раскладка пресса MaxRects + текстура
            </span>
            <span className="inline-flex items-center gap-1.5">
              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
              Импорт из БАЗИС 10.1 / 10.4
            </span>
            <span className="inline-flex items-center gap-1.5">
              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
              Изолированная база компании
            </span>
          </div>

          {/* Interactive Product Cockpit */}
          <LandingHeroCockpit />
        </div>
      </section>

      {/* 2. METRICS STRIP */}
      <section className="border-b border-white/10 bg-[#080D1A]">
        <div className="container mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
          <div className="grid grid-cols-2 gap-6 md:grid-cols-4">
            {[
              { value: "12 этапов", label: "Единый цикл от лида до гарантии" },
              { value: "30 сек", label: "На раскладку фасадов на стол пресса" },
              { value: "0 потерь", label: "Контроль обрезков, рулонов и долгов" },
              { value: "100%", label: "Работает без LLM и без потери данных" },
            ].map((item) => (
              <div
                key={item.label}
                className="rounded-xl border border-white/10 bg-white/[0.02] px-5 py-4"
              >
                <div className="font-mono text-2xl font-bold text-white sm:text-3xl">
                  {item.value}
                </div>
                <div className="mt-1 text-xs text-slate-400 leading-snug">
                  {item.label}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 3. BEFORE vs AFTER */}
      <section className="py-20 md:py-24 border-b border-white/10">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center mb-14">
            <p className="font-mono text-xs font-semibold uppercase tracking-[0.2em] text-sky-400">
              Зачем цехи уходят от таблиц и блокнотов
            </p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
              Владелец больше не работает «администратором за станком»
            </h2>
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            {/* Before */}
            <div className="rounded-2xl border border-rose-500/20 bg-rose-500/[0.03] p-7">
              <div className="inline-flex items-center gap-2 rounded-full bg-rose-500/10 px-3 py-1 text-xs font-semibold text-rose-300">
                <XCircle className="h-3.5 w-3.5" />
                Обычный день без системы
              </div>
              <ul className="mt-5 space-y-3.5 text-sm text-slate-300">
                {[
                  "Клиент звонит, пока вы у ЧПУ — размер пишется в блокнот и теряется до вечера.",
                  "Заказы МДФ в одной программе, остатки плёнки в тетради, оплаты в WhatsApp.",
                  "Плёнка закончилась внезапно — пресс и цех стоят в ожидании поставки.",
                  "В конце месяца споры с мастерами по сдельной оплате и неясные долги клиентов.",
                ].map((text) => (
                  <li key={text} className="flex items-start gap-3">
                    <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-rose-400" />
                    <span>{text}</span>
                  </li>
                ))}
              </ul>
            </div>

            {/* After */}
            <div className="rounded-2xl border border-emerald-500/25 bg-emerald-500/[0.04] p-7">
              <div className="inline-flex items-center gap-2 rounded-full bg-emerald-500/15 px-3 py-1 text-xs font-semibold text-emerald-300">
                <CheckCircle2 className="h-3.5 w-3.5" />
                С KORKEM Flow
              </div>
              <ul className="mt-5 space-y-3.5 text-sm text-slate-200">
                {[
                  "Сказали голосом AI-администратору — заявка, замерщик и напоминание созданы за 5 секунд.",
                  "Весь цикл МДФ, раскрой пресса и отдел плёнки ПВХ живут в одном окне и одной базе.",
                  "Система заранее предупреждает «мало листов» и показывает плёнку «в пути» с датой.",
                  "Каждый этап отмечается в цеху по PIN-коду — сдельная зарплата и касса сходятся до тенге.",
                ].map((text) => (
                  <li key={text} className="flex items-start gap-3">
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-400" />
                    <span>{text}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* 4. PRODUCTION PIPELINE */}
      <section className="py-20 md:py-24 border-b border-white/10 bg-[#080D1A]">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center mb-14">
            <p className="font-mono text-xs font-semibold uppercase tracking-[0.2em] text-amber-300">
              Сквозная архитектура
            </p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
              Ни один заказ не пропадает между отделами
            </h2>
            <p className="mt-3 text-sm text-slate-400">
              Центральная сущность — Производственный заказ. Всё, от замера до
              гарантии, привязано к нему и доступно в один клик.
            </p>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-6">
            {LIFECYCLE_STEPS.map((step) => (
              <div
                key={step.num}
                className="group relative rounded-xl border border-white/10 bg-white/[0.02] p-5 transition hover:border-sky-400/40 hover:bg-white/[0.04]"
              >
                <div className="font-mono text-xs font-bold text-sky-400">
                  {step.num}
                </div>
                <h3 className="mt-2 text-sm font-bold text-white">
                  {step.title}
                </h3>
                <p className="mt-1.5 text-xs text-slate-400 leading-relaxed">
                  {step.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 5. BENTO GRID: CORE MODULES */}
      <section className="py-20 md:py-28 border-b border-white/10">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center mb-16">
            <p className="font-mono text-xs font-semibold uppercase tracking-[0.2em] text-sky-400">
              Боевые модули производства
            </p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
              Сделано вместе с реальными мебельными цехами
            </h2>
          </div>

          <div className="grid grid-cols-1 gap-6 md:grid-cols-12">
            {/* Big Card 1: MDF + Press */}
            <div className="md:col-span-7 rounded-2xl border border-white/10 bg-gradient-to-br from-white/[0.04] to-transparent p-7 hover:border-sky-400/35 transition">
              <div className="flex items-center justify-between">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-sky-500/15 text-sky-400 ring-1 ring-sky-400/30">
                  <Cpu className="h-5 w-5" />
                </div>
                <Badge className="bg-sky-500/15 text-sky-300 border-sky-400/30 font-mono text-[11px]">
                  MaxRects + Ручной редактор
                </Badge>
              </div>
              <h3 className="mt-5 text-xl font-bold text-white">
                Заказы МДФ и умная раскладка на вакуумный пресс
              </h3>
              <p className="mt-2.5 text-sm leading-relaxed text-slate-300">
                Матрица цен «фрезеровка × отделка», автоматический расчёт м² и
                погонных метров плёнки по секциям стола пресса (1.1 / 2.1 / 3.1 м).
                Учитывает зазоры и запрещает поворот на 90° для текстурных
                плёнок — с возможностью ручной правки «Раскрой проверен».
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                {["Бланк клиенту и цеху", "Светофор сроков", "Двусторонние фасады"].map(
                  (tag) => (
                    <span
                      key={tag}
                      className="rounded-lg border border-white/10 bg-white/[0.03] px-2.5 py-1 text-xs text-slate-300"
                    >
                      {tag}
                    </span>
                  )
                )}
              </div>
            </div>

            {/* Big Card 2: Film Dept */}
            <div className="md:col-span-5 rounded-2xl border border-white/10 bg-gradient-to-br from-white/[0.04] to-transparent p-7 hover:border-amber-400/35 transition">
              <div className="flex items-center justify-between">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-amber-500/15 text-amber-300 ring-1 ring-amber-400/30">
                  <Layers className="h-5 w-5" />
                </div>
                <Badge className="bg-amber-500/15 text-amber-300 border-amber-400/30 font-mono text-[11px]">
                  Склад · Продажа · Касса
                </Badge>
              </div>
              <h3 className="mt-5 text-xl font-bold text-white">
                Отдел плёнки ПВХ
              </h3>
              <p className="mt-2.5 text-sm leading-relaxed text-slate-300">
                Каталог по производителям и коллекциям, учёт нескольких толщин у
                одной плёнки, статусы «Свободно / Отложено / В пути», чеки со
                смешанной оплатой, закрытие кассы и рейтинг клиентов с лимитом
                долга.
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                {["Доска поставщиков", "Командный бонус", "Акт сверки"].map((tag) => (
                  <span
                    key={tag}
                    className="rounded-lg border border-white/10 bg-white/[0.03] px-2.5 py-1 text-xs text-slate-300"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </div>

            {/* Card 3: BAZIS + Offcuts */}
            <div className="md:col-span-4 rounded-2xl border border-white/10 bg-white/[0.02] p-7 hover:border-white/20 transition">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-purple-500/15 text-purple-300 ring-1 ring-purple-400/30">
                <Scissors className="h-5 w-5" />
              </div>
              <h3 className="mt-4 text-lg font-bold text-white">
                БАЗИС-Мебельщик и обрезки
              </h3>
              <p className="mt-2 text-sm text-slate-400 leading-relaxed">
                Рекурсивный импорт XML из БАЗИС 10.1 / 10.4, учёт делового
                обрезка на складе, инвентаризация месяца и авто-алерты «мало
                листов».
              </p>
            </div>

            {/* Card 4: Piecework & 1C */}
            <div className="md:col-span-4 rounded-2xl border border-white/10 bg-white/[0.02] p-7 hover:border-white/20 transition">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-500/15 text-emerald-300 ring-1 ring-emerald-400/30">
                <Wallet className="h-5 w-5" />
              </div>
              <h3 className="mt-4 text-lg font-bold text-white">
                Сдельная оплата и экспорт в 1С
              </h3>
              <p className="mt-2 text-sm text-slate-400 leading-relaxed">
                Мастера отмечают выполнение на планшете цеха, начисления
                считаются по тарифам, а бухгалтерия выгружает проводки в 1С.
              </p>
            </div>

            {/* Card 5: AI Agent */}
            <div className="md:col-span-4 rounded-2xl border border-white/10 bg-white/[0.02] p-7 hover:border-white/20 transition">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-cyan-500/15 text-cyan-300 ring-1 ring-cyan-400/30">
                <Bot className="h-5 w-5" />
              </div>
              <h3 className="mt-4 text-lg font-bold text-white">
                Цифровой администратор (AI)
              </h3>
              <p className="mt-2 text-sm text-slate-400 leading-relaxed">
                Отвечает по реальным данным заказов и склада в приложении,
                Telegram и WhatsApp. Любая запись подтверждается человеком (R10).
              </p>
            </div>
          </div>

          <div className="mt-10 text-center">
            <Button
              variant="outline"
              size="lg"
              className="border-white/15 bg-white/[0.02] text-white hover:bg-white/10"
              asChild
            >
              <Link href="/features" className="gap-2">
                <span>Смотреть все модули подробно</span>
                <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
          </div>
        </div>
      </section>

      {/* 6. ECOSYSTEM PLATFORMS */}
      <section className="py-20 md:py-24 border-b border-white/10 bg-[#080D1A]">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center mb-14">
            <p className="font-mono text-xs font-semibold uppercase tracking-[0.2em] text-sky-400">
              Единое ядро — 4 интерфейса
            </p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-white sm:text-4xl">
              Удобный инструмент на каждом участке
            </h2>
          </div>

          <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {[
              {
                icon: Laptop,
                color: "text-sky-400 bg-sky-500/10 border-sky-400/20",
                title: "Windows Desktop",
                sub: "Менеджеры и технологи",
                desc: "Быстрое оформление заказов МДФ, раскладка на пресс, печать бланков и касса.",
              },
              {
                icon: Smartphone,
                color: "text-emerald-400 bg-emerald-500/10 border-emerald-400/20",
                title: "Android / iOS",
                sub: "Владелец и замерщики",
                desc: "Контроль просрочек, фото с замера, AI-чат и уведомления в кармане.",
              },
              {
                icon: Tablet,
                color: "text-amber-400 bg-amber-500/10 border-amber-400/20",
                title: "Терминал цеха",
                sub: "Мастера по PIN-коду",
                desc: "Очередь заданий, отметка этапов, сдельная выработка и регистрация брака.",
              },
              {
                icon: Globe,
                color: "text-purple-400 bg-purple-500/10 border-purple-400/20",
                title: "Веб-портал",
                sub: "Доступ из браузера",
                desc: "Управление компанией, складами, командой и приглашениями сотрудников.",
              },
            ].map((p) => {
              const Icon = p.icon;
              return (
                <div
                  key={p.title}
                  className="rounded-2xl border border-white/10 bg-white/[0.02] p-6 hover:border-white/20 transition"
                >
                  <div
                    className={`inline-flex h-11 w-11 items-center justify-center rounded-xl border ${p.color}`}
                  >
                    <Icon className="h-5 w-5" />
                  </div>
                  <h3 className="mt-4 text-lg font-bold text-white">
                    {p.title}
                  </h3>
                  <div className="font-mono text-[11px] text-slate-400">
                    {p.sub}
                  </div>
                  <p className="mt-2.5 text-sm text-slate-300 leading-relaxed">
                    {p.desc}
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* 7. SECURITY & ARCHITECTURAL GUARANTEES */}
      <section className="py-16 md:py-20 border-b border-white/10">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 items-center gap-8 rounded-3xl border border-white/10 bg-gradient-to-r from-white/[0.03] to-sky-500/[0.04] p-8 md:grid-cols-12 md:p-10">
            <div className="md:col-span-7">
              <div className="inline-flex items-center gap-2 rounded-full bg-emerald-500/15 px-3 py-1 text-xs font-semibold text-emerald-300">
                <ShieldCheck className="h-4 w-4" />
                Инженерные гарантии KORKEM
              </div>
              <h2 className="mt-4 text-2xl font-bold text-white sm:text-3xl">
                Ваши цены, клиенты и чертежи принадлежат только вам
              </h2>
              <p className="mt-3 text-sm leading-relaxed text-slate-300">
                Данные каждой фабрики изолированы на уровне базы. Система
                продолжает работать при сбоях интернета и без подключённой LLM,
                а все действия сотрудников и AI фиксируются в неизменяемом
                журнале аудита.
              </p>
            </div>
            <div className="md:col-span-5 grid grid-cols-1 gap-3">
              {[
                {
                  icon: Lock,
                  title: "Изоляция компании (R4 / R6)",
                  desc: "Никакого смешивания остатков и клиентов между цехами.",
                },
                {
                  icon: Boxes,
                  title: "Работа без LLM (R7)",
                  desc: "Вся операционка работает детерминированно даже без ИИ.",
                },
                {
                  icon: Users,
                  title: "Подтверждение человеком (R10)",
                  desc: "AI предлагает, но решение о записи всегда за вами.",
                },
              ].map((g) => {
                const Icon = g.icon;
                return (
                  <div
                    key={g.title}
                    className="flex items-start gap-3 rounded-xl border border-white/10 bg-[#060911]/70 p-3.5"
                  >
                    <Icon className="mt-0.5 h-4 w-4 shrink-0 text-sky-400" />
                    <div>
                      <div className="text-xs font-semibold text-white">
                        {g.title}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {g.desc}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </section>

      {/* 8. FAQ */}
      <section className="py-20 border-b border-white/10 bg-[#080D1A]">
        <div className="container mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <p className="font-mono text-xs font-semibold uppercase tracking-[0.2em] text-sky-400">
              Частые вопросы
            </p>
            <h2 className="mt-2 text-3xl font-bold text-white">
              Перед запуском в цеху
            </h2>
          </div>

          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            {FAQ_ITEMS.map((item) => (
              <div
                key={item.q}
                className="rounded-2xl border border-white/10 bg-white/[0.02] p-6"
              >
                <h3 className="text-base font-bold text-white">{item.q}</h3>
                <p className="mt-2.5 text-sm leading-relaxed text-slate-400">
                  {item.a}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 9. FINAL CTA */}
      <section className="py-20">
        <div className="container mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
          <div className="relative overflow-hidden rounded-3xl border border-sky-400/30 bg-gradient-to-br from-sky-500/20 via-[#0B1426] to-amber-500/15 p-8 text-center shadow-2xl sm:p-14">
            <h2 className="text-3xl font-extrabold tracking-tight text-white sm:text-4xl">
              Наведите порядок в цеху и фасадах уже сегодня
            </h2>
            <p className="mx-auto mt-4 max-w-xl text-base text-slate-300">
              Зарегистрируйте компанию за 2 минуты, пригласите команду по ссылке
              и скачайте KORKEM Flow Desktop v0.7.8.
            </p>
            <div className="mt-8 flex flex-col items-center justify-center gap-4 sm:flex-row">
              <Button
                size="lg"
                className="h-12 w-full sm:w-auto gap-2 rounded-xl bg-sky-500 px-8 text-base font-semibold text-slate-950 hover:bg-sky-400"
                asChild
              >
                <Link href="/register">
                  <span>Создать компанию</span>
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <Button
                size="lg"
                variant="outline"
                className="h-12 w-full sm:w-auto gap-2 rounded-xl border-white/20 bg-white/5 px-8 text-base text-white hover:bg-white/10"
                asChild
              >
                <Link href="/download">
                  <FileSpreadsheet className="h-4 w-4 text-amber-300" />
                  <span>Страница загрузок</span>
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
