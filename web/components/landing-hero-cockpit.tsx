"use client";

import * as React from "react";
import {
  CheckCircle2,
  Cpu,
  Layers,
  Lock,
  MessageSquare,
  ShieldCheck,
  Sparkles,
  Truck,
} from "lucide-react";

type TabId = "mdf" | "film" | "ai";

const TABS: { id: TabId; label: string; badge: string }[] = [
  { id: "mdf", label: "Заказы МДФ и Пресс", badge: "MaxRects" },
  { id: "film", label: "Отдел плёнки ПВХ", badge: "Склад + Касса" },
  { id: "ai", label: "AI-администратор", badge: "R10 Safe" },
];

export function LandingHeroCockpit() {
  const [activeTab, setActiveTab] = React.useState<TabId>("mdf");
  const [aiConfirmed, setAiConfirmed] = React.useState(false);

  return (
    <div className="relative mx-auto mt-14 max-w-5xl">
      {/* Ambient glow behind cockpit */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -inset-4 rounded-[2rem] bg-gradient-to-tr from-sky-500/15 via-cyan-400/10 to-amber-500/15 blur-2xl"
      />

      <div className="relative overflow-hidden rounded-2xl border border-white/10 bg-[#0B1120]/95 shadow-[0_24px_80px_-16px_rgba(0,0,0,0.85)] backdrop-blur-xl">
        {/* Window Chrome + Interactive Tabs */}
        <div className="flex flex-col gap-3 border-b border-white/10 bg-white/[0.02] px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-full bg-rose-500/70" />
              <span className="h-2.5 w-2.5 rounded-full bg-amber-400/70" />
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-500/70" />
            </div>
            <span className="font-mono text-[11px] text-slate-400">
              korkem-flow · desktop v0.7.8 · local-first
            </span>
          </div>

          <div className="flex flex-wrap gap-1.5">
            {TABS.map((tab) => {
              const active = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveTab(tab.id)}
                  className={`inline-flex items-center gap-2 rounded-lg px-3 py-1.5 text-xs font-medium transition-all ${
                    active
                      ? "bg-sky-500/15 text-sky-300 ring-1 ring-sky-400/40 shadow-sm"
                      : "text-slate-400 hover:bg-white/5 hover:text-slate-200"
                  }`}
                >
                  <span>{tab.label}</span>
                  <span
                    className={`rounded px-1.5 py-0.5 font-mono text-[10px] ${
                      active
                        ? "bg-sky-400/20 text-sky-200"
                        : "bg-white/5 text-slate-500"
                    }`}
                  >
                    {tab.badge}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Tab Content */}
        <div className="p-5 sm:p-7 text-left">
          {activeTab === "mdf" && (
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
              {/* Left: Order Card & Stages */}
              <div className="lg:col-span-5 flex flex-col justify-between rounded-xl border border-white/10 bg-white/[0.02] p-4">
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs text-sky-400">
                      ЗАКАЗ #1129
                    </span>
                    <span className="inline-flex items-center gap-1 rounded-full bg-amber-500/15 px-2.5 py-0.5 text-[11px] font-medium text-amber-300 ring-1 ring-amber-400/30">
                      В цеху · Срок 18.11
                    </span>
                  </div>
                  <h4 className="mt-2 text-base font-bold text-white">
                    Кухня «Астана Премиум» — Дуб Сонома
                  </h4>
                  <p className="mt-1 text-xs text-slate-400">
                    МДФ 16 мм · ПВХ 0.35 мм · Фреза: Суреттегі үлгі + Тегіс 90°
                  </p>

                  {/* 5 Stage Pipeline */}
                  <div className="mt-4 space-y-2">
                    <div className="text-[11px] font-medium uppercase tracking-wider text-slate-400">
                      Маршрут цеха (PIN-терминал)
                    </div>
                    <div className="grid grid-cols-5 gap-1.5">
                      {[
                        { name: "Раскрой", done: true },
                        { name: "Фреза", done: true },
                        { name: "Шлиф.", active: true },
                        { name: "Вакуум", done: false },
                        { name: "Упак.", done: false },
                      ].map((step) => (
                        <div
                          key={step.name}
                          className={`rounded-md px-1.5 py-1.5 text-center text-[10px] font-medium border ${
                            step.done
                              ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300"
                              : step.active
                              ? "border-sky-400/50 bg-sky-500/15 text-sky-200 animate-pulse"
                              : "border-white/5 bg-white/[0.02] text-slate-500"
                          }`}
                        >
                          {step.name}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Totals */}
                <div className="mt-5 grid grid-cols-3 gap-2 border-t border-white/10 pt-3 font-mono">
                  <div>
                    <div className="text-[10px] text-slate-500">Площадь</div>
                    <div className="text-sm font-semibold text-white tabular-nums">
                      3.04 м²
                    </div>
                  </div>
                  <div>
                    <div className="text-[10px] text-slate-500">Плёнка</div>
                    <div className="text-sm font-semibold text-sky-300 tabular-nums">
                      2.10 м.п.
                    </div>
                  </div>
                  <div>
                    <div className="text-[10px] text-slate-500">Сумма</div>
                    <div className="text-sm font-semibold text-emerald-300 tabular-nums">
                      58 680 ₸
                    </div>
                  </div>
                </div>
              </div>

              {/* Right: Live MaxRects Press Table Visualization */}
              <div className="lg:col-span-7 rounded-xl border border-white/10 bg-[#070B14] p-4">
                <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                  <div className="flex items-center gap-2">
                    <Cpu className="h-4 w-4 text-sky-400" />
                    <span className="text-xs font-semibold text-white">
                      Стол пресса Yellow 3013 · Секция 2.1 м
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="inline-flex items-center gap-1 rounded bg-white/5 px-2 py-0.5 font-mono text-[10px] text-amber-300">
                      <Lock className="h-3 w-3" /> Текстура: поворот 90° запрещён
                    </span>
                    <span className="inline-flex items-center gap-1 rounded bg-emerald-500/15 px-2 py-0.5 font-mono text-[10px] text-emerald-300">
                      Раскрой проверен ✓
                    </span>
                  </div>
                </div>

                {/* Press Bed Grid */}
                <div className="relative h-52 w-full rounded-lg border border-dashed border-sky-500/30 bg-grid-slate p-2.5">
                  <div className="grid h-full grid-cols-12 grid-rows-6 gap-1.5 font-mono text-[10px]">
                    <div className="col-span-4 row-span-4 flex flex-col justify-between rounded border border-sky-400/50 bg-sky-500/20 p-2 text-sky-100">
                      <span>#1 · 716×596</span>
                      <span className="text-[9px] text-sky-300/80">Суреттегі · 2 шт</span>
                    </div>
                    <div className="col-span-4 row-span-4 flex flex-col justify-between rounded border border-sky-400/50 bg-sky-500/20 p-2 text-sky-100">
                      <span>#2 · 716×596</span>
                      <span className="text-[9px] text-sky-300/80">Суреттегі · 2 шт</span>
                    </div>
                    <div className="col-span-4 row-span-3 flex flex-col justify-between rounded border border-amber-400/50 bg-amber-500/20 p-2 text-amber-100">
                      <span>#3 · 716×396</span>
                      <span className="text-[9px] text-amber-300/80">Тегіс 90°</span>
                    </div>
                    <div className="col-span-4 row-span-3 flex flex-col justify-between rounded border border-amber-400/50 bg-amber-500/20 p-2 text-amber-100">
                      <span>#4 · 356×396</span>
                      <span className="text-[9px] text-amber-300/80">Ящик · 3 шт</span>
                    </div>
                    <div className="col-span-5 row-span-2 flex items-center justify-between rounded border border-emerald-400/40 bg-emerald-500/15 px-2.5 text-emerald-100">
                      <span>#5 · 140×596 (Цоколь)</span>
                      <span className="text-[9px] text-emerald-300">Зазор 40 мм</span>
                    </div>
                    <div className="col-span-3 row-span-2 flex items-center justify-center rounded border border-white/10 bg-white/[0.02] text-slate-500">
                      Свободно 14%
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === "film" && (
            <div className="grid grid-cols-1 gap-5 lg:grid-cols-12">
              <div className="lg:col-span-7 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-xs font-semibold text-white">
                    <Layers className="h-4 w-4 text-sky-400" />
                    <span>Каталог плёнок ПВХ по толщинам и партиям</span>
                  </div>
                  <span className="font-mono text-[11px] text-slate-400">
                    3 склада · авто-резерв
                  </span>
                </div>

                {[
                  {
                    name: "Белый Софт-тач 1042",
                    maker: "Alfatherm · Текстурная: Нет",
                    thick: "0.35 мм",
                    free: "84.5 м",
                    reserved: "12.0 м",
                    transit: "+100 м (15.11)",
                  },
                  {
                    name: "Дуб Вотан Натурал",
                    maker: "Renolit · Текстурная: Да",
                    thick: "0.50 мм",
                    free: "18.2 м",
                    reserved: "24.0 м",
                    transit: "Мало! К заказу",
                    low: true,
                  },
                  {
                    name: "Кашемир Матовый 703",
                    maker: "LG Hausys · Текстурная: Нет",
                    thick: "0.35 мм",
                    free: "52.0 м",
                    reserved: "6.5 м",
                    transit: "В наличии",
                  },
                ].map((row) => (
                  <div
                    key={row.name}
                    className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/[0.02] px-4 py-3"
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-white">
                          {row.name}
                        </span>
                        <span className="rounded bg-white/10 px-1.5 py-0.5 font-mono text-[10px] text-slate-300">
                          {row.thick}
                        </span>
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {row.maker}
                      </div>
                    </div>
                    <div className="flex items-center gap-4 font-mono text-xs">
                      <div>
                        <div className="text-[10px] text-slate-500">Свободно</div>
                        <div className="text-emerald-300 font-semibold">
                          {row.free}
                        </div>
                      </div>
                      <div>
                        <div className="text-[10px] text-slate-500">Отложено</div>
                        <div className="text-amber-300 font-semibold">
                          {row.reserved}
                        </div>
                      </div>
                      <div>
                        <div className="text-[10px] text-slate-500">Статус</div>
                        <div
                          className={
                            row.low
                              ? "text-rose-400 font-semibold"
                              : "text-sky-300"
                          }
                        >
                          {row.transit}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Right: Mixed Payment & Customer Limit */}
              <div className="lg:col-span-5 rounded-xl border border-white/10 bg-[#070B14] p-4 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs text-emerald-400">
                      ЧЕК ПРОДАЖИ #ПЛ-408
                    </span>
                    <span className="inline-flex items-center gap-1 rounded bg-sky-500/15 px-2 py-0.5 text-[10px] text-sky-300">
                      <Truck className="h-3 w-3" /> Выдал: Ерлан
                    </span>
                  </div>
                  <div className="mt-3 text-sm font-bold text-white">
                    Клиент: ТОО «Мебель Строй»
                  </div>
                  <div className="text-xs text-slate-400 mt-0.5">
                    Лимит долга: 300 000 ₸ · Текущий долг: 45 000 ₸
                  </div>
                  <div className="mt-4 space-y-2 border-y border-white/10 py-3 font-mono text-xs">
                    <div className="flex justify-between text-slate-300">
                      <span>Белый Софт-тач (14.5 м × 2 800 ₸)</span>
                      <span>40 600 ₸</span>
                    </div>
                    <div className="flex justify-between text-slate-400">
                      <span>Kaspi QR / Перевод</span>
                      <span>25 000 ₸</span>
                    </div>
                    <div className="flex justify-between text-slate-400">
                      <span>Наличные в кассу</span>
                      <span>15 600 ₸</span>
                    </div>
                  </div>
                </div>
                <div className="mt-3 flex items-center justify-between">
                  <span className="text-xs text-slate-400">
                    Остаток рулона обновлён
                  </span>
                  <span className="font-mono text-sm font-bold text-emerald-300">
                    Оплачено 100%
                  </span>
                </div>
              </div>
            </div>
          )}

          {activeTab === "ai" && (
            <div className="grid grid-cols-1 gap-5 lg:grid-cols-12">
              <div className="lg:col-span-7 space-y-3">
                <div className="flex items-start gap-3">
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-white/10 text-slate-200">
                    <MessageSquare className="h-4 w-4" />
                  </div>
                  <div className="rounded-xl rounded-tl-none border border-white/10 bg-white/[0.04] px-4 py-3 text-sm text-slate-100">
                    «Стою у станка: по заказу №1129 сколько плёнки уйдёт с
                    прессом и хватит ли Дуба Сонома на складе? Если нет —
                    зарезервируй из свободного остатка.»
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-sky-500/20 text-sky-300 ring-1 ring-sky-400/30">
                    <Sparkles className="h-4 w-4" />
                  </div>
                  <div className="flex-1 rounded-xl rounded-tl-none border border-sky-500/20 bg-sky-500/[0.06] px-4 py-3 text-sm text-slate-200 space-y-2">
                    <div className="font-mono text-[11px] text-sky-300">
                      tools: mdf_orders.get · press_layout.calculate ·
                      film_dept.stock
                    </div>
                    <p className="leading-relaxed">
                      По заказу <strong className="text-white">#1129</strong>{" "}
                      (3.04 м²) раскладка на пресс укладывается в{" "}
                      <strong className="text-white">1 загрузку (2.10 м.п.)</strong>
                      . На складе свободно{" "}
                      <strong className="text-emerald-300">18.2 м.п.</strong> —
                      хватает с запасом.
                    </p>
                  </div>
                </div>
              </div>

              {/* Right: R10 Confirmation Gate */}
              <div className="lg:col-span-5 rounded-xl border border-amber-400/30 bg-amber-500/[0.06] p-4 flex flex-col justify-between">
                <div>
                  <div className="flex items-center gap-2 text-xs font-semibold text-amber-300">
                    <ShieldCheck className="h-4 w-4" />
                    <span>Правило R10: подтверждение человеком</span>
                  </div>
                  <p className="mt-2 text-xs text-slate-300 leading-relaxed">
                    ИИ никогда не списывает материалы и не меняет заказы втихую.
                    Любая запись проходит через Service API и ждёт вашего клика:
                  </p>
                  <div className="mt-3 rounded-lg border border-white/10 bg-[#070B14] p-3 font-mono text-xs text-slate-200">
                    <div>Действие: Резерв плёнки под #1129</div>
                    <div className="text-amber-300 mt-1">Объём: 2.10 м.п. (Дуб Сонома)</div>
                  </div>
                </div>

                <div className="mt-4 flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setAiConfirmed((prev) => !prev)}
                    className={`flex-1 inline-flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition ${
                      aiConfirmed
                        ? "bg-emerald-500 text-slate-950"
                        : "bg-sky-500 text-slate-950 hover:bg-sky-400"
                    }`}
                  >
                    <CheckCircle2 className="h-3.5 w-3.5" />
                    {aiConfirmed
                      ? "Подтверждено в аудит-логе"
                      : "Подтвердить резерв"}
                  </button>
                  {aiConfirmed && (
                    <button
                      type="button"
                      onClick={() => setAiConfirmed(false)}
                      className="rounded-lg border border-white/15 px-3 py-2 text-xs text-slate-300 hover:bg-white/5"
                    >
                      Сброс
                    </button>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
