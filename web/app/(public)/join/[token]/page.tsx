"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { 
  Building2, 
  UserCheck, 
  ShieldAlert, 
  Download, 
  Smartphone, 
  Apple, 
  CheckCircle2, 
  Copy, 
  Check, 
  ArrowRight, 
  Loader2, 
  Layers,
  Phone,
  User,
  ExternalLink
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { korkemApi } from "@/lib/korkem-api";

export default function JoinCompanyPage() {
  const params = useParams();
  const router = useRouter();
  const token = typeof params.token === "string" ? params.token : Array.isArray(params.token) ? params.token[0] : "";

  const [loading, setLoading] = React.useState(true);
  const [inviteInfo, setInviteInfo] = React.useState<any>(null);
  const [error, setError] = React.useState<string | null>(null);

  // Acceptance form state
  const [phone, setPhone] = React.useState("+7 ");
  const [fullName, setFullName] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);
  const [submitError, setSubmitError] = React.useState<string | null>(null);
  const [success, setSuccess] = React.useState(false);
  const [acceptedRole, setAcceptedRole] = React.useState("");

  // Copy code feedback
  const [copied, setCopied] = React.useState(false);

  React.useEffect(() => {
    if (!token) {
      setError("Токен приглашения отсутствует");
      setLoading(false);
      return;
    }

    async function load() {
      try {
        setLoading(true);
        setError(null);
        const info = await korkemApi.getInvitationInfo(token);
        if (!info.valid) {
          setError(info.error || "Приглашение недействительно или устарело");
        } else {
          setInviteInfo(info);
          if (info.phone) {
            setPhone(info.phone);
          }
        }
      } catch (err: any) {
        setError(err.message || "Не удалось загрузить данные приглашения");
      } finally {
        setLoading(false);
      }
    }

    load();
  }, [token]);

  function handlePhoneChange(e: React.ChangeEvent<HTMLInputElement>) {
    let val = e.target.value;
    if (!val.startsWith("+7")) {
      val = "+7 " + val.replace(/^\+?7?/, "");
    }
    setPhone(val);
  }

  async function handleAccept(e: React.FormEvent) {
    e.preventDefault();
    if (!phone.trim() || phone.trim() === "+7") {
      setSubmitError("Введите номер телефона");
      return;
    }
    if (!fullName.trim()) {
      setSubmitError("Введите ваше имя и фамилию");
      return;
    }

    setSubmitting(true);
    setSubmitError(null);

    try {
      const res = await korkemApi.acceptInvitation({
        token,
        phone: phone.trim(),
        full_name: fullName.trim(),
      });

      setAcceptedRole(res.role_title_ru);
      setSuccess(true);

      // Redirect after short delay
      setTimeout(() => {
        router.push(res.landing_route || "/app");
      }, 2500);
    } catch (err: any) {
      setSubmitError(err.message || "Не удалось принять приглашение");
    } finally {
      setSubmitting(false);
    }
  }

  function copyCode() {
    if (inviteInfo?.short_code) {
      navigator.clipboard.writeText(inviteInfo.short_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  }

  // Get initials for avatar fallback
  const initials = inviteInfo?.company_name
    ? inviteInfo.company_name
        .split(" ")
        .map((p: string) => p[0])
        .slice(0, 2)
        .join("")
        .toUpperCase()
    : "KM";

  if (loading) {
    return (
      <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center p-4">
        <div className="flex flex-col items-center gap-3 text-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
          <p className="text-sm text-muted-foreground">Проверка приглашения в мебельный цех...</p>
        </div>
      </div>
    );
  }

  if (error || !inviteInfo) {
    return (
      <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center p-4">
        <Card className="w-full max-w-md border-border/80 text-center p-6 space-y-4 shadow-lg">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-destructive/10 text-destructive">
            <ShieldAlert className="h-8 w-8" />
          </div>
          <CardTitle className="text-xl">Приглашение недействительно</CardTitle>
          <CardDescription className="text-sm">
            {error || "Ссылка устарела, была отозвана или уже использована."}
          </CardDescription>
          <CardFooter className="flex flex-col gap-2 pt-4 px-0">
            <Button asChild className="w-full">
              <Link href="/">Перейти на главную KORKEM Flow</Link>
            </Button>
            <Button asChild variant="outline" className="w-full">
              <Link href="/login">Войти в существующий аккаунт</Link>
            </Button>
          </CardFooter>
        </Card>
      </div>
    );
  }

  if (success) {
    return (
      <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center p-4">
        <Card className="w-full max-w-md border-border/80 text-center p-6 space-y-4 shadow-lg">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600">
            <CheckCircle2 className="h-8 w-8" />
          </div>
          <CardTitle className="text-xl">Добро пожаловать в команду!</CardTitle>
          <CardDescription className="text-sm">
            Вы успешно присоединились к компании «{inviteInfo.company_name}» в роли «{acceptedRole}».
          </CardDescription>
          <div className="flex items-center justify-center gap-2 text-xs text-muted-foreground pt-4">
            <Loader2 className="h-4 w-4 animate-spin text-primary" />
            <span>Перенаправление на ваш рабочий участок...</span>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center px-4 py-8">
      <div className="w-full max-w-lg space-y-6">
        {/* Header Branding */}
        <div className="text-center space-y-2">
          <Link href="/" className="inline-flex items-center gap-2 mb-1">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm">
              <Layers className="h-5 w-5" />
            </div>
            <span className="font-bold text-xl tracking-tight">KORKEM Flow</span>
          </Link>
          <h1 className="text-2xl font-bold tracking-tight">Приглашение в цех</h1>
          <p className="text-sm text-muted-foreground">
            Вас пригласили присоединиться к производственному рабочему пространству
          </p>
        </div>

        {/* Workshop Details Card */}
        <Card className="border-border/80 shadow-md overflow-hidden">
          <div className="bg-primary/5 p-6 border-b border-border/40 flex items-center gap-4">
            {inviteInfo.company_logo ? (
              <img
                src={inviteInfo.company_logo}
                alt={inviteInfo.company_name}
                className="h-16 w-16 rounded-2xl object-cover border bg-background"
              />
            ) : (
              <div className="h-16 w-16 rounded-2xl bg-primary text-primary-foreground font-bold text-xl flex items-center justify-center shadow-inner">
                {initials}
              </div>
            )}
            <div className="space-y-1">
              <div className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                Мебельное производство
              </div>
              <div className="font-bold text-lg leading-snug">{inviteInfo.company_name}</div>
              <div className="text-xs text-muted-foreground">
                Пригласил: <span className="font-medium text-foreground">{inviteInfo.invited_by}</span>
              </div>
            </div>
          </div>

          <CardContent className="p-6 space-y-5">
            {/* Role highlight */}
            <div className="rounded-xl border border-primary/20 bg-primary/5 p-4 space-y-1.5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium text-muted-foreground">Ваша должность:</span>
                <Badge variant="default" className="font-semibold">
                  {inviteInfo.role_title_ru}
                </Badge>
              </div>
              {inviteInfo.desc_ru && (
                <p className="text-xs text-muted-foreground leading-relaxed pt-1">
                  {inviteInfo.desc_ru}
                </p>
              )}
            </div>

            {/* Direct Join Form */}
            <form onSubmit={handleAccept} className="space-y-4">
              <div className="space-y-2">
                <label className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                  Номер телефона (Казахстан)
                </label>
                <Input
                  type="tel"
                  value={phone}
                  onChange={handlePhoneChange}
                  placeholder="+7 (701) 000-00-00"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <User className="h-3.5 w-3.5 text-muted-foreground" />
                  Ваше имя и фамилия
                </label>
                <Input
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="Асқар Серіков"
                  required
                />
              </div>

              {submitError && (
                <div className="rounded-md bg-destructive/10 border border-destructive/20 p-3 text-xs text-destructive">
                  {submitError}
                </div>
              )}

              <Button type="submit" className="w-full gap-2 text-sm font-semibold" disabled={submitting}>
                {submitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Подключение к цеху...
                  </>
                ) : (
                  <>
                    <UserCheck className="h-4 w-4" />
                    Принять приглашение и начать
                  </>
                )}
              </Button>
            </form>

            {/* Quick deep link or APK app install options */}
            <div className="border-t border-border/60 pt-4 space-y-3">
              <div className="text-xs font-medium text-muted-foreground text-center">
                Или откройте в мобильном приложении KORKEM Flow:
              </div>

              <div className="grid grid-cols-2 gap-2">
                <Button asChild variant="outline" size="sm" className="gap-1.5 text-xs">
                  <Link href={`korkem://join/${token}`}>
                    <Smartphone className="h-3.5 w-3.5" />
                    Открыть в приложении
                  </Link>
                </Button>

                <Button asChild variant="outline" size="sm" className="gap-1.5 text-xs">
                  <Link href="/download">
                    <Download className="h-3.5 w-3.5" />
                    Скачать APK
                  </Link>
                </Button>
              </div>

              {/* Short code fallback */}
              {inviteInfo.short_code && (
                <div className="flex items-center justify-between bg-muted/40 rounded-lg p-2.5 text-xs border">
                  <span className="text-muted-foreground">Код для ручного ввода:</span>
                  <div className="flex items-center gap-2">
                    <code className="font-mono font-bold tracking-widest text-primary">
                      {inviteInfo.short_code}
                    </code>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      className="h-6 w-6"
                      onClick={copyCode}
                    >
                      {copied ? <Check className="h-3.5 w-3.5 text-emerald-600" /> : <Copy className="h-3.5 w-3.5" />}
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
