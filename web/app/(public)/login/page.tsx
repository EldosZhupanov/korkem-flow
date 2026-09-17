"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Layers, ArrowRight, Loader2, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { korkemApi } from "@/lib/korkem-api";

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectPath = searchParams?.get("redirect") || "/app";

  const [username, setUsername] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!username.trim() || !password) {
      setError("Пожалуйста, заполните логин/email и пароль");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      await korkemApi.login(username.trim(), password);
      router.push(redirectPath);
    } catch (err: any) {
      setError(
        err.message || "Ошибка авторизации. Проверьте правильность логина и пароля."
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card className="border-border/80 shadow-md">
      <form onSubmit={handleSubmit}>
        <CardContent className="pt-6 space-y-4">
          {error && (
            <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-3 text-xs text-destructive">
              <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground" htmlFor="username">
              Логин или Email
            </label>
            <Input
              id="username"
              type="text"
              placeholder="master@korkem.asia или имя пользователя"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              disabled={loading}
              required
              autoFocus
            />
          </div>

          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <label className="text-xs font-medium text-foreground" htmlFor="password">
                Пароль
              </label>
              <Link
                href="/forgot-password"
                className="text-[11px] text-primary hover:underline"
              >
                Забыли пароль?
              </Link>
            </div>
            <Input
              id="password"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={loading}
              required
            />
          </div>
        </CardContent>

        <CardFooter className="flex flex-col gap-4">
          <Button type="submit" className="w-full gap-2 h-10" disabled={loading}>
            {loading ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                <span>Авторизация...</span>
              </>
            ) : (
              <>
                <span>Войти в систему</span>
                <ArrowRight className="h-4 w-4" />
              </>
            )}
          </Button>

          <div className="text-center text-xs text-muted-foreground">
            Еще нет аккаунта компании?{" "}
            <Link href="/register" className="font-semibold text-primary hover:underline">
              Зарегистрироваться
            </Link>
          </div>
        </CardFooter>
      </form>
    </Card>
  );
}

export default function LoginPage() {
  return (
    <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center px-4 py-12">
      <div className="w-full max-w-md space-y-6">
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
            Вход в систему
          </h1>
          <p className="text-xs text-muted-foreground">
            Введите логин или email вашей учетной записи
          </p>
        </div>

        <React.Suspense fallback={<div className="h-64 rounded-xl border bg-card animate-pulse" />}>
          <LoginForm />
        </React.Suspense>

        <p className="text-center text-[11px] text-muted-foreground">
          Защищенный протокол передачи данных. Сессионная изоляция ERPNext.
        </p>
      </div>
    </div>
  );
}
