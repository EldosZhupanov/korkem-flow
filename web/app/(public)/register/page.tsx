"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { 
  Layers, 
  ArrowRight, 
  Loader2, 
  AlertCircle, 
  CheckCircle2, 
  Building2, 
  User, 
  Mail, 
  Lock, 
  Phone,
  Upload,
  UserPlus,
  PlusCircle,
  LayoutDashboard,
  ShieldCheck,
  Check
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { korkemApi } from "@/lib/korkem-api";

export default function RegisterPage() {
  const router = useRouter();

  // Mode: 'create' | 'join'
  const [activeTab, setActiveTab] = React.useState<"create" | "join">("create");

  // Step in owner flow (1: Phone & OTP, 2: Profile, 3: Company & Logo, 4: Success)
  const [ownerStep, setOwnerStep] = React.useState<1 | 2 | 3 | 4>(1);

  // Form Fields
  const [phone, setPhone] = React.useState("+7 ");
  const [otpCode, setOtpCode] = React.useState("");
  const [otpSent, setOtpSent] = React.useState(false);
  const [otpVerified, setOtpVerified] = React.useState(false);
  const [sessionId, setSessionId] = React.useState("");

  const [ownerName, setOwnerName] = React.useState("");
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");

  const [companyName, setCompanyName] = React.useState("");
  const [logoPreview, setLogoPreview] = React.useState<string | null>(null);

  // Join by code field
  const [joinCodeOrUrl, setJoinCodeOrUrl] = React.useState("");

  // Loading & Feedback
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [successData, setSuccessData] = React.useState<any>(null);

  // Format phone
  function handlePhoneChange(e: React.ChangeEvent<HTMLInputElement>) {
    let val = e.target.value;
    if (!val.startsWith("+7")) {
      val = "+7 " + val.replace(/^\+?7?/, "");
    }
    setPhone(val);
  }

  // Handle Logo Upload
  function handleLogoUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      setLogoPreview(reader.result as string);
    };
    reader.readAsDataURL(file);
  }

  // Step 1: Send OTP
  async function handleSendOtp() {
    if (!phone.trim() || phone.trim() === "+7") {
      setError("Укажите номер телефона в формате +7 (7XX) XXX-XX-XX");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await korkemApi.requestOtp(phone.trim());
      setSessionId(res.session_id);
      setOtpSent(true);
      if (res.dev_code) {
        setOtpCode(res.dev_code);
      }
    } catch (err: any) {
      setError(err.message || "Не удалось отправить код подтверждения");
    } finally {
      setLoading(false);
    }
  }

  // Step 1: Verify OTP
  async function handleVerifyOtp() {
    if (!otpCode.trim()) {
      setError("Введите 4-значный код из SMS");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await korkemApi.verifyOtp(phone.trim(), otpCode.trim(), sessionId);
      if (res.verified) {
        setOtpVerified(true);
        setOwnerStep(2); // Advance to personal profile
      }
    } catch (err: any) {
      setError(err.message || "Неверный код подтверждения");
    } finally {
      setLoading(false);
    }
  }

  // Step 2 -> Step 3
  function handleProfileNext(e: React.FormEvent) {
    e.preventDefault();
    if (!ownerName.trim()) {
      setError("Укажите ваше имя и фамилию");
      return;
    }
    setError(null);
    setOwnerStep(3); // Advance to company name & logo
  }

  // Step 3: Complete Registration
  async function handleFinishRegistration(e: React.FormEvent) {
    e.preventDefault();
    if (!companyName.trim()) {
      setError("Укажите название вашего цеха или компании");
      return;
    }
    setLoading(true);
    setError(null);

    try {
      const res = await korkemApi.register({
        company_name: companyName.trim(),
        owner_name: ownerName.trim(),
        email: email.trim() || undefined as any,
        password: password || "KorkemPilot2026!",
        phone: phone.trim(),
      });

      setSuccessData(res);
      setOwnerStep(4); // Success step

      // Automatically sign in
      try {
        await korkemApi.login(res.email || email.trim(), password || "KorkemPilot2026!");
      } catch {
        // Continue
      }
    } catch (err: any) {
      setError(err.message || "Не удалось завершить создание компании");
    } finally {
      setLoading(false);
    }
  }

  // Path B: Join by Code / Link
  function handleJoinSubmit(e: React.FormEvent) {
    e.preventDefault();
    const raw = joinCodeOrUrl.trim();
    if (!raw) return;

    let targetToken = raw;
    if (raw.includes("/join/")) {
      targetToken = raw.split("/join/")[1].split("?")[0].split("#")[0];
    }
    router.push(`/join/${encodeURIComponent(targetToken)}`);
  }

  // Computed initials
  const initials = companyName
    ? companyName
        .split(" ")
        .map((p) => p[0])
        .slice(0, 2)
        .join("")
        .toUpperCase()
    : "KM";

  return (
    <div className="flex min-h-[calc(100vh-16rem)] items-center justify-center px-4 py-8">
      <div className="w-full max-w-lg space-y-6">
        {/* Header */}
        <div className="text-center space-y-2">
          <Link href="/" className="inline-flex items-center gap-2 mb-1">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm">
              <Layers className="h-5 w-5" />
            </div>
            <span className="font-bold text-xl tracking-tight">KORKEM Flow</span>
          </Link>
          <h1 className="text-2xl font-bold tracking-tight">Вход и регистрация</h1>
          <p className="text-xs text-muted-foreground">
            Операционная система для мебельных производств Казахстана
          </p>
        </div>

        {/* 2 Paths Tab Selector (Only if not already finished) */}
        {ownerStep !== 4 && (
          <Tabs value={activeTab} onValueChange={(val: any) => { setActiveTab(val); setError(null); }}>
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="create" className="text-xs font-medium">
                Создать компанию
              </TabsTrigger>
              <TabsTrigger value="join" className="text-xs font-medium">
                Присоединиться по ссылке
              </TabsTrigger>
            </TabsList>

            {/* Path A: Create Company (Owner) */}
            <TabsContent value="create" className="space-y-4 pt-2">
              <Card className="border-border/80 shadow-md">
                <CardHeader className="pb-3">
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-base font-semibold">
                      {ownerStep === 1 && "Шаг 1: Номер телефона"}
                      {ownerStep === 2 && "Шаг 2: Профиль владельца"}
                      {ownerStep === 3 && "Шаг 3: Название цеха"}
                    </CardTitle>
                    <Badge variant="outline" className="text-xs">
                      Шаг {ownerStep} из 3
                    </Badge>
                  </div>
                  <CardDescription className="text-xs">
                    {ownerStep === 1 && "Быстрое подтверждение по SMS без лишних паролей"}
                    {ownerStep === 2 && "Как к вам обращаться в системе и отчетах"}
                    {ownerStep === 3 && "Название производства для документов и сотрудников"}
                  </CardDescription>
                </CardHeader>

                <CardContent className="space-y-4">
                  {error && (
                    <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-3 text-xs text-destructive">
                      <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                      <span>{error}</span>
                    </div>
                  )}

                  {/* STEP 1: Phone + OTP */}
                  {ownerStep === 1 && (
                    <div className="space-y-3">
                      <div className="space-y-1.5">
                        <label className="text-xs font-medium text-foreground flex items-center gap-1.5">
                          <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                          Номер телефона (+7)
                        </label>
                        <div className="flex gap-2">
                          <Input
                            type="tel"
                            placeholder="+7 (701) 000-00-00"
                            value={phone}
                            onChange={handlePhoneChange}
                            disabled={otpSent || loading}
                          />
                          {!otpSent && (
                            <Button type="button" onClick={handleSendOtp} disabled={loading} size="sm">
                              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : "Получить код"}
                            </Button>
                          )}
                        </div>
                      </div>

                      {otpSent && (
                        <div className="space-y-2 pt-2 border-t">
                          <label className="text-xs font-medium text-foreground flex items-center justify-between">
                            <span>Код из SMS:</span>
                            <button
                              type="button"
                              onClick={() => { setOtpSent(false); setOtpCode(""); }}
                              className="text-xs text-primary underline"
                            >
                              Изменить номер
                            </button>
                          </label>
                          <div className="flex gap-2">
                            <Input
                              type="text"
                              maxLength={6}
                              placeholder="1234"
                              value={otpCode}
                              onChange={(e) => setOtpCode(e.target.value)}
                              className="font-mono text-center tracking-widest text-lg font-bold"
                            />
                            <Button type="button" onClick={handleVerifyOtp} disabled={loading} size="sm">
                              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : "Подтвердить"}
                            </Button>
                          </div>
                        </div>
                      )}
                    </div>
                  )}

                  {/* STEP 2: Profile */}
                  {ownerStep === 2 && (
                    <form onSubmit={handleProfileNext} className="space-y-3">
                      <div className="space-y-1.5">
                        <label className="text-xs font-medium text-foreground flex items-center gap-1.5">
                          <User className="h-3.5 w-3.5 text-muted-foreground" />
                          Ваше имя и фамилия *
                        </label>
                        <Input
                          type="text"
                          placeholder="Например: Аслан Ахметов"
                          value={ownerName}
                          onChange={(e) => setOwnerName(e.target.value)}
                          required
                        />
                      </div>

                      <div className="space-y-1.5">
                        <div className="flex items-center justify-between">
                          <label className="text-xs font-medium text-foreground flex items-center gap-1.5">
                            <Mail className="h-3.5 w-3.5 text-muted-foreground" />
                            Email
                          </label>
                          <span className="text-[10px] text-muted-foreground">Необязательно</span>
                        </div>
                        <Input
                          type="email"
                          placeholder="owner@example.com (опционально)"
                          value={email}
                          onChange={(e) => setEmail(e.target.value)}
                        />
                      </div>

                      <div className="space-y-1.5">
                        <div className="flex items-center justify-between">
                          <label className="text-xs font-medium text-foreground flex items-center gap-1.5">
                            <Lock className="h-3.5 w-3.5 text-muted-foreground" />
                            Пароль для входа
                          </label>
                          <span className="text-[10px] text-muted-foreground">Не менее 6 символов</span>
                        </div>
                        <Input
                          type="password"
                          placeholder="••••••••"
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                        />
                      </div>

                      <div className="flex gap-2 pt-2">
                        <Button type="button" variant="outline" onClick={() => setOwnerStep(1)} className="w-1/3">
                          Назад
                        </Button>
                        <Button type="submit" className="w-2/3 gap-1">
                          Далее <ArrowRight className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </form>
                  )}

                  {/* STEP 3: Company & Logo */}
                  {ownerStep === 3 && (
                    <form onSubmit={handleFinishRegistration} className="space-y-4">
                      <div className="space-y-1.5">
                        <label className="text-xs font-medium text-foreground flex items-center gap-1.5">
                          <Building2 className="h-3.5 w-3.5 text-muted-foreground" />
                          Название компании или цеха *
                        </label>
                        <Input
                          type="text"
                          placeholder="Например: Престиж Мебель"
                          value={companyName}
                          onChange={(e) => setCompanyName(e.target.value)}
                          required
                        />
                      </div>

                      {/* Logo or Initials Fallback */}
                      <div className="space-y-2">
                        <div className="flex items-center justify-between">
                          <span className="text-xs font-medium text-foreground">Логотип мастерской:</span>
                          <span className="text-[10px] text-muted-foreground">Можно пропустить</span>
                        </div>
                        <div className="flex items-center gap-4 p-3 rounded-xl border bg-muted/20">
                          {logoPreview ? (
                            <img
                              src={logoPreview}
                              alt="Logo"
                              className="h-14 w-14 rounded-xl object-cover border bg-background"
                            />
                          ) : (
                            <div className="h-14 w-14 rounded-xl bg-primary text-primary-foreground font-bold text-lg flex items-center justify-center shadow-inner">
                              {initials}
                            </div>
                          )}
                          <div className="space-y-1 flex-1">
                            <label className="cursor-pointer inline-flex items-center gap-1.5 text-xs font-semibold text-primary hover:underline">
                              <Upload className="h-3.5 w-3.5" />
                              Загрузить изображение
                              <input
                                type="file"
                                accept="image/png, image/jpeg, image/webp"
                                className="hidden"
                                onChange={handleLogoUpload}
                              />
                            </label>
                            <p className="text-[11px] text-muted-foreground">
                              PNG, JPG или авто-инициалы «{initials}»
                            </p>
                          </div>
                        </div>
                      </div>

                      <div className="rounded-lg bg-muted/40 p-3 text-xs text-muted-foreground space-y-1">
                        <div className="flex items-center gap-1.5 font-medium text-foreground">
                          <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
                          Роль: Владелец цеха (Owner)
                        </div>
                        <p className="text-[11px]">
                          БИН, реквизиты банка и адреса можно настроить позже в удобное время.
                        </p>
                      </div>

                      <div className="flex gap-2 pt-2">
                        <Button type="button" variant="outline" onClick={() => setOwnerStep(2)} className="w-1/3">
                          Назад
                        </Button>
                        <Button type="submit" disabled={loading} className="w-2/3 gap-1">
                          {loading ? (
                            <>
                              <Loader2 className="h-4 w-4 animate-spin" />
                              Создание...
                            </>
                          ) : (
                            <>
                              Создать цех <Check className="h-3.5 w-3.5" />
                            </>
                          )}
                        </Button>
                      </div>
                    </form>
                  )}
                </CardContent>
              </Card>
            </TabsContent>

            {/* Path B: Join by Invite Code */}
            <TabsContent value="join" className="space-y-4 pt-2">
              <Card className="border-border/80 shadow-md">
                <CardHeader className="pb-3">
                  <CardTitle className="text-base font-semibold">Присоединиться к цеху</CardTitle>
                  <CardDescription className="text-xs">
                    Если вам прислали ссылку в WhatsApp / Telegram или короткий код приглашения
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <form onSubmit={handleJoinSubmit} className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-xs font-medium text-foreground">
                        Ссылка приглашения или короткий код:
                      </label>
                      <Input
                        type="text"
                        placeholder="https://korkem.asia/join/... или код"
                        value={joinCodeOrUrl}
                        onChange={(e) => setJoinCodeOrUrl(e.target.value)}
                        required
                      />
                    </div>
                    <Button type="submit" className="w-full gap-1.5">
                      Перейти к приглашению <ArrowRight className="h-3.5 w-3.5" />
                    </Button>
                  </form>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        )}

        {/* STEP 4: Success Screen */}
        {ownerStep === 4 && (
          <Card className="border-border/80 text-center p-6 space-y-5 shadow-lg">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600">
              <CheckCircle2 className="h-8 w-8" />
            </div>
            <div className="space-y-1">
              <CardTitle className="text-xl">Компания «{companyName}» создана!</CardTitle>
              <CardDescription className="text-xs">
                Рабочее пространство настроено. Вы можете сразу пригласить мастеров или начать первый заказ.
              </CardDescription>
            </div>

            <div className="grid grid-cols-1 gap-2.5 pt-2">
              <Button asChild variant="default" className="w-full gap-2 justify-start px-4">
                <Link href="/app/team">
                  <UserPlus className="h-4 w-4" />
                  Пригласить первого сотрудника (WhatsApp / Ссылка)
                </Link>
              </Button>

              <Button asChild variant="outline" className="w-full gap-2 justify-start px-4">
                <Link href="/app">
                  <PlusCircle className="h-4 w-4" />
                  Создать первый заказ
                </Link>
              </Button>

              <Button asChild variant="secondary" className="w-full gap-2 justify-start px-4">
                <Link href="/app">
                  <LayoutDashboard className="h-4 w-4" />
                  Открыть панель управления (Dashboard)
                </Link>
              </Button>
            </div>
          </Card>
        )}

        {/* Footer info */}
        <div className="text-center text-xs text-muted-foreground">
          Уже есть аккаунт?{" "}
          <Link href="/login" className="text-primary font-medium hover:underline">
            Войти
          </Link>
        </div>
      </div>
    </div>
  );
}
