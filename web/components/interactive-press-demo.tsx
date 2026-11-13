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

  const totalArea = facades.reduce(
    (sum, f) => sum + Math.round(((f.h * f.w * f.qty) / 1_000_000) * 100) / 100,
    0
  );
  const totalSum = facades.reduce((sum, f) => {
    const area = Math.round(((f.h * f.w * f.qty) / 1_000_000) * 100) / 100;
    return sum + Math.round(area * f.pricePerM2);
  }, 0);
  const totalPieces = facades.reduce((sum, f) => sum + f.qty, 0);

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
    <div className="overflow-hidden rounded-2xl border border-[#3D4A3B] bg-[#2B382A] shadow-[0_32px_90px_-20px_rgba(0,0,0,0.8)]">
      {/* Top Chrome */}
      <div className="flex flex-col gap-3 border-b border-[#3D4A3B] bg-[#232F22] px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-full bg-[#3D4A3B]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#3D4A3B]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#7FD36B]/70" />
          </div>
          <span className="font-mono text-[11px] text-[#A8ADA4]">
            korkem-flow · live simulator
          </span>
        </div>

        <div className="inline-flex rounded-lg border border-[#3D4A3B] bg-[#1B241A] p-1">
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
                  ? "bg-[#DEDAD0] text-[#1B241A] font-semibold"
                  : "text-[#A8ADA4] hover:text-[#E6E3D9]"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Interactive Body */}
      <div className="p-5 sm:p-7 text-left">
        {mode === "press" && (
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
            <div className="lg:col-span-5 flex flex-col justify-between space-y-4">
              <div>
                <div className="flex items-center justify-between">
                  <span className="font-mono text-[11px] uppercase tracking-wider text-[#FFC14D]">
                    Интерактивный заказ #1129
                  </span>
                  <span className="font-mono text-[11px] text-[#A8ADA4]">
                    {totalPieces} дет.
                  </span>
                </div>
                <p className="mt-1 text-xs text-[#A8ADA4]">
                  Измените количество фасадов или тип плёнки — раскладка и
                  стоимость пересчитаются мгновенно:
                </p>

                <div className="mt-4 space-y-2">
                  {facades.map((f) => (
                    <div
                      key={f.id}
                      className="flex items-center justify-between rounded-xl border border-[#3D4A3B] bg-[#1B241A] px-3.5 py-2.5"
                    >
                      <div>
                        <div className="text-xs font-medium text-[#E6E3D9]">
                          {f.label}
                        </div>
                        <div className="font-mono text-[10px] text-[#A8ADA4]">
                          {f.milling} · {f.pricePerM2.toLocaleString("ru-RU")} ₸/м²
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => updateQty(f.id, -1)}
                          aria-label="Уменьшить"
                          className="flex h-6 w-6 items-center justify-center rounded-md border border-[#3D4A3B] text-[#E6E3D9] hover:bg-[#3B4C39]"
                        >
                          <Minus className="h-3 w-3" />
                        </button>
                        <span className="w-5 text-center font-mono text-xs font-semibold text-[#DEDAD0] tabular-nums">
                          {f.qty}
                        </span>
                        <button
                          type="button"
                          onClick={() => updateQty(f.id, 1)}
                          aria-label="Увеличить"
                          className="flex h-6 w-6 items-center justify-center rounded-md border border-[#3D4A3B] text-[#E6E3D9] hover:bg-[#3B4C39]"
                        >
                          <Plus className="h-3 w-3" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>

                <button
                  type="button"
                  onClick={() => setTextured((t) => !t)}
                  className="mt-3 flex w-full items-center justify-between rounded-xl border border-[#3D4A3B] bg-[#1B241A] px-3.5 py-2.5 text-left transition hover:border-[#7D8277]"
                >
                  <div className="flex items-center gap-2 text-xs text-[#E6E3D9]">
                    {textured ? (
                      <Lock className="h-3.5 w-3.5 text-[#FFC14D]" />
                    ) : (
                      <RotateCw className="h-3.5 w-3.5 text-[#7FD36B]" />
                    )}
                    <span>
                      {textured
                        ? "Текстурная плёнка (поворот 90° запрещён)"
                        : "Однотонная плёнка (свободный поворот)"}
                    </span>
                  </div>
                  <span className="font-mono text-[10px] text-[#A8ADA4]">
                    перекл.
                  </span>
                </button>
              </div>

              <div className="grid grid-cols-3 gap-3 border-t border-[#3D4A3B] pt-4 font-mono">
                <div>
                  <div className="text-[10px] text-[#A8ADA4]">Площадь</div>
                  <div className="text-sm font-semibold text-[#DEDAD0] tabular-nums">
                    {totalArea.toFixed(2)} м²
                  </div>
                </div>
                <div>
                  <div className="text-[10px] text-[#A8ADA4]">
                    Плёнка ({loadsCount} загр.)
                  </div>
                  <div className="text-sm font-semibold text-[#FFC14D] tabular-nums">
                    {totalFilmMetres} м.п.
                  </div>
                </div>
                <div>
                  <div className="text-[10px] text-[#A8ADA4]">Сумма заказа</div>
                  <div className="text-sm font-semibold text-[#7FD36B] tabular-nums">
                    {totalSum.toLocaleString("ru-RU")} ₸
                  </div>
                </div>
              </div>
            </div>

            {/* Right: 3D Tactile Press Bed */}
            <div className="lg:col-span-7 flex flex-col justify-between rounded-xl border border-[#3D4A3B] bg-[#1B241A] p-4">
              <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                <div className="font-mono text-xs text-[#E6E3D9]">
                  Пресс Yellow 3013 · Секция{" "}
                  <span className="text-[#FFC14D] font-semibold">
                    {pressSection.toFixed(1)} м
                  </span>
                </div>
                <span className="font-mono text-[10px] text-[#A8ADA4]">
                  Зазор 40 мм · MaxRects
                </span>
              </div>

              <div className="relative min-h-[225px] rounded-lg border border-dashed border-[#7D8277]/60 bg-arch-grid p-3">
                {totalPieces === 0 ? (
                  <div className="flex h-48 items-center justify-center font-mono text-xs text-[#A8ADA4]">
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
                            ? "border-[#D85A30]/60 bg-[#D85A30]/15 text-[#DEDAD0]"
                            : f.id === "f2"
                            ? "border-[#DEDAD0]/35 bg-[#3B4C39]/70 text-[#DEDAD0]"
                            : "border-[#1D9E75]/60 bg-[#1D9E75]/15 text-[#DEDAD0]";
                        return (
                          <div
                            key={`${f.id}-${idx}`}
                            className={`${wClass} ${tone} flex flex-col justify-between rounded-md border p-2 font-mono text-[10px] shadow-sm transition-all duration-200 hover:-translate-y-1 hover:shadow-[0_10px_25px_-5px_rgba(0,0,0,0.65)]`}
                          >
                            <span>
                              {f.h}×{f.w}
                            </span>
                            <span className="text-[9px] opacity-80">
                              {textured ? "↑ волокно" : "↻ 90° ок"}
                            </span>
                          </div>
                        );
                      })
                    )}
                  </div>
                )}
              </div>

              <div className="mt-3 flex items-center justify-between font-mono text-[11px] text-[#A8ADA4]">
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
                <div className="font-mono text-xs text-[#FFC14D]">
                  ОТДЕЛ ПЛЁНКИ ПВХ · ПАРТИИ ПО ТОЛЩИНАМ
                </div>
                <div className="text-xs text-[#A8ADA4] mt-0.5">
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
                        ? "bg-[#DEDAD0] text-[#1B241A] font-semibold"
                        : "border border-[#3D4A3B] text-[#A8ADA4] hover:text-[#E6E3D9]"
                    }`}
                  >
                    {th}
                  </button>
                ))}
              </div>
            </div>

            <div className="overflow-hidden rounded-xl border border-[#3D4A3B]">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-[#3D4A3B] bg-[#232F22] font-mono text-[11px] text-[#A8ADA4]">
                  <tr>
                    <th className="px-4 py-2.5 font-medium">Плёнка</th>
                    <th className="px-4 py-2.5 font-medium">Толщина</th>
                    <th className="px-4 py-2.5 font-medium">Свободно</th>
                    <th className="px-4 py-2.5 font-medium">Отложено</th>
                    <th className="px-4 py-2.5 font-medium">Поставка</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#3D4A3B]/60 font-mono">
                  {visibleRolls.map((r) => (
                    <tr key={r.name} className="bg-[#1B241A]">
                      <td className="px-4 py-3 font-sans">
                        <div className="font-medium text-[#E6E3D9]">
                          {r.name}
                        </div>
                        <div className="text-[11px] text-[#A8ADA4]">
                          {r.maker} · {r.textured ? "Текстурная" : "Гладкая"}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-[#E6E3D9]">{r.thick}</td>
                      <td className="px-4 py-3 text-[#7FD36B]">{r.free}</td>
                      <td className="px-4 py-3 text-[#FFC14D]">{r.reserved}</td>
                      <td
                        className={`px-4 py-3 ${
                          r.low ? "text-[#FF897D] font-semibold" : "text-[#A8ADA4]"
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
              <div className="font-mono text-[11px] uppercase tracking-wider text-[#A8ADA4] mb-2">
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
                      ? "border-[#DEDAD0]/50 bg-[#3B4C39] text-[#E6E3D9]"
                      : "border-[#3D4A3B] bg-[#1B241A] text-[#A8ADA4] hover:text-[#E6E3D9]"
                  }`}
                >
                  «{item.cmd}»
                </button>
              ))}
            </div>

            <div className="lg:col-span-7 flex flex-col justify-between rounded-xl border border-[#3D4A3B] bg-[#1B241A] p-4">
              <div>
                <div className="flex items-center gap-2 font-mono text-[11px] text-[#FFC14D]">
                  <Terminal className="h-3.5 w-3.5" />
                  <span>{currentAi.tool}</span>
                </div>
                <p className="mt-3 text-sm leading-relaxed text-[#E6E3D9]">
                  {currentAi.answer}
                </p>
              </div>

              <div className="mt-5 rounded-xl border border-[#3D4A3B] bg-[#2B382A] p-3.5">
                <div className="flex items-center gap-2 text-[11px] font-medium text-[#E6E3D9]">
                  <ShieldCheck className="h-4 w-4 text-[#7FD36B]" />
                  <span>R10: подтверждение записи человеком</span>
                </div>
                <div className="mt-1.5 font-mono text-xs text-[#A8ADA4]">
                  {currentAi.action}
                </div>
                <button
                  type="button"
                  onClick={() => setConfirmed((c) => !c)}
                  className={`mt-3 inline-flex items-center gap-1.5 rounded-lg px-3.5 py-1.5 text-xs font-semibold transition ${
                    confirmed
                      ? "bg-[#7FD36B] text-[#1B241A]"
                      : "bg-[#DEDAD0] text-[#1B241A] hover:bg-[#F7F5EE]"
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
  );
}
