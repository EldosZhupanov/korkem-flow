"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Layers, ArrowRight, Loader2, AlertCircle, CheckCircle2, Building2, User, Mail, Lock, Phone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { korkemApi } from "@/lib/korkem-api";

export default function RegisterPage() {
  const router = useRouter();

  const [companyName, setCompanyName] = React.useState("");
  const [ownerName, setOwnerName] = React.useState("");
  const [email, setEmail] = React.useState("");
  const [phone, setPhone] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [confirmPassword, setConfirmPassword] = React.useState("");
  
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [success, setSuccess] = React.useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!companyName.trim() || !ownerName.trim() || !email.trim() || !password) {
      setError("Пожалуйста, заполните все обязательные поля");
      return;
    }

    if (password.length < 6) {
      setError("Пароль должен содержать не менее 6 символов");
      return;
    }

    if (password !== confirmPassword) {
      setError("Введенные пароли не совпадают");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      await korkemApi.register({
        company_name: companyName.trim(),
        owner_name: ownerName.trim(),
        email: email.trim(),
        password,
        phone: phone.trim() || undefined,
      });

      setSuccess(true);

      // Attempt automatic sign-in
      try {
        await korkemApi.login(email.trim(), password);
        router.push("/app");
      } catch {
        // Fallback to manual login navigation
        setTimeout(() => {
          router.push("/login");
        }, 2000);
      }
    } catch (err: any) {
      setError(
        err.message || "Не удалось завершить регистрацию. Возможно, указанный email уже занят."
      );
      setLoading(false);
    }
  }

  if (success) {
    return (
      <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center px-4 py-12">
        <Card className="w-full max-w-md border-border/80 text-center p-6 space-y-4 shadow-lg">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600">
            <CheckCircle2 className="h-8 w-8" />
          </div>
          <CardTitle className="text-xl">Компания успешно создана!</CardTitle>
          <CardDescription>
            Мы настраиваем изолированное рабочее пространство для компании «{companyName}»...
          </CardDescription>
          <div className="flex items-center justify-center gap-2 text-xs text-muted-foreground pt-2">
            <Loader2 className="h-4 w-4 animate-spin text-primary" />
            <span>Перенаправление в веб-кабинет...</span>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center px-4 py-12">
      <div className="w-full max-w-lg space-y-6">
        <div className="text-center space-y-2">
          <Link href="/" className="inline-flex items-center gap-2 mb-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm">
              <Layers className="h-5 w-5" />
            </div>
            <span className="text-2xl font-bold tracking-tight text-foreground">
              KORKEM
            </span>
          </Link>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">
            Регистрация мебельного производства
          </h1>
          <p className="text-xs text-muted-foreground">
            Создайте компанию и подключите сотрудников к платформе
          </p>
        </div>

        <Card className="border-border/80 shadow-md">
          <form onSubmit={handleSubmit}>
            <CardContent className="pt-6 space-y-4">
              {error && (
                <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-3 text-xs text-destructive">
                  <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                  <span>{error}</span>
                </div>
              )}

              {/* Company Name */}
              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="company">
                  <Building2 className="h-3.5 w-3.5 text-muted-foreground" />
                  Название компании или цеха *
                </label>
                <Input
                  id="company"
                  type="text"
                  placeholder="Например: Мебельная Фабрика «Престиж»"
                  value={companyName}
                  onChange={(e) => setCompanyName(e.target.value)}
                  disabled={loading}
                  required
                />
              </div>

              {/* Owner Name */}
              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="owner">
                  <User className="h-3.5 w-3.5 text-muted-foreground" />
                  ФИО руководителя *
                </label>
                <Input
                  id="owner"
                  type="text"
                  placeholder="Иванов Иван Иванович"
                  value={ownerName}
                  onChange={(e) => setOwnerName(e.target.value)}
                  disabled={loading}
                  required
                />
              </div>

              {/* Email & Phone Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="email">
                    <Mail className="h-3.5 w-3.5 text-muted-foreground" />
                    Рабочий Email *
                  </label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="director@mebel.kz"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="phone">
                    <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                    Телефон
                  </label>
                  <Input
                    id="phone"
                    type="tel"
                    placeholder="+7 (701) 000-00-00"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    disabled={loading}
                  />
                </div>
              </div>

              {/* Password Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="password">
                    <Lock className="h-3.5 w-3.5 text-muted-foreground" />
                    Пароль *
                  </label>
                  <Input
                    id="password"
                    type="password"
                    placeholder="Минимум 6 символов"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="confirmPassword">
                    <Lock className="h-3.5 w-3.5 text-muted-foreground" />
                    Повтор пароля *
                  </label>
                  <Input
                    id="confirmPassword"
                    type="password"
                    placeholder="Повторите пароль"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>
              </div>
            </CardContent>

            <CardFooter className="flex flex-col gap-4">
              <Button type="submit" className="w-full gap-2 h-10" disabled={loading}>
                {loading ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    <span>Создание компании...</span>
                  </>
                ) : (
                  <>
                    <span>Зарегистрировать компанию</span>
                    <ArrowRight className="h-4 w-4" />
                  </>
                )}
              </Button>

              <div className="text-center text-xs text-muted-foreground">
                Уже есть аккаунт?{" "}
                <Link href="/login" className="font-semibold text-primary hover:underline">
                  Войти в систему
                </Link>
              </div>
            </CardFooter>
          </form>
        </Card>
      </div>
    </div>
  );
}
