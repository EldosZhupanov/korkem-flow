"use client";

import * as React from "react";
import Link from "next/link";
import { 
  User, 
  Building2, 
  Mail, 
  ShieldCheck, 
  LogOut, 
  Smartphone, 
  Laptop, 
  KeyRound,
  CheckCircle2
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function ProfilePage() {
  const { user, company, logout } = useAuth();

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <PageHeader
        title="Профиль пользователя"
        description="Параметры вашей учетной записи и статус доступа к системе"
        breadcrumbs={[
          { label: "Обзор", href: "/app" },
          { label: "Профиль" },
        ]}
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* User Card */}
        <Card className="md:col-span-2 border-border/70 shadow-sm">
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="h-12 w-12 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-lg uppercase">
                {user ? user.charAt(0).toUpperCase() : "U"}
              </div>
              <div>
                <CardTitle className="text-base">{user || "Пользователь"}</CardTitle>
                <CardDescription>Учетная запись KORKEM ERP</CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent className="space-y-4 text-xs">
            <div className="space-y-3 pb-3 border-b">
              <div className="flex justify-between py-1">
                <span className="text-muted-foreground">Идентификатор входа:</span>
                <span className="font-semibold text-foreground">{user}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-muted-foreground">Активное предприятие:</span>
                <span className="font-semibold text-foreground">
                  {company?.company_name || "Мебельное производство"}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-muted-foreground">Роль в компании:</span>
                <Badge variant="outline" className="text-primary border-primary/30">
                  Владелец / Администратор
                </Badge>
              </div>
            </div>

            <div className="space-y-2 pt-1">
              <h4 className="font-semibold text-foreground flex items-center gap-1.5">
                <ShieldCheck className="h-4 w-4 text-emerald-600" />
                Безопасность сессии
              </h4>
              <p className="text-muted-foreground leading-relaxed">
                Ваша сессия защищена HTTP-only cookie через домен <code className="bg-muted px-1 py-0.5 rounded">korkem.asia</code>. Все запросы к складским остаткам и номенклатуре изолированы в рамках вашей компании.
              </p>
            </div>
          </CardContent>

          <CardFooter className="flex justify-between border-t border-border/40 py-4">
            <Button variant="outline" size="sm" asChild>
              <Link href="/forgot-password">
                <KeyRound className="h-3.5 w-3.5 mr-1.5" />
                Сменить пароль
              </Link>
            </Button>

            <Button
              variant="destructive"
              size="sm"
              onClick={() => logout()}
              className="gap-1.5"
            >
              <LogOut className="h-3.5 w-3.5" />
              <span>Выйти из аккаунта</span>
            </Button>
          </CardFooter>
        </Card>

        {/* Client apps reminder */}
        <div className="space-y-4">
          <Card className="border-border/70 shadow-sm bg-muted/20">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs font-semibold text-foreground">
                Приложения цеха
              </CardTitle>
              <CardDescription className="text-[11px]">
                Используйте ту же учетную запись на всех устройствах
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3 text-xs">
              <div className="flex items-center gap-2">
                <Smartphone className="h-4 w-4 text-emerald-600 shrink-0" />
                <span className="text-muted-foreground">Android APK (v0.3.0)</span>
              </div>
              <div className="flex items-center gap-2">
                <Laptop className="h-4 w-4 text-blue-600 shrink-0" />
                <span className="text-muted-foreground">Windows x64 Desktop (v0.3.0)</span>
              </div>
              <Button size="sm" variant="outline" className="w-full mt-2 text-xs" asChild>
                <Link href="/download">
                  Перейти к загрузкам
                </Link>
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
