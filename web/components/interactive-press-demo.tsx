"use client";

import * as React from "react";
import {
  Check,
  Lock,
  Minus,
  Plus,
  RotateCw,
  ShieldCheck,
  Terminal,
} from "lucide-react";

type Mode = "press" | "film" | "ai";

interface FacadeItem {
  id: string;
  label: string;
  h: number;
  w: number;
  qty: number;
  milling: string;
  pricePerM2: number;
}

const INITIAL_FACADES: FacadeItem[] = [
  { id: "f1", label: "Пенал 716×596", h: 716, w: 596, qty: 2, milling: "Суреттегі үлгі", pricePerM2: 19500 },
  { id: "f2", label: "Верх 716×396", h: 716, w: 396, qty: 3, milling: "Тегіс 90°", pricePerM2: 17000 },
  { id: "f3", label: "Ящик 356×596", h: 356, w: 596, qty: 2, milling: "Тегіс 90°", pricePerM2: 17000 },
];

const FILM_ROLLS = [
  { name: "Дуб Сонома 401", maker: "Renolit", thick: "0.35 мм", free: "42.0 м", reserved: "12.5 м", transit: "На складе", textured: true },
  { name: "Кашемир Матовый", maker: "LG Hausys", thick: "0.35 мм", free: "84.5 м", reserved: "6.0 м", transit: "+100 м (15.11)", textured: false },
  { name: "Антрацит Софт-тач", maker: "Alfatherm", thick: "0.50 мм", free: "14.2 м", reserved: "18.0 м", transit: "К заказу", low: true, textured: false },
];

const AI_PROMPTS = [
  {
    cmd: "Сколько плёнки уйдёт на #1129 и хватит ли на складе?",
    tool: "mdf_orders.get · press_layout.pack · film_dept.stock",
    answer: "Заказ #1129 (3.04 м²) ложится в 1 загрузку секции 2.1 м пресса Yellow 3013. На складе свободно 42.0 м — хватает с запасом.",
    action: "Зарезервировать 2.10 м.п. Дуб Сонома под #1129",
  },
  {
    cmd: "Какие заказы МДФ горят по срокам на этой неделе?",
    tool: "mdf_orders.list_overdue · shop_floor.queue",
    answer: "На контроле 2 заказа: #1124 (срок завтра, этап «Вакуум») и #1118 (остаток оплаты 34 000 ₸, готов к выдаче).",
    action: "Отправить напоминание мастеру пресса в цех",
  },
  {
    cmd: "Закрой смену цеха за сегодня и посчитай сдельную.",
    tool: "piece_work.daily_summary · mdf_cash.day_close",
    answer: "Выполнено 19 операций на 48 200 ₸ (3 мастера). По кассе плёнки: 142 000 ₸ (Kaspi 98 000 ₸ + наличные 44 000 ₸).",
    action: "Провести закрытие смены и зафиксировать ведомость",
  },
];

export function InteractivePressDemo() {
  const [mode, setMode] = React.useState<Mode>("press");
  const [facades, setFacades] = React.useState<FacadeItem[]>(INITIAL_FACADES);
  const [textured, setTextured] = React.useState(true);
  const [thickFilter, setThickFilter] = React.useState<string>("Все");
  const [aiIdx, setAiIdx] = React.useState(0);
  const [confirmed, setConfirmed] = React.useState(false);

  const updateQty = (id: string, delta: number) => {
    setFacades((prev) =>
      prev.map((f) =>
        f.id === id ? { ...f, qty: Math.max(0, Math.min(8, f.qty + delta)) } : f
      )
    );
  };

  // Live calculations mirroring domain rules
  const totalArea = facades.reduce(
    (sum, f) => sum + Math.round(((f.h * f.w * f.qty) / 1_000_000) * 100) / 100,
    0
  );
  const totalSum = facades.reduce((sum, f) => {
    const area = Math.round(((f.h * f.w * f.qty) / 1_000_000) * 100) / 100;
    return sum + Math.round(area * f.pricePerM2);
  }, 0);
  const totalPieces = facades.reduce((sum, f) => sum + f.qty, 0);

  // Press section estimation (1.1 / 2.1 / 3.1m)
  const effectiveArea = textured ? totalArea * 1.12 : totalArea;
  const pressSection =
    effectiveArea <= 1.25 ? 1.1 : effectiveArea <= 2.45 ? 2.1 : 3.1;
  const loadsCount = Math.max(1, Math.ceil(effectiveArea / 3.2));
  const totalFilmMetres = (pressSection * loadsCount).toFixed(1);

  const visibleRolls = FILM_ROLLS.filter(
    (r) => thickFilter === "Все" || r.thick === thickFilter
  );

  const currentAi = AI_PROMPTS[aiIdx];

  return (
    <div className="relative mx-auto mt-14 max-w-5xl text-left">
      <div className="overflow-hidden rounded-2xl border border-white/[0.12] bg-[#0E0E11] shadow-[0_32px_100px_-20px_rgba(0,0,0,0.9)]">
        {/* Top Chrome */}
        <div className="flex flex-col gap-3 border-b border-white/[0.08] bg-[#141418] px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-full bg-zinc-700" />
              <span className="h-2.5 w-2.5 rounded-full bg-zinc-700" />
              <span className="h-2.5 w-2.5 rounded-full bg-zinc-700" />
            </div>
            <span className="font-mono text-[11px] text-zinc-400">
              korkem-flow · live simulator
            </span>
          </div>

          <div className="inline-flex rounded-lg border border-white/[0.08] bg-[#09090B] p-1">
            {[
              { id: "press" as Mode, label: "1. Пресс и Заказ МДФ" },
              { id: "film" as Mode, label: "2. Склад плёнки" },
              { id: "ai" as Mode, label: "3. AI-администратор" },
            ].map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setMode(tab.id)}
                className={`rounded-md px-3 py-1.5 text-xs font-medium transition ${
                  mode === tab.id
                    ? "bg-[#F5F5F0] text-[#09090B]"
                    : "text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Interactive Body */}
        <div className="p-5 sm:p-7">
          {mode === "press" && (
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
              {/* Left Controls: Real Interactive Facade Qty */}
              <div className="lg:col-span-5 flex flex-col justify-between space-y-4">
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-[11px] uppercase tracking-wider text-amber-400">
                      Интерактивный заказ #1129
                    </span>
                    <span className="font-mono text-[11px] text-zinc-500">
                      {totalPieces} дет.
                    </span>
                  </div>
                  <p className="mt-1 text-xs text-zinc-400">
                    Измените количество фасадов или тип плёнки — раскладка на
                    столе и итог пересчитаются сразу:
                  </p>

                  <div className="mt-4 space-y-2">
                    {facades.map((f) => (
                      <div
                        key={f.id}
                        className="flex items-center justify-between rounded-xl border border-white/[0.08] bg-[#141418] px-3.5 py-2.5"
                      >
                        <div>
                          <div className="text-xs font-medium text-[#F5F5F0]">
                            {f.label}
                          </div>
                          <div className="font-mono text-[10px] text-zinc-500">
                            {f.milling} · {f.pricePerM2.toLocaleString("ru-RU")} ₸/м²
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => updateQty(f.id, -1)}
                            aria-label="Уменьшить"
                            className="flex h-6 w-6 items-center justify-center rounded-md border border-white/10 text-zinc-300 hover:bg-white/10"
                          >
                            <Minus className="h-3 w-3" />
                          </button>
                          <span className="w-5 text-center font-mono text-xs font-semibold text-white tabular-nums">
                            {f.qty}
                          </span>
                          <button
                            type="button"
                            onClick={() => updateQty(f.id, 1)}
                            aria-label="Увеличить"
                            className="flex h-6 w-6 items-center justify-center rounded-md border border-white/10 text-zinc-300 hover:bg-white/10"
                          >
                            <Plus className="h-3 w-3" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>

                  {/* Texture toggle */}
                  <button
                    type="button"
                    onClick={() => setTextured((t) => !t)}
                    className="mt-3 flex w-full items-center justify-between rounded-xl border border-white/[0.08] bg-[#141418] px-3.5 py-2.5 text-left transition hover:border-white/20"
                  >
                    <div className="flex items-center gap-2 text-xs text-zinc-200">
                      {textured ? (
                        <Lock className="h-3.5 w-3.5 text-amber-400" />
                      ) : (
                        <RotateCw className="h-3.5 w-3.5 text-emerald-400" />
                      )}
                      <span>
                        {textured
                          ? "Текстурная плёнка (поворот 90° запрещён)"
                          : "Однотонная плёнка (свободный поворот)"}
                      </span>
                    </div>
                    <span className="font-mono text-[10px] text-zinc-400">
                      перекл.
                    </span>
                  </button>
                </div>

                {/* Live Totals */}
                <div className="grid grid-cols-3 gap-3 border-t border-white/[0.08] pt-4 font-mono">
                  <div>
                    <div className="text-[10px] text-zinc-500">Площадь</div>
                    <div className="text-sm font-semibold text-[#F5F5F0] tabular-nums">
                      {totalArea.toFixed(2)} м²
                    </div>
                  </div>
                  <div>
                    <div className="text-[10px] text-zinc-500">
                      Плёнка ({loadsCount} загр.)
                    </div>
                    <div className="text-sm font-semibold text-amber-300 tabular-nums">
                      {totalFilmMetres} м.п.
                    </div>
                  </div>
                  <div>
                    <div className="text-[10px] text-zinc-500">Сумма заказа</div>
                    <div className="text-sm font-semibold text-emerald-400 tabular-nums">
                      {totalSum.toLocaleString("ru-RU")} ₸
                    </div>
                  </div>
                </div>
              </div>

              {/* Right: Live Press Bed */}
              <div className="lg:col-span-7 flex flex-col justify-between rounded-xl border border-white/[0.08] bg-[#09090B] p-4">
                <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                  <div className="font-mono text-xs text-zinc-300">
                    Пресс Yellow 3013 · Секция{" "}
                    <span className="text-amber-300 font-semibold">
                      {pressSection.toFixed(1)} м
                    </span>
                  </div>
                  <span className="font-mono text-[10px] text-zinc-500">
                    Зазор 40 мм · MaxRects
                  </span>
                </div>

                <div className="relative min-h-[220px] rounded-lg border border-dashed border-white/15 bg-arch-grid p-3">
                  {totalPieces === 0 ? (
                    <div className="flex h-48 items-center justify-center font-mono text-xs text-zinc-500">
                      Добавьте хотя бы один фасад слева
                    </div>
                  ) : (
                    <div className="flex flex-wrap content-start gap-2">
                      {facades.flatMap((f) =>
                        Array.from({ length: f.qty }).map((_, idx) => {
                          const wClass =
                            f.w >= 550
                              ? textured
                                ? "w-[116px] h-[74px]"
                                : "w-[96px] h-[82px]"
                              : "w-[82px] h-[74px]";
                          const tone =
                            f.id === "f1"
                              ? "border-amber-400/40 bg-amber-500/15 text-amber-100"
                              : f.id === "f2"
                              ? "border-white/25 bg-white/[0.07] text-zinc-100"
                              : "border-emerald-400/35 bg-emerald-500/10 text-emerald-100";
                          return (
                            <div
                              key={`${f.id}-${idx}`}
                              className={`${wClass} ${tone} flex flex-col justify-between rounded border p-2 font-mono text-[10px] transition-all duration-200`}
                            >
                              <span>
                                {f.h}×{f.w}
                              </span>
                              <span className="text-[9px] opacity-70">
                                {textured ? "↑ волокно" : "↻ 90° ок"}
                              </span>
                            </div>
                          );
                        })
                      )}
                    </div>
                  )}
                </div>

                <div className="mt-3 flex items-center justify-between font-mono text-[11px] text-zinc-500">
                  <span>Статус: Раскрой проверен</span>
                  <span>Бланк цеха: Без цен</span>
                </div>
              </div>
            </div>
          )}

          {mode === "film" && (
            <div className="space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <div className="font-mono text-xs text-amber-400">
                    ОТДЕЛ ПЛЁНКИ ПВХ · ПАРТИИ ПО ТОЛЩИНАМ
                  </div>
                  <div className="text-xs text-zinc-400 mt-0.5">
                    Одна плёнка — несколько толщин со своими метрами, ценой
                    закупа и резервом
                  </div>
                </div>
                <div className="flex gap-1.5">
                  {["Все", "0.35 мм", "0.50 мм"].map((th) => (
                    <button
                      key={th}
                      type="button"
                      onClick={() => setThickFilter(th)}
                      className={`rounded-md px-2.5 py-1 font-mono text-[11px] transition ${
                        thickFilter === th
                          ? "bg-[#F5F5F0] text-[#09090B] font-semibold"
                          : "border border-white/10 text-zinc-400 hover:text-white"
                      }`}
                    >
                      {th}
                    </button>
                  ))}
                </div>
              </div>

              <div className="overflow-hidden rounded-xl border border-white/[0.08]">
                <table className="w-full text-left text-xs">
                  <thead className="border-b border-white/[0.08] bg-[#141418] font-mono text-[11px] text-zinc-400">
                    <tr>
                      <th className="px-4 py-2.5 font-medium">Плёнка</th>
                      <th className="px-4 py-2.5 font-medium">Толщина</th>
                      <th className="px-4 py-2.5 font-medium">Свободно</th>
                      <th className="px-4 py-2.5 font-medium">Отложено</th>
                      <th className="px-4 py-2.5 font-medium">Поставка</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/[0.06] font-mono">
                    {visibleRolls.map((r) => (
                      <tr key={r.name} className="bg-[#09090B]">
                        <td className="px-4 py-3 font-sans">
                          <div className="font-medium text-[#F5F5F0]">
                            {r.name}
                          </div>
                          <div className="text-[11px] text-zinc-500">
                            {r.maker} · {r.textured ? "Текстурная" : "Гладкая"}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-zinc-300">{r.thick}</td>
                        <td className="px-4 py-3 text-emerald-400">{r.free}</td>
                        <td className="px-4 py-3 text-amber-300">{r.reserved}</td>
                        <td
                          className={`px-4 py-3 ${
                            r.low ? "text-rose-400 font-semibold" : "text-zinc-400"
                          }`}
                        >
                          {r.transit}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {mode === "ai" && (
            <div className="grid grid-cols-1 gap-5 lg:grid-cols-12">
              <div className="lg:col-span-5 space-y-2">
                <div className="font-mono text-[11px] uppercase tracking-wider text-zinc-500 mb-2">
                  Выберите вопрос из цеха
                </div>
                {AI_PROMPTS.map((item, idx) => (
                  <button
                    key={item.cmd}
                    type="button"
                    onClick={() => {
                      setAiIdx(idx);
                      setConfirmed(false);
                    }}
                    className={`w-full rounded-xl border p-3 text-left text-xs transition ${
                      aiIdx === idx
                        ? "border-amber-400/50 bg-amber-500/10 text-[#F5F5F0]"
                        : "border-white/[0.08] bg-[#141418] text-zinc-400 hover:text-zinc-200"
                    }`}
                  >
                    «{item.cmd}»
                  </button>
                ))}
              </div>

              <div className="lg:col-span-7 flex flex-col justify-between rounded-xl border border-white/[0.08] bg-[#09090B] p-4">
                <div>
                  <div className="flex items-center gap-2 font-mono text-[11px] text-amber-400">
                    <Terminal className="h-3.5 w-3.5" />
                    <span>{currentAi.tool}</span>
                  </div>
                  <p className="mt-3 text-sm leading-relaxed text-[#F5F5F0]">
                    {currentAi.answer}
                  </p>
                </div>

                <div className="mt-5 rounded-xl border border-white/[0.08] bg-[#141418] p-3.5">
                  <div className="flex items-center gap-2 text-[11px] font-medium text-zinc-300">
                    <ShieldCheck className="h-4 w-4 text-emerald-400" />
                    <span>R10: подтверждение записи человеком</span>
                  </div>
                  <div className="mt-1.5 font-mono text-xs text-zinc-400">
                    {currentAi.action}
                  </div>
                  <button
                    type="button"
                    onClick={() => setConfirmed((c) => !c)}
                    className={`mt-3 inline-flex items-center gap-1.5 rounded-lg px-3.5 py-1.5 text-xs font-semibold transition ${
                      confirmed
                        ? "bg-emerald-500 text-slate-950"
                        : "bg-[#F5F5F0] text-[#09090B] hover:bg-white"
                    }`}
                  >
                    <Check className="h-3.5 w-3.5" />
                    {confirmed ? "Записано в аудит" : "Подтвердить действие"}
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
