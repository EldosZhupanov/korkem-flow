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
    <header className="sticky top-0 z-50 w-full border-b border-[#3D4A3B] bg-[#1B241A]/90 backdrop-blur-xl">
      <div className="container mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Official KORKEM Brand Logo */}
        <Link href="/" className="group flex items-center gap-3 transition">
          <div className="flex h-9 w-9 items-center justify-center overflow-hidden rounded-full border border-[#DEDAD0]/30 bg-[#070B07] transition-transform group-hover:scale-105">
            <img
              src="/brand/korkem_mark.png"
              alt="KORKEM"
              className="h-8 w-8 object-contain"
            />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-[15px] font-semibold tracking-tight text-[#E6E3D9]">
              KӨRKEM
            </span>
            <span className="font-mono text-[10px] uppercase tracking-[0.2em] text-[#A8ADA4]">
              Flow
            </span>
          </div>
        </Link>

        {/* Desktop Navigation */}
        <nav className="hidden md:flex items-center gap-1 text-[13px] font-medium">
          {navLinks.map((link) => {
            const isActive = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-full px-3.5 py-1.5 transition-colors ${
                  isActive
                    ? "bg-[#2B382A] text-[#DEDAD0] ring-1 ring-[#3D4A3B]"
                    : "text-[#A8ADA4] hover:text-[#E6E3D9]"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        {/* Desktop CTA actions */}
        <div className="hidden md:flex items-center gap-2.5">
          <Link
            href="/login"
            className="rounded-full px-3.5 py-1.5 text-[13px] font-medium text-[#E6E3D9] transition hover:text-white"
          >
            Войти
          </Link>
          <Link
            href="/register"
            className="inline-flex items-center gap-1.5 rounded-full bg-[#DEDAD0] px-4 py-1.5 text-[13px] font-semibold text-[#1B241A] transition hover:bg-[#F7F5EE]"
          >
            <span>Начать</span>
            <ArrowRight className="h-3.5 w-3.5" />
          </Link>
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
