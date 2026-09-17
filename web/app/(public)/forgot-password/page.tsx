"use client";

import * as React from "react";
import Link from "next/link";
import { Layers, ArrowLeft, Mail, CheckCircle2, AlertCircle, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";

export default function ForgotPasswordPage() {
  const [email, setEmail] = React.useState("");
  const [loading, setLoading] = React.useState(false);
  const [submitted, setSubmitted] = React.useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email.trim()) return;

    setLoading(true);
    // Standard ERPNext password reset or notification
    try {
      await fetch("/api/method/frappe.core.doctype.user.user.reset_password", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ user: email.trim() }),
      });
    } catch {
      // Keep UI informative regardless to prevent email enumeration
    } finally {
      setLoading(false);
      setSubmitted(true);
    }
  }

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
            Восстановление пароля
          </h1>
          <p className="text-xs text-muted-foreground">
            Инструкции по сбросу пароля будут отправлены на ваш рабочий email
          </p>
        </div>

        <Card className="border-border/80 shadow-md">
          {submitted ? (
            <CardContent className="pt-6 text-center space-y-4">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600">
                <CheckCircle2 className="h-6 w-6" />
              </div>
              <h3 className="text-base font-semibold text-foreground">
                Проверьте входящие сообщения
              </h3>
              <p className="text-xs text-muted-foreground leading-relaxed">
                Если учетная запись с адресом <span className="font-medium text-foreground">{email}</span> существует в системе, вам направлена ссылка для установки нового пароля.
              </p>
              <div className="pt-2">
                <Button variant="outline" className="w-full gap-2 text-xs" asChild>
                  <Link href="/login">
                    <ArrowLeft className="h-4 w-4" />
                    <span>Вернуться к авторизации</span>
                  </Link>
                </Button>
              </div>
            </CardContent>
          ) : (
            <form onSubmit={handleSubmit}>
              <CardContent className="pt-6 space-y-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="email">
                    <Mail className="h-3.5 w-3.5 text-muted-foreground" />
                    Email аккаунта
                  </label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="ivanov@mebel.kz"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    disabled={loading}
                    required
                    autoFocus
                  />
                </div>
              </CardContent>

              <CardFooter className="flex flex-col gap-3">
                <Button type="submit" className="w-full gap-2 h-10" disabled={loading}>
                  {loading ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      <span>Отправка...</span>
                    </>
                  ) : (
                    <span>Отправить ссылку для сброса</span>
                  )}
                </Button>

                <Button variant="ghost" className="w-full gap-2 text-xs" asChild>
                  <Link href="/login">
                    <ArrowLeft className="h-3.5 w-3.5" />
                    <span>Вернуться ко входу</span>
                  </Link>
                </Button>
              </CardFooter>
            </form>
          )}
        </Card>
      </div>
    </div>
  );
}
