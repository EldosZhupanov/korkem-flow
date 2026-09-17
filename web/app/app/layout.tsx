"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { 
  Layers, 
  LayoutDashboard, 
  Building2, 
  Boxes, 
  Users, 
  User, 
  LogOut, 
  Menu, 
  X, 
  Download, 
  ExternalLink,
  ChevronRight,
  ShieldCheck,
  Loader2
} from "lucide-react";
import { AuthProvider, useAuth } from "@/lib/auth-context";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

const navigation = [
  { name: "Обзор", href: "/app", icon: LayoutDashboard },
  { name: "Компания", href: "/app/company", icon: Building2 },
  { name: "Склады", href: "/app/warehouses", icon: Boxes },
  { name: "Команда", href: "/app/team", icon: Users },
  { name: "Профиль", href: "/app/profile", icon: User },
];

function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { user, company, loading, logout } = useAuth();
  const [sidebarOpen, setSidebarOpen] = React.useState(false);

  if (loading && !user) {
    return (
      <div className="flex h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <Layers className="h-6 w-6 animate-pulse" />
          </div>
          <div className="space-y-1">
            <h2 className="text-sm font-semibold text-foreground">Загрузка KORKEM Workspace...</h2>
            <p className="text-xs text-muted-foreground">Проверка сессии и параметров компании</p>
          </div>
          <Loader2 className="h-4 w-4 animate-spin text-muted-foreground mt-2" />
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-muted/20">
      {/* Mobile Backdrop */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 z-40 bg-background/80 backdrop-blur-sm md:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar Navigation */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-border bg-card transition-transform duration-200 ease-in-out md:static md:translate-x-0 ${
          sidebarOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        {/* Workspace Brand Header */}
        <div className="flex h-16 items-center justify-between border-b border-border/60 px-5">
          <Link href="/app" className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground shadow-sm">
              <Layers className="h-4 w-4" />
            </div>
            <div className="flex flex-col">
              <span className="text-sm font-bold tracking-tight text-foreground">KORKEM</span>
              <span className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Workspace</span>
            </div>
          </Link>
          <button
            type="button"
            className="md:hidden text-muted-foreground hover:text-foreground"
            onClick={() => setSidebarOpen(false)}
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Company Active Context Pill */}
        <div className="px-4 py-3 border-b border-border/40 bg-muted/30">
          <div className="text-[10px] uppercase font-semibold text-muted-foreground tracking-wider mb-1">
            Предприятие
          </div>
          <div className="flex items-center justify-between">
            <div className="truncate text-xs font-semibold text-foreground">
              {company?.company_name || "Мебельное производство"}
            </div>
            <Badge variant="outline" className="text-[10px] px-1.5 py-0 bg-emerald-500/10 text-emerald-600 border-emerald-300">
              Активно
            </Badge>
          </div>
        </div>

        {/* Nav Links */}
        <div className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
          {navigation.map((item) => {
            const isActive = pathname === item.href || (item.href !== "/app" && pathname.startsWith(item.href));
            const Icon = item.icon;
            return (
              <Link
                key={item.name}
                href={item.href}
                onClick={() => setSidebarOpen(false)}
                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-xs font-medium transition-colors ${
                  isActive
                    ? "bg-primary text-primary-foreground font-semibold shadow-sm"
                    : "text-muted-foreground hover:bg-muted hover:text-foreground"
                }`}
              >
                <Icon className="h-4 w-4 shrink-0" />
                <span className="flex-1">{item.name}</span>
                {isActive && <ChevronRight className="h-3 w-3 opacity-70" />}
              </Link>
            );
          })}

          <div className="pt-4 pb-1">
            <div className="px-3 text-[10px] uppercase font-semibold text-muted-foreground tracking-wider">
              Ресурсы
            </div>
          </div>

          <Link
            href="/download"
            className="flex items-center gap-3 rounded-lg px-3 py-2 text-xs font-medium text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          >
            <Download className="h-4 w-4 shrink-0" />
            <span>Центр загрузок</span>
          </Link>

          <Link
            href="/"
            className="flex items-center gap-3 rounded-lg px-3 py-2 text-xs font-medium text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          >
            <ExternalLink className="h-4 w-4 shrink-0" />
            <span>Сайт KORKEM</span>
          </Link>
        </div>

        {/* User Account / Footer */}
        <div className="border-t border-border/60 p-3 bg-card">
          <div className="flex items-center justify-between gap-2 p-2 rounded-lg bg-muted/40">
            <div className="flex items-center gap-2.5 overflow-hidden">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/20 text-primary font-bold text-xs">
                {user ? user.charAt(0).toUpperCase() : "U"}
              </div>
              <div className="truncate">
                <p className="truncate text-xs font-medium text-foreground">{user || "Пользователь"}</p>
                <p className="truncate text-[10px] text-muted-foreground">Владелец / Администратор</p>
              </div>
            </div>
            <button
              onClick={() => logout()}
              title="Выйти из системы"
              className="rounded p-1 text-muted-foreground hover:bg-destructive/10 hover:text-destructive transition-colors"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Container */}
      <div className="flex flex-1 flex-col overflow-x-hidden">
        {/* Top bar */}
        <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-border/60 bg-background/80 px-4 backdrop-blur-md sm:px-6 lg:px-8">
          <div className="flex items-center gap-3">
            <button
              type="button"
              className="md:hidden rounded-lg p-2 text-muted-foreground hover:bg-muted"
              onClick={() => setSidebarOpen(true)}
            >
              <Menu className="h-5 w-5" />
            </button>
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <span>Панель управления</span>
              <span>/</span>
              <span className="font-semibold text-foreground">
                {navigation.find((n) => n.href === pathname || (n.href !== "/app" && pathname.startsWith(n.href)))?.name || "Обзор"}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="hidden sm:flex items-center gap-1.5 text-xs text-muted-foreground border rounded-full px-3 py-1 bg-muted/30">
              <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
              <span>ERPNext Site: korkem.localhost</span>
            </div>
            <Button variant="outline" size="sm" className="text-xs gap-1.5" asChild>
              <Link href="/download">
                <Download className="h-3.5 w-3.5" />
                <span className="hidden sm:inline">Клиент цеха</span>
              </Link>
            </Button>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 p-4 sm:p-6 lg:p-8">
          {children}
        </main>
      </div>
    </div>
  );
}

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <AppShell>{children}</AppShell>
    </AuthProvider>
  );
}
