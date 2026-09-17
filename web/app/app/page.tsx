"use client";

import * as React from "react";
import Link from "next/link";
import { 
  Building2, 
  Boxes, 
  Users, 
  Smartphone, 
  Laptop, 
  ArrowRight, 
  CheckCircle2, 
  AlertCircle, 
  ShieldCheck, 
  Plus, 
  Sparkles, 
  Package,
  Layers
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { korkemApi, type Warehouse, type StaffMember } from "@/lib/korkem-api";

export default function DashboardPage() {
  const { user, company, loading: authLoading } = useAuth();
  const [warehouses, setWarehouses] = React.useState<Warehouse[]>([]);
  const [staff, setStaff] = React.useState<StaffMember[]>([]);
  const [loadingData, setLoadingData] = React.useState(true);

  React.useEffect(() => {
    async function loadData() {
      try {
        const [wList, sList] = await Promise.allSettled([
          korkemApi.getWarehouses(),
          korkemApi.getStaffMembers(),
        ]);
        if (wList.status === "fulfilled") setWarehouses(wList.value);
        if (sList.status === "fulfilled") setStaff(sList.value);
      } catch (err) {
        console.warn("Failed to load dashboard data:", err);
      } finally {
        setLoadingData(false);
      }
    }

    if (user) {
      loadData();
    }
  }, [user]);

  const defaultWarehouse = warehouses.find((w) => w.is_shipping_default) || warehouses[0];

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      {/* Page Header */}
      <PageHeader
        title={`Здравствуйте${company?.owner_name ? `, ${company.owner_name}` : ""}!`}
        description={`Управление производством: ${company?.company_name || "Загрузка компании..."}`}
        action={
          <div className="flex gap-2.5">
            <Button variant="outline" size="sm" asChild>
              <Link href="/download" className="gap-1.5">
                <Smartphone className="h-3.5 w-3.5" />
                <span>Приложения</span>
              </Link>
            </Button>
            <Button size="sm" asChild>
              <Link href="/app/warehouses" className="gap-1.5">
                <Plus className="h-3.5 w-3.5" />
                <span>Склады</span>
              </Link>
            </Button>
          </div>
        }
      />

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Company */}
        <Card className="border-border/60 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Компания
            </CardTitle>
            <Building2 className="h-4 w-4 text-primary" />
          </CardHeader>
          <CardContent>
            <div className="text-lg font-bold text-foreground truncate">
              {company?.company_name || "—"}
            </div>
            <p className="text-[11px] text-muted-foreground mt-1 flex items-center gap-1">
              <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
              <span>Мультитенантная изоляция</span>
            </p>
          </CardContent>
        </Card>

        {/* Card 2: Warehouses */}
        <Card className="border-border/60 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Склады цеха
            </CardTitle>
            <Boxes className="h-4 w-4 text-amber-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {loadingData ? "..." : warehouses.length}
            </div>
            <p className="text-[11px] text-muted-foreground mt-1 truncate">
              По умолчанию: {defaultWarehouse ? defaultWarehouse.name : "Не назначен"}
            </p>
          </CardContent>
        </Card>

        {/* Card 3: Team */}
        <Card className="border-border/60 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Команда
            </CardTitle>
            <Users className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {loadingData ? "..." : staff.length || 1}
            </div>
            <p className="text-[11px] text-muted-foreground mt-1">
              {staff.filter(s => s.status === "Active" || s.enabled).length || 1} активных сотрудников
            </p>
          </CardContent>
        </Card>

        {/* Card 4: ERP Engine */}
        <Card className="border-border/60 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              ERPNext Core
            </CardTitle>
            <Layers className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-base font-bold text-foreground">Онлайн 2026</span>
            </div>
            <p className="text-[11px] text-muted-foreground mt-1">
              Синхронизация v0.3.0
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Onboarding / Setup Steps */}
      <div className="rounded-2xl border border-border/70 bg-card p-6 shadow-sm space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <Sparkles className="h-5 w-5 text-primary" />
            <div>
              <h3 className="text-base font-bold text-foreground">Настройка производства KORKEM</h3>
              <p className="text-xs text-muted-foreground">Шаги для полноценного запуска цифрового конвейера цеха</p>
            </div>
          </div>
          <Badge variant="secondary" className="text-xs">Начальный этап</Badge>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-2">
          {/* Step 1 */}
          <Link 
            href="/app/company" 
            className="group block rounded-xl border border-border/60 bg-muted/20 p-4 hover:border-primary/50 hover:bg-muted/40 transition-colors"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2 text-xs font-bold text-foreground group-hover:text-primary">
                <Building2 className="h-4 w-4" />
                <span>1. Реквизиты компании</span>
              </div>
              <ArrowRight className="h-3.5 w-3.5 text-muted-foreground group-hover:translate-x-1 transition-transform" />
            </div>
            <p className="text-xs text-muted-foreground">
              Заполните адрес производства, контакты и банковские реквизиты для договоров.
            </p>
          </Link>

          {/* Step 2 */}
          <Link 
            href="/app/warehouses" 
            className="group block rounded-xl border border-border/60 bg-muted/20 p-4 hover:border-primary/50 hover:bg-muted/40 transition-colors"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2 text-xs font-bold text-foreground group-hover:text-primary">
                <Boxes className="h-4 w-4" />
                <span>2. Структура складов</span>
              </div>
              <ArrowRight className="h-3.5 w-3.5 text-muted-foreground group-hover:translate-x-1 transition-transform" />
            </div>
            <p className="text-xs text-muted-foreground">
              Создайте склады плит (ЛДСП/МДФ), фурнитуры и склад отгрузки готовой мебели.
            </p>
          </Link>

          {/* Step 3 */}
          <Link 
            href="/app/team" 
            className="group block rounded-xl border border-border/60 bg-muted/20 p-4 hover:border-primary/50 hover:bg-muted/40 transition-colors"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2 text-xs font-bold text-foreground group-hover:text-primary">
                <Users className="h-4 w-4" />
                <span>3. Доступ для сотрудников</span>
              </div>
              <ArrowRight className="h-3.5 w-3.5 text-muted-foreground group-hover:translate-x-1 transition-transform" />
            </div>
            <p className="text-xs text-muted-foreground">
              Отправьте приглашения технологам, конструкторам и мастерам производственной смены.
            </p>
          </Link>
        </div>
      </div>

      {/* Quick Launch Ecosystem Platforms */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Mobile Setup Card */}
        <div className="rounded-2xl border border-border/60 bg-card p-6 shadow-sm space-y-3">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
              <Smartphone className="h-5 w-5" />
            </div>
            <div>
              <h4 className="text-base font-bold text-foreground">Приложение для мастеров и замерщиков</h4>
              <p className="text-xs text-muted-foreground">Android APK (v0.3.0 Universal)</p>
            </div>
          </div>
          <p className="text-xs text-muted-foreground leading-relaxed">
            Установите приложение на смартфоны сотрудников цеха для сканирования деталей со штрихкодами, фиксации статусов и замеров на объекте.
          </p>
          <div className="pt-2 flex items-center gap-3">
            <Button size="sm" variant="outline" asChild>
              <a href="/files/korkem-flow.apk" download="korkem-flow.apk">
                Скачать APK (68 МБ)
              </a>
            </Button>
            <Link href="/download" className="text-xs text-primary hover:underline">
              Инструкция по установке →
            </Link>
          </div>
        </div>

        {/* Desktop Setup Card */}
        <div className="rounded-2xl border border-border/60 bg-card p-6 shadow-sm space-y-3">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-blue-500/10 text-blue-600 flex items-center justify-center">
              <Laptop className="h-5 w-5" />
            </div>
            <div>
              <h4 className="text-base font-bold text-foreground">Десктоп для технологов и ЧПУ</h4>
              <p className="text-xs text-muted-foreground">Windows x64 Portable (v0.3.0)</p>
            </div>
          </div>
          <p className="text-xs text-muted-foreground leading-relaxed">
            Рабочее место для конструктора и оператора форматно-раскроечного центра: быстрый 2D-раскрой плит и выгрузка G-code.
          </p>
          <div className="pt-2 flex items-center gap-3">
            <Button size="sm" variant="outline" asChild>
              <a href="/files/korkem-flow-windows-x64.zip" download="korkem-flow-windows-x64.zip">
                Скачать ZIP (30.6 МБ)
              </a>
            </Button>
            <Link href="/download" className="text-xs text-primary hover:underline">
              Инструкция по установке →
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
