import Link from "next/link";
import {
  ArrowRight,
  ArrowUpRight,
  Check,
  Download,
  Laptop,
  Lock,
  Smartphone,
  Tablet,
  Globe,
} from "lucide-react";
import { InteractivePressDemo } from "@/components/interactive-press-demo";
import { SpotlightCard } from "@/components/spotlight-card";

const PIPELINE = [
  { n: "01", name: "Замер и фото", note: "С телефона замерщика сразу в заявку" },
  { n: "02", name: "КП и Заказ МДФ", note: "Прайс фрезеровка × отделка без ручного счёта" },
  { n: "03", name: "БАЗИС и Пресс", note: "XML-выгрузка 10.1/10.4 + раскладка MaxRects" },
  { n: "04", name: "Склад и Плёнка", note: "Свободно, отложено, в пути и деловые обрезки" },
  { n: "05", name: "PIN-терминал", note: "Мастера отмечают этапы, сдельная считается сама" },
  { n: "06", name: "Касса и 1С", note: "Оплаты, лимит долга, акт сверки, гарантия" },
];

const FAQ = [
  {
    q: "Нужно ли переучивать технологов с БАЗИС-Мебельщик?",
    a: "Нет. Технологи работают в БАЗИС 10.1 / 10.4 как обычно. KORKEM рекурсивно читает XML-выгрузку и переносит детали, кромку и материалы в заказ.",
  },
  {
    q: "Что будет, если в цеху пропадёт интернет или отключат ИИ?",
    a: "Ядро работает без LLM (правило R7) и переживает перебои связи. Заказы, раскладка пресса, склад и PIN-терминал цеха не зависят от облачного ИИ.",
  },
  {
    q: "Где хранятся наши базы, клиенты и закупочные цены?",
    a: "Данные каждой фабрики строго изолированы (R6). Возможен выделенный контур на api.korkem.asia или локальный узел на вашем сервере в цеху.",
  },
  {
    q: "Сколько времени занимает запуск в реальном производстве?",
    a: "Базовый запуск — один день: регистрируете компанию, загружаете прайс МДФ и плёнки, раздаёте ссылки-приглашения команде и ставите Windows-клиент.",
  },
];

export default function HomePage() {
  return (
    <div className="flex flex-col">
      {/* 1. HERO — Obsidian Dark (#09090B) */}
      <section className="relative overflow-hidden bg-[#09090B] bg-arch-grid pt-16 pb-24 md:pt-24 md:pb-32 text-[#F5F5F0]">
        {/* Warm subtle architectural spotlight */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-48 left-1/2 h-[540px] w-[820px] -translate-x-1/2 rounded-full bg-amber-500/[0.08] blur-[160px]"
        />

        <div className="container relative z-10 mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 text-center">
          <Link
            href="/download"
            className="inline-flex items-center gap-2.5 rounded-full border border-white/[0.12] bg-white/[0.03] px-3.5 py-1 text-xs text-zinc-300 transition hover:border-white/25 hover:text-white"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
            <span className="font-mono text-[11px] text-zinc-400">v0.7.8</span>
            <span>Вышел модуль «Отдел плёнки» и редактор пресса</span>
            <ArrowUpRight className="h-3.5 w-3.5 text-zinc-500" />
          </Link>

          <h1 className="mx-auto mt-8 max-w-4xl text-4xl font-semibold tracking-[-0.035em] text-[#F5F5F0] sm:text-6xl lg:text-[68px] lg:leading-[1.04]">
            Цифровая архитектура{" "}
            <span className="font-serif italic font-medium text-amber-200/95">
              мебельного
            </span>{" "}
            производства
          </h1>

          <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-zinc-400 sm:text-lg">
            Единая операционная система для фабрик и цехов: заказы МДФ,
            раскладка на вакуумный пресс, отдел плёнки ПВХ, импорт из БАЗИС и
            AI-администратор — в одном точном интерфейсе.
          </p>

          <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <Link
              href="/register"
              className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full bg-[#F5F5F0] px-7 text-sm font-semibold text-[#09090B] transition hover:bg-white"
            >
              <span>Создать пространство цеха</span>
              <ArrowRight className="h-4 w-4" />
            </Link>
            <Link
              href="/download"
              className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full border border-white/15 bg-transparent px-7 text-sm font-medium text-zinc-200 transition hover:border-white/30 hover:bg-white/[0.04]"
            >
              <Download className="h-4 w-4 text-zinc-400" />
              <span>Скачать Windows / Android</span>
            </Link>
          </div>

          {/* Interactive Product Simulator */}
          <InteractivePressDemo />
        </div>
      </section>

      {/* 2. EDITORIAL MANIFESTO — Warm Limestone (#F7F6F2) */}
      <section className="bg-[#F7F6F2] text-[#09090B] border-y border-neutral-200 py-20 md:py-28">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 gap-12 lg:grid-cols-12 lg:items-start">
            <div className="lg:col-span-5">
              <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-neutral-500">
                Философия KORKEM
              </div>
              <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-[#09090B] sm:text-4xl leading-[1.12]">
                Владелец больше не работает{" "}
                <span className="font-serif italic font-medium">
                  администратором
                </span>{" "}
                за станком
              </h2>
            </div>

            <div className="lg:col-span-7 grid grid-cols-1 gap-8 sm:grid-cols-3 border-t border-neutral-300 pt-8 lg:border-t-0 lg:pt-0">
              <div>
                <div className="font-mono text-2xl font-semibold text-[#09090B]">
                  0 мин
                </div>
                <div className="mt-2 text-sm font-semibold text-[#09090B]">
                  Потерь между отделами
                </div>
                <p className="mt-1.5 text-xs leading-relaxed text-neutral-600">
                  Замер, КП, фасадный заказ, плёнка, цех и касса связаны с
                  одним производственным заказом.
                </p>
              </div>
              <div>
                <div className="font-mono text-2xl font-semibold text-[#09090B]">
                  MaxRects
                </div>
                <div className="mt-2 text-sm font-semibold text-[#09090B]">
                  Точный метраж плёнки
                </div>
                <p className="mt-1.5 text-xs leading-relaxed text-neutral-600">
                  Учитывает секции 1.1 / 2.1 / 3.1 м, зазоры и запрет поворота
                  для текстурных декоров.
                </p>
              </div>
              <div>
                <div className="font-mono text-2xl font-semibold text-[#09090B]">
                  R6 · R7
                </div>
                <div className="mt-2 text-sm font-semibold text-[#09090B]">
                  Автономность и приватность
                </div>
                <p className="mt-1.5 text-xs leading-relaxed text-neutral-600">
                  База компании изолирована, а весь цех работает даже без
                  интернета и без ИИ.
                </p>
              </div>
            </div>
          </div>

          {/* 6-Stage Architectural Lifecycle */}
          <div className="mt-16 grid grid-cols-1 divide-y divide-neutral-200 border border-neutral-200 rounded-2xl bg-white sm:grid-cols-2 sm:divide-y-0 lg:grid-cols-6 lg:divide-x">
            {PIPELINE.map((step) => (
              <div key={step.n} className="p-5">
                <div className="font-mono text-[11px] font-medium text-neutral-400">
                  {step.n}
                </div>
                <div className="mt-2 text-sm font-semibold text-[#09090B]">
                  {step.name}
                </div>
                <p className="mt-1.5 text-xs leading-relaxed text-neutral-600">
                  {step.note}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 3. BENTO CAPABILITIES — Obsidian Dark (#09090B) */}
      <section className="bg-[#09090B] text-[#F5F5F0] py-20 md:py-28 border-b border-white/[0.08]">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end mb-14">
            <div>
              <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-zinc-500">
                Модули производства
              </div>
              <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] sm:text-4xl">
                Построено на реальных заказах{" "}
                <span className="font-serif italic font-medium text-amber-200">
                  и бланках цеха
                </span>
              </h2>
            </div>
            <Link
              href="/features"
              className="inline-flex items-center gap-1.5 text-sm font-medium text-zinc-300 transition hover:text-white"
            >
              <span>Все возможности</span>
              <ArrowRight className="h-4 w-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-12">
            {/* Large 1 */}
            <SpotlightCard className="md:col-span-7 p-7 sm:p-8">
              <div className="font-mono text-[11px] uppercase tracking-wider text-amber-400">
                01 · Фасады МДФ и Пресс
              </div>
              <h3 className="mt-3 text-xl font-semibold text-[#F5F5F0]">
                Единое окно заказа МДФ и раскладка на вакуумный пресс
              </h3>
              <p className="mt-2.5 text-sm leading-relaxed text-zinc-400">
                Прайс-матрица фрезеровка × отделка подставляет цены сама. После
                принятия цены фиксируются в заказе. Оператор пресса видит
                оптимальную карту укладки на стол и может поправить её вручную.
              </p>
              <div className="mt-6 flex flex-wrap gap-2 font-mono text-[11px] text-zinc-300">
                <span className="rounded-full border border-white/10 px-3 py-1">
                  Печать клиенту и цеху
                </span>
                <span className="rounded-full border border-white/10 px-3 py-1">
                  Двусторонние фасады
                </span>
                <span className="rounded-full border border-white/10 px-3 py-1">
                  Светофор сроков
                </span>
              </div>
            </SpotlightCard>

            {/* Large 2 */}
            <SpotlightCard className="md:col-span-5 p-7 sm:p-8">
              <div className="font-mono text-[11px] uppercase tracking-wider text-amber-400">
                02 · Отдел плёнки ПВХ
              </div>
              <h3 className="mt-3 text-xl font-semibold text-[#F5F5F0]">
                Рулоны, толщины, касса и клиенты
              </h3>
              <p className="mt-2.5 text-sm leading-relaxed text-zinc-400">
                Несколько толщин у одной плёнки, статусы «Свободно / Отложено /
                В пути», чеки со смешанной оплатой, закрытие дня, доска
                поставщиков и контроль лимита долга клиента.
              </p>
              <div className="mt-6 flex flex-wrap gap-2 font-mono text-[11px] text-zinc-300">
                <span className="rounded-full border border-white/10 px-3 py-1">
                  Акт сверки
                </span>
                <span className="rounded-full border border-white/10 px-3 py-1">
                  Командный бонус
                </span>
              </div>
            </SpotlightCard>

            {/* Row 2: 3 equal cards */}
            <SpotlightCard className="md:col-span-4 p-7">
              <div className="font-mono text-[11px] uppercase tracking-wider text-zinc-500">
                03 · БАЗИС и Склад
              </div>
              <h3 className="mt-3 text-lg font-semibold text-[#F5F5F0]">
                Импорт БАЗИС 10.1 / 10.4
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-zinc-400">
                Рекурсивный разбор блоков и деталей, учёт деловых обрезков,
                инвентаризация месяца и алерты «мало листов».
              </p>
            </SpotlightCard>

            <SpotlightCard className="md:col-span-4 p-7">
              <div className="font-mono text-[11px] uppercase tracking-wider text-zinc-500">
                04 · Люди и 1С
              </div>
              <h3 className="mt-3 text-lg font-semibold text-[#F5F5F0]">
                Сдельная оплата и выгрузка
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-zinc-400">
                Мастера отмечают этап на планшете по PIN-коду — зарплата
                начисляется прозрачно, а бухгалтерия выгружает данные в 1С.
              </p>
            </SpotlightCard>

            <SpotlightCard className="md:col-span-4 p-7">
              <div className="font-mono text-[11px] uppercase tracking-wider text-zinc-500">
                05 · AI-Ассистент
              </div>
              <h3 className="mt-3 text-lg font-semibold text-[#F5F5F0]">
                Помощник без самодеятельности
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-zinc-400">
                Отвечает по фактам из БД в приложении, Telegram и WhatsApp.
                Любая запись требует подтверждения человеком (R10).
              </p>
            </SpotlightCard>
          </div>
        </div>
      </section>

      {/* 4. FOUR SURFACES — Warm Limestone (#F7F6F2) */}
      <section className="bg-[#F7F6F2] text-[#09090B] py-20 md:py-24 border-b border-neutral-200">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-2xl text-center mb-14">
            <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-neutral-500">
              4 интерфейса · 1 ядро
            </div>
            <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] sm:text-4xl">
              Один поток данных от офиса до станка
            </h2>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[
              {
                icon: Laptop,
                title: "Windows Desktop",
                role: "Офис и технолог",
                desc: "Заказы МДФ, редактор пресса, печать бланков, отдел плёнки и касса.",
              },
              {
                icon: Smartphone,
                title: "Android / iOS",
                role: "Директор и замерщик",
                desc: "Замеры с фото, просрочки, аналитика и AI-чат с подтверждением.",
              },
              {
                icon: Tablet,
                title: "Терминал цеха",
                role: "Мастера по PIN-коду",
                desc: "Очередь сменных заданий, отметка операций и фиксация брака.",
              },
              {
                icon: Globe,
                title: "Веб-портал",
                role: "Администрирование",
                desc: "Регистрация фабрики, приглашения сотрудников и управление складами.",
              },
            ].map((item) => {
              const Icon = item.icon;
              return (
                <div
                  key={item.title}
                  className="rounded-2xl border border-neutral-200 bg-white p-6 transition hover:border-neutral-400"
                >
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-neutral-200 bg-[#F7F6F2] text-[#09090B]">
                    <Icon className="h-4 w-4" />
                  </div>
                  <div className="mt-5 font-mono text-[11px] text-neutral-500">
                    {item.role}
                  </div>
                  <h3 className="mt-1 text-base font-semibold text-[#09090B]">
                    {item.title}
                  </h3>
                  <p className="mt-2 text-xs leading-relaxed text-neutral-600">
                    {item.desc}
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* 5. FAQ + FINAL CTA — Obsidian Dark (#09090B) */}
      <section className="bg-[#09090B] text-[#F5F5F0] py-20 md:py-28">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 gap-12 lg:grid-cols-12">
            <div className="lg:col-span-4">
              <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-zinc-500">
                Вопросы и ответы
              </div>
              <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em]">
                Всё, что важно перед{" "}
                <span className="font-serif italic font-medium text-amber-200">
                  запуском
                </span>
              </h2>
              <div className="mt-6 space-y-2.5 text-xs text-zinc-400">
                <div className="flex items-center gap-2">
                  <Lock className="h-3.5 w-3.5 text-emerald-400" />
                  <span>Изоляция данных на уровне компании</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check className="h-3.5 w-3.5 text-emerald-400" />
                  <span>Аудит каждого изменения</span>
                </div>
              </div>
            </div>

            <div className="lg:col-span-8 divide-y divide-white/[0.08] border-y border-white/[0.08]">
              {FAQ.map((item) => (
                <div key={item.q} className="py-6">
                  <h3 className="text-base font-medium text-[#F5F5F0]">
                    {item.q}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-zinc-400">
                    {item.a}
                  </p>
                </div>
              ))}
            </div>
          </div>

          {/* Minimal High-Contrast Closing CTA */}
          <div className="mt-24 rounded-3xl border border-white/[0.12] bg-[#111114] px-6 py-14 text-center sm:px-12 sm:py-16">
            <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-amber-300">
              KORKEM Flow · 2026
            </div>
            <h2 className="mx-auto mt-4 max-w-2xl text-3xl font-semibold tracking-[-0.03em] text-[#F5F5F0] sm:text-5xl">
              Наведите порядок в цеху за{" "}
              <span className="font-serif italic font-medium">один день</span>
            </h2>
            <p className="mx-auto mt-4 max-w-lg text-sm text-zinc-400">
              Создайте пространство компании, пригласите сотрудников по ссылке и
              скачайте актуальную версию для Windows или Android.
            </p>
            <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <Link
                href="/register"
                className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full bg-[#F5F5F0] px-8 text-sm font-semibold text-[#09090B] transition hover:bg-white"
              >
                <span>Создать компанию</span>
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link
                href="/download"
                className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full border border-white/15 px-8 text-sm font-medium text-zinc-200 transition hover:border-white/30 hover:bg-white/[0.04]"
              >
                <span>Страница загрузок</span>
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
