"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";

const navLinks = [
  { href: "/features", label: "Возможности" },
  { href: "/download", label: "Загрузки" },
  { href: "/about", label: "О платформе" },
];

export function PublicNav() {
  const pathname = usePathname();
  const [mobileMenuOpen, setMobileMenuOpen] = React.useState(false);

  return (
    <header className="sticky top-0 z-50 w-full border-b border-white/10 bg-[#060911]/80 backdrop-blur-xl">
      <div className="container mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Brand Logo */}
        <Link href="/" className="group flex items-center gap-3 transition">
          <div className="relative flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-sky-400 to-blue-600 text-slate-950 shadow-[0_0_20px_-4px_rgba(14,165,233,0.6)] transition-transform group-hover:scale-105">
            <svg viewBox="0 0 24 24" className="h-5 w-5 fill-none stroke-current" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 4v16" />
              <path d="M18 4L9 12l9 8" />
              <circle cx="18" cy="4" r="1.4" className="fill-current stroke-none" />
            </svg>
          </div>
          <div className="flex flex-col leading-none">
            <span className="text-base font-extrabold tracking-tight text-white">
              KORKEM <span className="text-sky-400 font-semibold">Flow</span>
            </span>
            <span className="mt-0.5 font-mono text-[9px] font-medium uppercase tracking-[0.18em] text-slate-400">
              Manufacturing OS
            </span>
          </div>
        </Link>

        {/* Desktop Navigation */}
        <nav className="hidden md:flex items-center gap-1 text-sm font-medium">
          {navLinks.map((link) => {
            const isActive = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-md px-3.5 py-2 transition-colors ${
                  isActive
                    ? "text-primary bg-primary/5 font-semibold"
                    : "text-muted-foreground hover:text-foreground hover:bg-muted/50"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        {/* Desktop CTA actions */}
        <div className="hidden md:flex items-center gap-3">
          <Button variant="ghost" size="sm" asChild>
            <Link href="/login">Войти</Link>
          </Button>
          <Button size="sm" className="gap-1.5 shadow-sm" asChild>
            <Link href="/register">
              <span>Регистрация</span>
              <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </Button>
        </div>

        {/* Mobile menu trigger */}
        <button
          type="button"
          className="inline-flex md:hidden items-center justify-center rounded-md p-2 text-muted-foreground hover:bg-muted hover:text-foreground focus:outline-none"
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          aria-label="Toggle menu"
        >
          {mobileMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {/* Mobile Drawer / Dropdown */}
      {mobileMenuOpen && (
        <div className="md:hidden border-b border-border bg-background px-4 pt-2 pb-6 space-y-4 shadow-lg animate-in slide-in-from-top-2">
          <nav className="flex flex-col space-y-1">
            <Link
              href="/"
              onClick={() => setMobileMenuOpen(false)}
              className={`px-3 py-2.5 rounded-md text-sm font-medium ${
                pathname === "/" ? "bg-primary/10 text-primary font-semibold" : "text-foreground hover:bg-muted"
              }`}
            >
              Главная
            </Link>
            {navLinks.map((link) => {
              const isActive = pathname === link.href;
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={() => setMobileMenuOpen(false)}
                  className={`px-3 py-2.5 rounded-md text-sm font-medium ${
                    isActive ? "bg-primary/10 text-primary font-semibold" : "text-foreground hover:bg-muted"
                  }`}
                >
                  {link.label}
                </Link>
              );
            })}
          </nav>
          <div className="pt-3 border-t border-border flex flex-col gap-2.5">
            <Button variant="outline" className="w-full justify-center" asChild>
              <Link href="/login" onClick={() => setMobileMenuOpen(false)}>
                Войти в аккаунт
              </Link>
            </Button>
            <Button className="w-full justify-center gap-1.5" asChild>
              <Link href="/register" onClick={() => setMobileMenuOpen(false)}>
                Начать работу бесплатно
                <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
          </div>
        </div>
      )}
    </header>
  );
}
