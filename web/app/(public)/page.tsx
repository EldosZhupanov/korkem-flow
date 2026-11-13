import Link from "next/link";
import {
  ArrowRight,
  ArrowUpRight,
  Check,
  Download,
  Globe,
  Laptop,
  Lock,
  Smartphone,
  Tablet,
} from "lucide-react";
import { InteractivePressDemo } from "@/components/interactive-press-demo";
import { Brand3DMedallion, Reveal3D, Tilt3DStage } from "@/components/motion-3d";
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
      {/* 1. HERO — Official KORKEM Forest Dark (#1B241A) + 3D Stage */}
      <section className="relative overflow-hidden bg-[#1B241A] bg-arch-grid pt-14 pb-24 md:pt-20 md:pb-32 text-[#E6E3D9]">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-44 left-1/2 h-[540px] w-[820px] -translate-x-1/2 rounded-full bg-[#DEDAD0]/[0.08] blur-[150px]"
        />

        <div className="container relative z-10 mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 text-center">
          {/* Official 3D Shanyrak Medallion */}
          <Brand3DMedallion />

          <div className="mt-7">
            <Link
              href="/download"
              className="inline-flex items-center gap-2.5 rounded-full border border-[#3D4A3B] bg-[#2B382A]/80 px-3.5 py-1 text-xs text-[#E6E3D9] transition hover:border-[#7D8277]"
            >
              <span className="h-1.5 w-1.5 rounded-full bg-[#7FD36B]" />
              <span className="font-mono text-[11px] text-[#DEDAD0]">v0.7.8</span>
              <span>Отдел плёнки ПВХ и редактор пресса</span>
              <ArrowUpRight className="h-3.5 w-3.5 text-[#A8ADA4]" />
            </Link>
          </div>

          <h1 className="mx-auto mt-7 max-w-4xl text-4xl font-semibold tracking-[-0.035em] text-[#DEDAD0] sm:text-6xl lg:text-[66px] lg:leading-[1.04]">
            Цифровая архитектура{" "}
            <span className="font-serif italic font-medium text-[#F7F5EE]">
              мебельного
            </span>{" "}
            производства
          </h1>

          <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-[#A8ADA4] sm:text-lg">
            Операционная система для фабрик и цехов: заказы МДФ, раскладка на
            вакуумный пресс, отдел плёнки ПВХ, импорт из БАЗИС и AI-администратор
            в едином пространстве.
          </p>

          <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <Link
              href="/register"
              className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full bg-[#DEDAD0] px-7 text-sm font-semibold text-[#1B241A] shadow-lg transition hover:bg-[#F7F5EE]"
            >
              <span>Создать пространство цеха</span>
              <ArrowRight className="h-4 w-4" />
            </Link>
            <Link
              href="/download"
              className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full border border-[#7D8277]/60 bg-[#2B382A]/60 px-7 text-sm font-medium text-[#E6E3D9] transition hover:border-[#DEDAD0] hover:bg-[#2B382A]"
            >
              <Download className="h-4 w-4 text-[#DEDAD0]" />
              <span>Скачать Windows / Android</span>
            </Link>
          </div>

          {/* 3D Tilt Interactive Product Simulator */}
          <Tilt3DStage intensity={5} className="mx-auto mt-14 max-w-5xl">
            <InteractivePressDemo />
          </Tilt3DStage>
        </div>
      </section>

      {/* 2. EDITORIAL MANIFESTO — Official Cream Paper (#F7F5EE) */}
      <section className="bg-[#F7F5EE] text-[#1E2A1E] border-y border-[#DAD7CA] py-20 md:py-28">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <Reveal3D>
            <div className="grid grid-cols-1 gap-12 lg:grid-cols-12 lg:items-start">
              <div className="lg:col-span-5">
                <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-[#5C5F5A]">
                  Философия KӨRKEM
                </div>
                <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-[#1E2A1E] sm:text-4xl leading-[1.12]">
                  Владелец больше не работает{" "}
                  <span className="font-serif italic font-medium text-[#2B382A]">
                    администратором
                  </span>{" "}
                  за станком
                </h2>
              </div>

              <div className="lg:col-span-7 grid grid-cols-1 gap-8 sm:grid-cols-3 border-t border-[#DAD7CA] pt-8 lg:border-t-0 lg:pt-0">
                <div>
                  <div className="font-mono text-2xl font-semibold text-[#2B382A]">
                    0 мин
                  </div>
                  <div className="mt-2 text-sm font-semibold text-[#1E2A1E]">
                    Потерь между отделами
                  </div>
                  <p className="mt-1.5 text-xs leading-relaxed text-[#5C5F5A]">
                    Замер, КП, фасадный заказ, плёнка, цех и касса связаны с
                    одним производственным заказом.
                  </p>
                </div>
                <div>
                  <div className="font-mono text-2xl font-semibold text-[#2B382A]">
                    MaxRects
                  </div>
                  <div className="mt-2 text-sm font-semibold text-[#1E2A1E]">
                    Точный метраж плёнки
                  </div>
                  <p className="mt-1.5 text-xs leading-relaxed text-[#5C5F5A]">
                    Учитывает секции 1.1 / 2.1 / 3.1 м, зазоры и запрет поворота
                    для текстурных декоров.
                  </p>
                </div>
                <div>
                  <div className="font-mono text-2xl font-semibold text-[#2B382A]">
                    R6 · R7
                  </div>
                  <div className="mt-2 text-sm font-semibold text-[#1E2A1E]">
                    Автономность и приватность
                  </div>
                  <p className="mt-1.5 text-xs leading-relaxed text-[#5C5F5A]">
                    База компании изолирована, а весь цех работает даже без
                    интернета и без ИИ.
                  </p>
                </div>
              </div>
            </div>
          </Reveal3D>

          {/* 6-Stage Architectural Lifecycle */}
          <Reveal3D delayMs={100}>
            <div className="mt-16 grid grid-cols-1 divide-y divide-[#DAD7CA] border border-[#DAD7CA] rounded-2xl bg-[#EDEAE0]/60 sm:grid-cols-2 sm:divide-y-0 lg:grid-cols-6 lg:divide-x">
              {PIPELINE.map((step) => (
                <div key={step.n} className="p-5 transition hover:bg-[#F7F5EE]">
                  <div className="font-mono text-[11px] font-medium text-[#5C5F5A]">
                    {step.n}
                  </div>
                  <div className="mt-2 text-sm font-semibold text-[#1E2A1E]">
                    {step.name}
                  </div>
                  <p className="mt-1.5 text-xs leading-relaxed text-[#5C5F5A]">
                    {step.note}
                  </p>
                </div>
              ))}
            </div>
          </Reveal3D>
        </div>
      </section>

      {/* 3. BENTO CAPABILITIES — Official Forest Dark (#1B241A / #2B382A) */}
      <section className="bg-[#1B241A] text-[#E6E3D9] py-20 md:py-28 border-b border-[#3D4A3B]">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end mb-14">
            <div>
              <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-[#A8ADA4]">
                Модули производства
              </div>
              <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-[#DEDAD0] sm:text-4xl">
                Построено на реальных заказах{" "}
                <span className="font-serif italic font-medium text-[#F7F5EE]">
                  и бланках цеха
                </span>
              </h2>
            </div>
            <Link
              href="/features"
              className="inline-flex items-center gap-1.5 text-sm font-medium text-[#DEDAD0] transition hover:text-white"
            >
              <span>Все возможности</span>
              <ArrowRight className="h-4 w-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-12">
            <Reveal3D className="md:col-span-7" delayMs={0}>
              <SpotlightCard className="h-full p-7 sm:p-8">
                <div className="font-mono text-[11px] uppercase tracking-wider text-[#FFC14D]">
                  01 · Фасады МДФ и Пресс
                </div>
                <h3 className="mt-3 text-xl font-semibold text-[#DEDAD0]">
                  Единое окно заказа МДФ и раскладка на вакуумный пресс
                </h3>
                <p className="mt-2.5 text-sm leading-relaxed text-[#E6E3D9]/80">
                  Прайс-матрица фрезеровка × отделка подставляет цены сама. После
                  принятия цены фиксируются в заказе. Оператор пресса видит
                  оптимальную карту укладки на стол и может поправить её вручную.
                </p>
                <div className="mt-6 flex flex-wrap gap-2 font-mono text-[11px] text-[#DEDAD0]">
                  <span className="rounded-full border border-[#3D4A3B] bg-[#1B241A]/60 px-3 py-1">
                    Печать клиенту и цеху
                  </span>
                  <span className="rounded-full border border-[#3D4A3B] bg-[#1B241A]/60 px-3 py-1">
                    Двусторонние фасады
                  </span>
                  <span className="rounded-full border border-[#3D4A3B] bg-[#1B241A]/60 px-3 py-1">
                    Светофор сроков
                  </span>
                </div>
              </SpotlightCard>
            </Reveal3D>

            <Reveal3D className="md:col-span-5" delayMs={80}>
              <SpotlightCard className="h-full p-7 sm:p-8">
                <div className="font-mono text-[11px] uppercase tracking-wider text-[#7FD36B]">
                  02 · Отдел плёнки ПВХ
                </div>
                <h3 className="mt-3 text-xl font-semibold text-[#DEDAD0]">
                  Рулоны, толщины, касса и клиенты
                </h3>
                <p className="mt-2.5 text-sm leading-relaxed text-[#E6E3D9]/80">
                  Несколько толщин у одной плёнки, статусы «Свободно / Отложено /
                  В пути», чеки со смешанной оплатой, закрытие дня, доска
                  поставщиков и контроль лимита долга клиента.
                </p>
                <div className="mt-6 flex flex-wrap gap-2 font-mono text-[11px] text-[#DEDAD0]">
                  <span className="rounded-full border border-[#3D4A3B] bg-[#1B241A]/60 px-3 py-1">
                    Акт сверки
                  </span>
                  <span className="rounded-full border border-[#3D4A3B] bg-[#1B241A]/60 px-3 py-1">
                    Командный бонус
                  </span>
                </div>
              </SpotlightCard>
            </Reveal3D>

            <Reveal3D className="md:col-span-4" delayMs={120}>
              <SpotlightCard className="h-full p-7">
                <div className="font-mono text-[11px] uppercase tracking-wider text-[#A8ADA4]">
                  03 · БАЗИС и Склад
                </div>
                <h3 className="mt-3 text-lg font-semibold text-[#DEDAD0]">
                  Импорт БАЗИС 10.1 / 10.4
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-[#E6E3D9]/75">
                  Рекурсивный разбор блоков и деталей, учёт деловых обрезков,
                  инвентаризация месяца и алерты «мало листов».
                </p>
              </SpotlightCard>
            </Reveal3D>

            <Reveal3D className="md:col-span-4" delayMs={160}>
              <SpotlightCard className="h-full p-7">
                <div className="font-mono text-[11px] uppercase tracking-wider text-[#A8ADA4]">
                  04 · Люди и 1С
                </div>
                <h3 className="mt-3 text-lg font-semibold text-[#DEDAD0]">
                  Сдельная оплата и выгрузка
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-[#E6E3D9]/75">
                  Мастера отмечают этап на планшете по PIN-коду — зарплата
                  начисляется прозрачно, а бухгалтерия выгружает данные в 1С.
                </p>
              </SpotlightCard>
            </Reveal3D>

            <Reveal3D className="md:col-span-4" delayMs={200}>
              <SpotlightCard className="h-full p-7">
                <div className="font-mono text-[11px] uppercase tracking-wider text-[#A8ADA4]">
                  05 · AI-Ассистент
                </div>
                <h3 className="mt-3 text-lg font-semibold text-[#DEDAD0]">
                  Помощник без самодеятельности
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-[#E6E3D9]/75">
                  Отвечает по фактам из БД в приложении, Telegram и WhatsApp.
                  Любая запись требует подтверждения человеком (R10).
                </p>
              </SpotlightCard>
            </Reveal3D>
          </div>
        </div>
      </section>

      {/* 4. FOUR SURFACES — Cream Paper (#F7F5EE) */}
      <section className="bg-[#F7F5EE] text-[#1E2A1E] py-20 md:py-24 border-b border-[#DAD7CA]">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-2xl text-center mb-14">
            <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-[#5C5F5A]">
              4 интерфейса · 1 ядро
            </div>
            <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] sm:text-4xl">
              Один поток данных от офиса до станка
            </h2>
          </div>

          <Reveal3D>
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
                    className="rounded-2xl border border-[#DAD7CA] bg-[#EDEAE0]/50 p-6 transition duration-300 hover:-translate-y-1 hover:border-[#2B382A] hover:bg-white"
                  >
                    <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-[#DAD7CA] bg-[#2B382A] text-[#DEDAD0]">
                      <Icon className="h-4 w-4" />
                    </div>
                    <div className="mt-5 font-mono text-[11px] text-[#5C5F5A]">
                      {item.role}
                    </div>
                    <h3 className="mt-1 text-base font-semibold text-[#1E2A1E]">
                      {item.title}
                    </h3>
                    <p className="mt-2 text-xs leading-relaxed text-[#5C5F5A]">
                      {item.desc}
                    </p>
                  </div>
                );
              })}
            </div>
          </Reveal3D>
        </div>
      </section>

      {/* 5. FAQ + FINAL CTA — Forest Dark (#1B241A) */}
      <section className="bg-[#1B241A] text-[#E6E3D9] py-20 md:py-28">
        <div className="container mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 gap-12 lg:grid-cols-12">
            <div className="lg:col-span-4">
              <div className="font-mono text-[11px] uppercase tracking-[0.2em] text-[#A8ADA4]">
                Вопросы и ответы
              </div>
              <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-[#DEDAD0]">
                Всё, что важно перед{" "}
                <span className="font-serif italic font-medium text-[#F7F5EE]">
                  запуском
                </span>
              </h2>
              <div className="mt-6 space-y-2.5 text-xs text-[#A8ADA4]">
                <div className="flex items-center gap-2">
                  <Lock className="h-3.5 w-3.5 text-[#7FD36B]" />
                  <span>Изоляция данных на уровне компании</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check className="h-3.5 w-3.5 text-[#7FD36B]" />
                  <span>Аудит каждого изменения</span>
                </div>
              </div>
            </div>

            <div className="lg:col-span-8 divide-y divide-[#3D4A3B] border-y border-[#3D4A3B]">
              {FAQ.map((item) => (
                <div key={item.q} className="py-6">
                  <h3 className="text-base font-medium text-[#DEDAD0]">
                    {item.q}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-[#A8ADA4]">
                    {item.a}
                  </p>
                </div>
              ))}
            </div>
          </div>

          {/* Closing CTA with Official Brand Lockup */}
          <Reveal3D delayMs={100}>
            <div className="mt-24 rounded-3xl border border-[#3D4A3B] bg-[#2B382A] px-6 py-14 text-center sm:px-12 sm:py-16 shadow-2xl">
              <img
                src="/brand/korkem_lockup.png"
                alt="KӨRKEM — Since 2021"
                className="mx-auto h-12 w-auto rounded-lg border border-[#3D4A3B] bg-[#070B07] px-3 py-1.5 object-contain"
              />
              <h2 className="mx-auto mt-6 max-w-2xl text-3xl font-semibold tracking-[-0.03em] text-[#DEDAD0] sm:text-5xl">
                Наведите порядок в цеху за{" "}
                <span className="font-serif italic font-medium text-[#F7F5EE]">
                  один день
                </span>
              </h2>
              <p className="mx-auto mt-4 max-w-lg text-sm text-[#E6E3D9]/80">
                Создайте пространство компании, пригласите сотрудников по ссылке и
                скачайте актуальную версию для Windows или Android.
              </p>
              <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
                <Link
                  href="/register"
                  className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full bg-[#DEDAD0] px-8 text-sm font-semibold text-[#1B241A] transition hover:bg-[#F7F5EE]"
                >
                  <span>Создать компанию</span>
                  <ArrowRight className="h-4 w-4" />
                </Link>
                <Link
                  href="/download"
                  className="inline-flex h-12 w-full sm:w-auto items-center justify-center gap-2 rounded-full border border-[#7D8277] px-8 text-sm font-medium text-[#DEDAD0] transition hover:border-[#DEDAD0] hover:bg-[#3B4C39]"
                >
                  <span>Страница загрузок</span>
                </Link>
              </div>
            </div>
          </Reveal3D>
        </div>
      </section>
    </div>
  );
}
