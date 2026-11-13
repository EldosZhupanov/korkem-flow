import Link from "next/link";
import {
  ArrowRight,
  ArrowUpRight,
  Bot,
  Boxes,
  Download,
  Globe,
  Laptop,
  Layers,
  Lock,
  Plus,
  ScrollText,
  Smartphone,
  Tablet,
  Users,
} from "lucide-react";
import { InteractivePressDemo } from "@/components/interactive-press-demo";
import { Brand3DModel } from "@/components/brand-3d-model";
import { Reveal3D, Tilt3DStage } from "@/components/motion-3d";
import { SpotlightCard } from "@/components/spotlight-card";

/* ------------------------------------------------------------------ */
/*  Content                                                            */
/* ------------------------------------------------------------------ */

const MARQUEE = [
  "БАЗИС-Мебельщик 10.1 / 10.4",
  "Вакуумный пресс",
  "Плёнка ПВХ",
  "Фрезеровка МДФ",
  "Kaspi и наличные",
  "Выгрузка в 1С",
  "PIN-терминал цеха",
  "Сдельная оплата",
  "Деловые обрезки",
  "Telegram и WhatsApp",
];

const STATS = [
  {
    value: "0 мин",
    label: "Потерь между отделами",
    note: "Замер, КП, фасадный заказ, плёнка, цех и касса связаны одним производственным заказом.",
  },
  {
    value: "MaxRects",
    label: "Точный метраж плёнки",
    note: "Секции пресса 1.1 / 2.1 / 3.1 м, зазоры и запрет поворота для текстурных декоров.",
  },
  {
    value: "R6 · R7",
    label: "Приватность и автономность",
    note: "База каждой фабрики изолирована, а цех работает даже без интернета и без ИИ.",
  },
];

const PIPELINE = [
  { n: "01", name: "Замер и фото", note: "С телефона замерщика — сразу в заявку" },
  { n: "02", name: "КП и заказ МДФ", note: "Прайс фрезеровка × отделка без ручного счёта" },
  { n: "03", name: "БАЗИС и пресс", note: "XML 10.1 / 10.4 и раскладка MaxRects" },
  { n: "04", name: "Склад и плёнка", note: "Свободно, отложено, в пути, обрезки" },
  { n: "05", name: "PIN-терминал", note: "Мастера отмечают этапы — сдельная считается сама" },
  { n: "06", name: "Касса и 1С", note: "Оплаты, лимит долга, акт сверки, гарантия" },
];

const FEATURES = [
  {
    span: "md:col-span-7",
    icon: Layers,
    tag: "Фасады МДФ и пресс",
    title: "Единое окно заказа МДФ и раскладка на вакуумный пресс",
    body: "Прайс-матрица фрезеровка × отделка подставляет цены сама и фиксирует их после принятия. Оператор пресса видит оптимальную карту укладки и может поправить её вручную.",
    chips: ["Печать клиенту и цеху", "Двусторонние фасады", "Светофор сроков"],
  },
  {
    span: "md:col-span-5",
    icon: ScrollText,
    tag: "Отдел плёнки ПВХ",
    title: "Рулоны, толщины, касса и клиенты",
    body: "Несколько толщин у одной плёнки, статусы «Свободно / Отложено / В пути», чеки со смешанной оплатой, закрытие дня и контроль лимита долга.",
    chips: ["Акт сверки", "Командный бонус"],
  },
  {
    span: "md:col-span-4",
    icon: Boxes,
    tag: "БАЗИС и склад",
    title: "Импорт БАЗИС 10.1 / 10.4",
    body: "Рекурсивный разбор блоков и деталей, учёт деловых обрезков, инвентаризация месяца и алерты «мало листов».",
  },
  {
    span: "md:col-span-4",
    icon: Users,
    tag: "Люди и 1С",
    title: "Сдельная оплата и выгрузка",
    body: "Мастера отмечают этап на планшете по PIN-коду — зарплата начисляется прозрачно, бухгалтерия выгружает данные в 1С.",
  },
  {
    span: "md:col-span-4",
    icon: Bot,
    tag: "AI-ассистент",
    title: "Помощник без самодеятельности",
    body: "Отвечает по фактам из базы в приложении, Telegram и WhatsApp. Любая запись требует подтверждения человеком (R10).",
  },
];

const SURFACES = [
  { icon: Laptop, title: "Windows Desktop", role: "Офис и технолог", desc: "Заказы МДФ, редактор пресса, печать бланков, отдел плёнки и касса." },
  { icon: Smartphone, title: "Android / iOS", role: "Директор и замерщик", desc: "Замеры с фото, просрочки, аналитика и AI-чат с подтверждением." },
  { icon: Tablet, title: "Терминал цеха", role: "Мастера по PIN-коду", desc: "Очередь сменных заданий, отметка операций и фиксация брака." },
  { icon: Globe, title: "Веб-портал", role: "Администрирование", desc: "Регистрация фабрики, приглашения сотрудников и управление складами." },
];

const FAQ = [
  {
    q: "Нужно ли переучивать технологов с БАЗИС-Мебельщик?",
    a: "Нет. Технологи работают в БАЗИС 10.1 / 10.4 как обычно. KӨRKEM рекурсивно читает XML-выгрузку и переносит детали, кромку и материалы в заказ.",
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

/* ------------------------------------------------------------------ */
/*  Small building blocks                                              */
/* ------------------------------------------------------------------ */

function Eyebrow({ children, light = false }: { children: React.ReactNode; light?: boolean }) {
  return (
    <div
      className={`inline-flex items-center gap-3 font-mono text-[11px] uppercase tracking-[0.24em] ${
        light ? "text-[#7A6A45]" : "text-[#C9A25B]"
      }`}
    >
      <span className={`h-px w-8 ${light ? "bg-[#B08D4F]/60" : "bg-[#C9A25B]/60"}`} />
      {children}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Page                                                               */
/* ------------------------------------------------------------------ */

export default function HomePage() {
  return (
    <div className="flex flex-col">
      {/* ============================ HERO ============================ */}
      <section className="bg-grain relative -mt-20 overflow-hidden bg-[#10160F] text-[#E6E3D9] sm:-mt-24">
        {/* lighting */}
        <div aria-hidden className="pointer-events-none absolute inset-0">
          <div className="absolute -right-40 -top-40 h-[720px] w-[720px] rounded-full bg-[#C9A25B]/[0.10] blur-[140px]" />
          <div className="absolute -left-52 top-1/3 h-[620px] w-[620px] rounded-full bg-[#2B382A]/70 blur-[130px]" />
          <div className="bg-arch-grid absolute inset-0 [mask-image:radial-gradient(ellipse_at_70%_40%,black_10%,transparent_65%)]" />
        </div>

        <div className="relative mx-auto grid min-h-[100svh] max-w-6xl grid-cols-1 items-center gap-6 px-5 pb-16 pt-32 sm:px-8 lg:grid-cols-12 lg:gap-4 lg:pb-24 lg:pt-36">
          {/* copy */}
          <div className="order-2 lg:order-1 lg:col-span-7">
            <Link
              href="/download"
              className="group inline-flex items-center gap-2.5 rounded-full border border-[#C9A25B]/25 bg-white/[0.03] py-1 pl-1 pr-3.5 text-[12px] text-[#CFCBBF] backdrop-blur transition hover:border-[#C9A25B]/50"
            >
              <span className="rounded-full bg-[#C9A25B]/15 px-2 py-0.5 font-mono text-[10.5px] font-medium text-[#E2C68C]">
                v0.7.8
              </span>
              Отдел плёнки ПВХ и редактор пресса
              <ArrowUpRight className="h-3.5 w-3.5 text-[#C9A25B] transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
            </Link>

            <h1 className="font-display mt-7 text-[44px] font-extrabold leading-[0.98] tracking-[-0.045em] text-[#F2EEE3] sm:text-[64px] lg:text-[78px]">
              Мебельный цех
              <br />
              под полным <span className="text-brass">контролем</span>
            </h1>

            <p className="mt-7 max-w-xl text-[17px] leading-[1.65] text-[#A9AEA4] sm:text-lg">
              KӨRKEM Flow — операционная система для фабрик и цехов: заказы МДФ,
              раскладка на вакуумный пресс, плёнка ПВХ, импорт из БАЗИС и
              AI-администратор. В одном окне.
            </p>

            <div className="mt-10 flex flex-col gap-3 sm:flex-row">
              <Link
                href="/register"
                className="group inline-flex h-[52px] items-center justify-center gap-2 rounded-full bg-[#ECE5D3] px-7 text-[15px] font-semibold text-[#141B13] shadow-[0_10px_40px_-10px_rgba(236,229,211,0.45)] transition hover:bg-white"
              >
                Создать компанию
                <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
              </Link>
              <Link
                href="/download"
                className="inline-flex h-[52px] items-center justify-center gap-2 rounded-full border border-white/[0.12] bg-white/[0.03] px-7 text-[15px] font-medium text-[#E6E3D9] backdrop-blur transition hover:border-[#C9A25B]/50 hover:bg-white/[0.06]"
              >
                <Download className="h-4 w-4 text-[#C9A25B]" />
                Скачать Windows / Android
              </Link>
            </div>

            <dl className="mt-14 grid max-w-lg grid-cols-3 gap-6 border-t border-white/[0.07] pt-7">
              {[
                ["1 день", "до запуска"],
                ["4", "платформы"],
                ["R7", "ядро без ИИ"],
              ].map(([v, l]) => (
                <div key={l}>
                  <dt className="font-display text-2xl font-bold tracking-tight text-[#F2EEE3] sm:text-[28px]">{v}</dt>
                  <dd className="mt-1 text-[12.5px] text-[#8E9488]">{l}</dd>
                </div>
              ))}
            </dl>
          </div>

          {/* 3D stage */}
          <div className="order-1 lg:order-2 lg:col-span-5">
            <div className="relative mx-auto aspect-square w-full max-w-[300px] sm:max-w-[420px] lg:max-w-none">
              {/* concentric hairline rings */}
              <div aria-hidden className="pointer-events-none absolute inset-0">
                <div className="absolute inset-[2%] rounded-full border border-[#C9A25B]/[0.14]" />
                <div className="animate-spin-slower absolute inset-[10%] rounded-full border border-dashed border-[#C9A25B]/[0.18]" />
                <div className="absolute inset-[18%] rounded-full border border-white/[0.05]" />
                <div className="absolute inset-[22%] rounded-full bg-[radial-gradient(circle,rgba(233,207,150,0.16),transparent_65%)] blur-2xl" />
                {/* floor shadow */}
                <div className="absolute bottom-[6%] left-1/2 h-6 w-1/2 -translate-x-1/2 rounded-[50%] bg-black/60 blur-xl" />
              </div>
              <Brand3DModel
                modelJson="/brand/korkem_mark_3d.json"
                fallbackSrc="/brand/korkem_mark.png"
                alt="KӨRKEM — официальный знак, 3D"
                variant="mark"
                className="absolute inset-0"
              />
            </div>
            <p className="mt-2 text-center font-mono text-[10px] uppercase tracking-[0.24em] text-[#6F766B]">
              Потяните знак — он вращается в 3D
            </p>
          </div>
        </div>
      </section>

      {/* =========================== MARQUEE ========================== */}
      <section aria-label="Интеграции" className="relative overflow-hidden border-y border-[#C9A25B]/15 bg-[#0D120C] py-5">
        <div className="flex w-max animate-marquee items-center gap-10 whitespace-nowrap [mask-image:linear-gradient(90deg,transparent,black_10%,black_90%,transparent)]">
          {[...MARQUEE, ...MARQUEE].map((m, i) => (
            <span key={i} className="flex items-center gap-10 text-[13px] font-medium uppercase tracking-[0.18em] text-[#9BA196]">
              {m}
              <span className="text-[#C9A25B]">✦</span>
            </span>
          ))}
        </div>
      </section>

      {/* ========================== MANIFESTO ========================= */}
      <section className="bg-[#F4F1E8] py-24 text-[#1E2A1E] md:py-32">
        <div className="mx-auto max-w-6xl px-5 sm:px-8">
          <Reveal3D>
            <Eyebrow light>Философия KӨRKEM</Eyebrow>
            <p className="font-display mt-8 max-w-5xl text-[30px] font-bold leading-[1.18] tracking-[-0.03em] sm:text-[44px] lg:text-[54px]">
              Владелец больше не работает администратором за станком.{" "}
              <span className="text-[#1E2A1E]/35">
                Система ведёт заказ от замера до выдачи — а вы управляете ростом.
              </span>
            </p>
          </Reveal3D>

          <div className="mt-16 grid grid-cols-1 gap-px overflow-hidden rounded-3xl border border-[#DCD6C6] bg-[#DCD6C6] sm:grid-cols-3">
            {STATS.map((s, i) => (
              <Reveal3D key={s.label} delayMs={i * 90}>
                <div className="h-full bg-[#F8F6EF] p-8 transition-colors hover:bg-white">
                  <div className="font-display text-[34px] font-extrabold tracking-[-0.03em] text-[#2B382A]">{s.value}</div>
                  <div className="mt-3 text-[15px] font-semibold">{s.label}</div>
                  <p className="mt-2 text-[14px] leading-relaxed text-[#5C5F5A]">{s.note}</p>
                </div>
              </Reveal3D>
            ))}
          </div>

          {/* pipeline */}
          <div className="mt-28">
            <div className="flex flex-col justify-between gap-4 md:flex-row md:items-end">
              <div>
                <Eyebrow light>Жизненный цикл заказа</Eyebrow>
                <h2 className="font-display mt-5 text-[32px] font-extrabold leading-[1.05] tracking-[-0.035em] sm:text-[44px]">
                  Шесть этапов — одна нить
                </h2>
              </div>
              <p className="max-w-sm text-[15px] leading-relaxed text-[#5C5F5A]">
                Каждый отдел видит ровно свой участок работы, а владелец — весь путь заказа целиком.
              </p>
            </div>

            <ol className="relative mt-14 grid grid-cols-1 gap-10 sm:grid-cols-2 lg:grid-cols-6 lg:gap-6">
              <span aria-hidden className="absolute left-0 right-0 top-[22px] hidden h-px bg-gradient-to-r from-[#B08D4F]/0 via-[#B08D4F]/50 to-[#B08D4F]/0 lg:block" />
              {PIPELINE.map((s, i) => (
                <Reveal3D key={s.n} delayMs={i * 70}>
                  <li className="relative">
                    <div className="relative z-10 flex h-11 w-11 items-center justify-center rounded-full border border-[#B08D4F]/50 bg-[#F4F1E8] font-mono text-[12px] font-semibold text-[#8A6C34]">
                      {s.n}
                    </div>
                    <div className="mt-5 text-[16px] font-semibold">{s.name}</div>
                    <p className="mt-1.5 text-[13.5px] leading-relaxed text-[#5C5F5A]">{s.note}</p>
                  </li>
                </Reveal3D>
              ))}
            </ol>
          </div>
        </div>
      </section>

      {/* ============================ DEMO ============================ */}
      <section className="bg-grain relative overflow-hidden bg-[#10160F] py-24 text-[#E6E3D9] md:py-32">
        <div aria-hidden className="pointer-events-none absolute left-1/2 top-0 h-[480px] w-[900px] -translate-x-1/2 rounded-full bg-[#C9A25B]/[0.07] blur-[140px]" />
        <div className="relative mx-auto max-w-6xl px-5 sm:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <Eyebrow>Живая демонстрация</Eyebrow>
            <h2 className="font-display mt-5 text-[34px] font-extrabold leading-[1.04] tracking-[-0.04em] text-[#F2EEE3] sm:text-[52px]">
              Попробуйте прямо здесь
            </h2>
            <p className="mt-5 text-[16px] leading-relaxed text-[#A9AEA4]">
              Раскладка фасадов на пресс, склад плёнки и AI-администратор — тот же интерфейс, что у вас в цеху.
            </p>
          </div>
          <Reveal3D delayMs={100}>
            <Tilt3DStage intensity={3} className="mx-auto mt-14 max-w-5xl">
              <div className="ring-brass rounded-[22px] p-1.5">
                <InteractivePressDemo />
              </div>
            </Tilt3DStage>
          </Reveal3D>
        </div>
      </section>

      {/* =========================== BENTO ============================ */}
      <section className="border-t border-white/[0.05] bg-[#141B13] py-24 text-[#E6E3D9] md:py-32">
        <div className="mx-auto max-w-6xl px-5 sm:px-8">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end">
            <div>
              <Eyebrow>Модули производства</Eyebrow>
              <h2 className="font-display mt-5 max-w-2xl text-[32px] font-extrabold leading-[1.05] tracking-[-0.035em] text-[#F2EEE3] sm:text-[46px]">
                Построено на реальных заказах и бланках цеха
              </h2>
            </div>
            <Link href="/features" className="group inline-flex items-center gap-2 text-[14px] font-medium text-[#E2C68C] hover:text-[#F3E2B8]">
              Все возможности
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </Link>
          </div>

          <div className="mt-14 grid grid-cols-1 gap-4 md:grid-cols-12">
            {FEATURES.map((f, i) => {
              const Icon = f.icon;
              return (
                <Reveal3D key={f.title} className={f.span} delayMs={i * 70}>
                  <SpotlightCard className="h-full border-white/[0.07] bg-[#1A2219] p-7 sm:p-8">
                    <div className="flex items-center gap-3">
                      <span className="flex h-10 w-10 items-center justify-center rounded-xl border border-[#C9A25B]/25 bg-[#C9A25B]/[0.08] text-[#E2C68C]">
                        <Icon className="h-[18px] w-[18px]" />
                      </span>
                      <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-[#8E9488]">{f.tag}</span>
                    </div>
                    <h3 className="font-display mt-6 text-[21px] font-bold leading-snug tracking-[-0.02em] text-[#F2EEE3]">{f.title}</h3>
                    <p className="mt-3 text-[14.5px] leading-relaxed text-[#A9AEA4]">{f.body}</p>
                    {f.chips && (
                      <div className="mt-6 flex flex-wrap gap-2">
                        {f.chips.map((c) => (
                          <span key={c} className="rounded-full border border-white/[0.08] bg-black/20 px-3 py-1 text-[12px] text-[#CFCBBF]">
                            {c}
                          </span>
                        ))}
                      </div>
                    )}
                  </SpotlightCard>
                </Reveal3D>
              );
            })}
          </div>
        </div>
      </section>

      {/* ========================= SURFACES =========================== */}
      <section className="bg-[#F4F1E8] py-24 text-[#1E2A1E] md:py-32">
        <div className="mx-auto max-w-6xl px-5 sm:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <Eyebrow light>4 интерфейса · 1 ядро</Eyebrow>
            <h2 className="font-display mt-5 text-[32px] font-extrabold leading-[1.05] tracking-[-0.035em] sm:text-[46px]">
              Один поток данных от офиса до станка
            </h2>
          </div>
          <div className="mt-14 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {SURFACES.map((s, i) => {
              const Icon = s.icon;
              return (
                <Reveal3D key={s.title} delayMs={i * 80}>
                  <div className="group h-full rounded-3xl border border-[#DCD6C6] bg-[#F8F6EF] p-7 transition duration-300 hover:-translate-y-1 hover:border-[#B08D4F]/50 hover:bg-white hover:shadow-[0_30px_60px_-30px_rgba(43,56,42,0.35)]">
                    <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[#1E2A1E] text-[#E2C68C] transition-transform group-hover:scale-105">
                      <Icon className="h-5 w-5" />
                    </span>
                    <div className="mt-7 font-mono text-[11px] uppercase tracking-[0.16em] text-[#8A6C34]">{s.role}</div>
                    <h3 className="font-display mt-1.5 text-[19px] font-bold tracking-[-0.02em]">{s.title}</h3>
                    <p className="mt-2.5 text-[14px] leading-relaxed text-[#5C5F5A]">{s.desc}</p>
                  </div>
                </Reveal3D>
              );
            })}
          </div>
        </div>
      </section>

      {/* ============================ FAQ ============================= */}
      <section className="bg-[#10160F] py-24 text-[#E6E3D9] md:py-32">
        <div className="mx-auto grid max-w-6xl grid-cols-1 gap-12 px-5 sm:px-8 lg:grid-cols-12">
          <div className="lg:col-span-5">
            <Eyebrow>Вопросы и ответы</Eyebrow>
            <h2 className="font-display mt-5 text-[32px] font-extrabold leading-[1.05] tracking-[-0.035em] text-[#F2EEE3] sm:text-[44px]">
              Всё, что важно перед запуском
            </h2>
            <div className="mt-8 flex items-center gap-2.5 text-[13.5px] text-[#A9AEA4]">
              <Lock className="h-4 w-4 text-[#C9A25B]" />
              Изоляция данных и аудит каждого изменения
            </div>
          </div>
          <div className="divide-y divide-white/[0.07] border-y border-white/[0.07] lg:col-span-7">
            {FAQ.map((f, i) => (
              <details key={f.q} className="group py-6 [&_summary::-webkit-details-marker]:hidden" open={i === 0}>
                <summary className="flex cursor-pointer list-none items-start justify-between gap-6">
                  <span className="font-display text-[17px] font-semibold leading-snug text-[#F2EEE3]">{f.q}</span>
                  <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-[#C9A25B]/30 text-[#E2C68C] transition-transform duration-300 group-open:rotate-45">
                    <Plus className="h-3.5 w-3.5" />
                  </span>
                </summary>
                <p className="mt-4 max-w-xl pr-10 text-[15px] leading-relaxed text-[#A9AEA4]">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ======================== FINAL CTA =========================== */}
      <section className="bg-[#10160F] px-3 pb-24 sm:px-6 md:pb-32">
        <Reveal3D>
          <div className="bg-grain relative mx-auto max-w-6xl overflow-hidden rounded-[36px] border border-[#C9A25B]/20 bg-[#18211A] px-6 pb-16 pt-10 text-center sm:px-12 sm:pb-20">
            <div aria-hidden className="pointer-events-none absolute inset-0">
              <div className="absolute left-1/2 top-[-30%] h-[520px] w-[820px] -translate-x-1/2 rounded-full bg-[#C9A25B]/[0.12] blur-[120px]" />
              <div className="hairline-brass absolute inset-x-0 top-0 h-px" />
            </div>

            <div className="relative mx-auto h-[150px] max-w-3xl sm:h-[230px]">
              <Brand3DModel
                modelJson="/brand/korkem_lockup_3d.json"
                fallbackSrc="/brand/korkem_lockup.png"
                alt="KӨRKEM — Since 2021, 3D"
                variant="lockup"
                className="absolute inset-0"
              />
            </div>

            <h2 className="font-display relative mx-auto mt-10 max-w-3xl text-[34px] font-extrabold leading-[1.04] tracking-[-0.04em] text-[#F2EEE3] sm:text-[56px]">
              Наведите порядок в цеху <span className="text-brass">за один день</span>
            </h2>
            <p className="relative mx-auto mt-5 max-w-lg text-[16px] leading-relaxed text-[#A9AEA4]">
              Создайте пространство компании, пригласите сотрудников по ссылке и скачайте актуальную версию для Windows или Android.
            </p>
            <div className="relative mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <Link
                href="/register"
                className="group inline-flex h-[52px] w-full items-center justify-center gap-2 rounded-full bg-[#ECE5D3] px-8 text-[15px] font-semibold text-[#141B13] transition hover:bg-white sm:w-auto"
              >
                Создать компанию
                <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
              </Link>
              <Link
                href="/download"
                className="inline-flex h-[52px] w-full items-center justify-center gap-2 rounded-full border border-white/[0.12] px-8 text-[15px] font-medium text-[#E6E3D9] transition hover:border-[#C9A25B]/50 sm:w-auto"
              >
                <Download className="h-4 w-4 text-[#C9A25B]" />
                Загрузки
              </Link>
            </div>
          </div>
        </Reveal3D>
      </section>
    </div>
  );
}
