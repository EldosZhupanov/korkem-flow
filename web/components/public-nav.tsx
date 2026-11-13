"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X, ArrowUpRight } from "lucide-react";

const navLinks = [
  { href: "/features", label: "Возможности" },
  { href: "/download", label: "Загрузки" },
  { href: "/about", label: "О платформе" },
];

export function PublicNav() {
  const pathname = usePathname();
  const [open, setOpen] = React.useState(false);
  const [scrolled, setScrolled] = React.useState(false);

  React.useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  React.useEffect(() => setOpen(false), [pathname]);

  return (
    <header className="fixed inset-x-0 top-0 z-50 px-3 pt-3 sm:px-6 sm:pt-4">
      <div
        className={`mx-auto flex max-w-6xl items-center justify-between rounded-full border px-3 py-2 transition-all duration-500 sm:px-4 ${
          scrolled || open
            ? "border-[#C9A25B]/20 bg-[#121811]/80 shadow-[0_20px_60px_-25px_rgba(0,0,0,0.8)] backdrop-blur-xl"
            : "border-transparent bg-transparent"
        }`}
      >
        <Link href="/" className="group flex items-center gap-2.5 pl-1" aria-label="KӨRKEM Flow — на главную">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/brand/korkem_mark.png"
            alt=""
            className="h-8 w-8 object-contain transition-transform duration-500 group-hover:rotate-[8deg] group-hover:scale-110"
          />
          <span className="font-display text-[15px] font-extrabold tracking-[0.08em] text-[#ECE5D3]">
            KӨRKEM
          </span>
          <span className="hidden rounded-full border border-[#C9A25B]/30 px-2 py-0.5 font-mono text-[9px] uppercase tracking-[0.22em] text-[#C9A25B] sm:inline">
            Flow
          </span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {navLinks.map((l) => {
            const active = pathname === l.href;
            return (
              <Link
                key={l.href}
                href={l.href}
                className={`rounded-full px-4 py-2 text-[13px] font-medium transition-colors ${
                  active ? "bg-white/[0.06] text-[#F7F5EE]" : "text-[#A8ADA4] hover:text-[#F7F5EE]"
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>

        <div className="hidden items-center gap-1.5 md:flex">
          <Link
            href="/login"
            className="rounded-full px-4 py-2 text-[13px] font-medium text-[#DEDAD0] transition hover:text-white"
          >
            Войти
          </Link>
          <Link
            href="/register"
            className="group inline-flex items-center gap-1.5 rounded-full bg-[#ECE5D3] py-2 pl-4 pr-3 text-[13px] font-semibold text-[#141B13] transition hover:bg-white"
          >
            Начать
            <ArrowUpRight className="h-3.5 w-3.5 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
          </Link>
        </div>

        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          aria-label={open ? "Закрыть меню" : "Открыть меню"}
          aria-expanded={open}
          className="inline-flex h-9 w-9 items-center justify-center rounded-full text-[#DEDAD0] hover:bg-white/5 md:hidden"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {open && (
        <div className="mx-auto mt-2 max-w-6xl rounded-3xl border border-[#C9A25B]/20 bg-[#121811]/95 p-3 backdrop-blur-xl md:hidden">
          <nav className="flex flex-col">
            {[{ href: "/", label: "Главная" }, ...navLinks].map((l) => (
              <Link
                key={l.href}
                href={l.href}
                className={`rounded-2xl px-4 py-3 text-[15px] font-medium ${
                  pathname === l.href ? "bg-white/[0.06] text-[#F7F5EE]" : "text-[#C9CCC4]"
                }`}
              >
                {l.label}
              </Link>
            ))}
          </nav>
          <div className="mt-2 grid grid-cols-2 gap-2 border-t border-white/5 pt-3">
            <Link
              href="/login"
              className="rounded-full border border-white/10 py-3 text-center text-sm font-medium text-[#DEDAD0]"
            >
              Войти
            </Link>
            <Link href="/register" className="rounded-full bg-[#ECE5D3] py-3 text-center text-sm font-semibold text-[#141B13]">
              Начать
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
