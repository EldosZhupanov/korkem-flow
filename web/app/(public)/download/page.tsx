import Link from "next/link";
import { 
  Download, 
  Smartphone, 
  Laptop, 
  Apple, 
  HelpCircle, 
  CheckCircle2, 
  AlertTriangle, 
  ShieldCheck, 
  ArrowRight,
  ExternalLink,
  Info
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";

export default function DownloadPage() {
  return (
    <div className="py-12 md:py-20">
      <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mx-auto text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            Центр загрузок KORKEM
          </Badge>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-foreground">
            Скачайте приложения для всех ваших устройств
          </h1>
          <p className="mt-4 text-base sm:text-lg text-muted-foreground leading-relaxed">
            Управляйте заказами и раскроем в цеху на смартфонах, ноутбуках и десктопных компьютерах.
          </p>
        </div>

        {/* Primary Download Platforms */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-16">
          {/* Android Card */}
          <div className="rounded-2xl border-2 border-emerald-500/30 bg-card p-6 sm:p-8 shadow-sm relative overflow-hidden">
            <div className="absolute top-0 right-0 bg-emerald-500 text-white text-[10px] font-bold px-3 py-1 rounded-bl-lg uppercase tracking-wider">
              Релиз 2026
            </div>
            <div className="flex items-center gap-4 mb-4">
              <div className="h-14 w-14 rounded-2xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
                <Smartphone className="h-7 w-7" />
              </div>
              <div>
                <h3 className="text-2xl font-bold text-foreground">Android</h3>
                <p className="text-xs text-muted-foreground">Смартфоны и планшеты мастеров и замерщиков</p>
              </div>
            </div>

            <p className="text-sm text-muted-foreground mb-6 leading-relaxed">
              Универсальный установочный пакет APK для любых моделей смартфонов (Samsung, Xiaomi, Huawei, Honor, Oppo, Realme). Поддерживает замеры, фотофиксацию и офлайн-режим.
            </p>

            <div className="space-y-2 mb-6 rounded-xl bg-muted/40 p-4 text-xs">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Версия:</span>
                <span className="font-semibold text-foreground">v0.3.0 Release</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Размер файла:</span>
                <span className="font-semibold text-foreground">~68.0 МБ</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Требования:</span>
                <span className="font-semibold text-foreground">Android 8.0 или выше</span>
              </div>
            </div>

            <Button size="lg" className="w-full bg-emerald-600 hover:bg-emerald-700 text-white gap-2 h-12 text-base font-semibold shadow-md" asChild>
              <a href="/files/korkem-flow.apk" download="korkem-flow.apk">
                <Download className="h-5 w-5" />
                <span>Скачать APK для Android (68 МБ)</span>
              </a>
            </Button>
          </div>

          {/* Windows Desktop Card */}
          <div className="rounded-2xl border-2 border-blue-500/30 bg-card p-6 sm:p-8 shadow-sm relative overflow-hidden">
            <div className="absolute top-0 right-0 bg-blue-500 text-white text-[10px] font-bold px-3 py-1 rounded-bl-lg uppercase tracking-wider">
              Десктоп Релиз
            </div>
            <div className="flex items-center gap-4 mb-4">
              <div className="h-14 w-14 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center">
                <Laptop className="h-7 w-7" />
              </div>
              <div>
                <h3 className="text-2xl font-bold text-foreground">Windows x64</h3>
                <p className="text-xs text-muted-foreground">Рабочие места технологов и конструкторов</p>
              </div>
            </div>

            <p className="text-sm text-muted-foreground mb-6 leading-relaxed">
              Портативное десктопное приложение для 64-битных систем Windows. Высокая скорость расчетов карт раскроя, прямой экспорт управляющих программ для станков с ЧПУ.
            </p>

            <div className="space-y-2 mb-6 rounded-xl bg-muted/40 p-4 text-xs">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Версия:</span>
                <span className="font-semibold text-foreground">v0.3.0 Desktop</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Размер архива:</span>
                <span className="font-semibold text-foreground">~30.6 МБ</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Требования:</span>
                <span className="font-semibold text-foreground">Windows 10 / 11 (64-bit)</span>
              </div>
            </div>

            <Button size="lg" className="w-full bg-blue-600 hover:bg-blue-700 text-white gap-2 h-12 text-base font-semibold shadow-md" asChild>
              <a href="/files/korkem-flow-windows-x64.zip" download="korkem-flow-windows-x64.zip">
                <Download className="h-5 w-5" />
                <span>Скачать для Windows (30.6 МБ)</span>
              </a>
            </Button>
          </div>
        </div>

        {/* Apple Ecosystem & Web Options */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-16">
          {/* iOS / iPhone */}
          <div className="rounded-2xl border border-border/80 bg-card p-6 shadow-sm">
            <div className="flex items-center gap-3 mb-3">
              <div className="h-10 w-10 rounded-xl bg-muted text-foreground flex items-center justify-center">
                <Apple className="h-5 w-5" />
              </div>
              <div>
                <h4 className="text-lg font-bold text-foreground">Apple iPhone & iPad</h4>
                <p className="text-xs text-muted-foreground">PWA и Мобильный веб-клиент</p>
              </div>
            </div>
            <p className="text-xs text-muted-foreground leading-relaxed mb-4">
              Полнофункциональная веб-версия оптимизирована под сенсорные экраны iOS. Вы можете мгновенно установить приложение на главный экран без App Store:
            </p>
            <ol className="list-decimal list-inside space-y-1.5 text-xs text-foreground bg-muted/30 p-3 rounded-lg">
              <li>Откройте сайт <span className="font-semibold">korkem.asia</span> в Safari на вашем iPhone.</li>
              <li>Нажмите кнопку «Поделиться» (иконка квадрата со стрелкой вверх).</li>
              <li>Выберите «На экран «Домой»» (Add to Home Screen).</li>
            </ol>
          </div>

          {/* macOS / MacBook */}
          <div className="rounded-2xl border border-border/80 bg-card p-6 shadow-sm">
            <div className="flex items-center gap-3 mb-3">
              <div className="h-10 w-10 rounded-xl bg-muted text-foreground flex items-center justify-center">
                <Laptop className="h-5 w-5" />
              </div>
              <div>
                <h4 className="text-lg font-bold text-foreground">macOS (MacBook & iMac)</h4>
                <p className="text-xs text-muted-foreground">Веб-портал и десктопный режим</p>
              </div>
            </div>
            <p className="text-xs text-muted-foreground leading-relaxed mb-4">
              На компьютерах Apple с чипами M1/M2/M3/M4 и Intel веб-кабинет KORKEM работает с максимальной скоростью в Safari, Chrome и Arc:
            </p>
            <div className="space-y-2">
              <Button variant="outline" size="sm" className="w-full justify-between" asChild>
                <Link href="/app">
                  <span>Открыть KORKEM в браузере macOS</span>
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <p className="text-[11px] text-muted-foreground">
                В браузере Chrome доступна опция "Установить приложение KORKEM", создающая отдельное нативное окно в Dock.
              </p>
            </div>
          </div>
        </div>

        {/* Installation Instructions & FAQ */}
        <div className="rounded-2xl border border-border/80 bg-muted/20 p-6 sm:p-10">
          <div className="flex items-center gap-3 mb-6">
            <HelpCircle className="h-6 w-6 text-primary" />
            <h3 className="text-xl font-bold text-foreground">Часто задаваемые вопросы по установке</h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-xs leading-relaxed">
            <div className="space-y-2">
              <h4 className="font-semibold text-foreground text-sm flex items-center gap-1.5">
                <Info className="h-4 w-4 text-blue-500" />
                Как установить APK на Android?
              </h4>
              <p className="text-muted-foreground">
                После завершения скачивания откройте файл <code className="bg-muted px-1 py-0.5 rounded">korkem-flow.apk</code> из шторки уведомлений или папки «Загрузки». Если система запросит разрешение на установку из неизвестных источников для вашего браузера, подтвердите его в настройках безопасности.
              </p>
            </div>

            <div className="space-y-2">
              <h4 className="font-semibold text-foreground text-sm flex items-center gap-1.5">
                <Info className="h-4 w-4 text-blue-500" />
                Как запустить на Windows?
              </h4>
              <p className="text-muted-foreground">
                Скачанный архив <code className="bg-muted px-1 py-0.5 rounded">korkem-flow-windows-x64.zip</code> распакуйте в удобную папку (например, в «Документы» или на диск C:). Внутри найдите файл <code className="bg-muted px-1 py-0.5 rounded">korkem_flow.exe</code> и запустите его. При предупреждении SmartScreen нажмите «Подробнее» → «Выполнить в любом случае».
              </p>
            </div>

            <div className="space-y-2">
              <h4 className="font-semibold text-foreground text-sm flex items-center gap-1.5">
                <AlertTriangle className="h-4 w-4 text-amber-500" />
                Что делать, если пишет «Нет соединения с интернетом»?
              </h4>
              <p className="text-muted-foreground">
                Приложение подключается к защищенному центральному серверу <code className="bg-muted px-1 py-0.5 rounded">https://api.korkem.asia</code>. Убедитесь, что устройство подключено к мобильной сети или Wi-Fi. Если вы используете корпоративный VPN или файрвол, разрешите доступ к домену korkem.asia.
              </p>
            </div>

            <div className="space-y-2">
              <h4 className="font-semibold text-foreground text-sm flex items-center gap-1.5">
                <ShieldCheck className="h-4 w-4 text-emerald-500" />
                Нужно ли регистрироваться перед входом?
              </h4>
              <p className="text-muted-foreground">
                Да. Владелец предприятия регистрирует компанию один раз на сайте. После этого сотрудники могут входить в мобильные и десктопные приложения под своими учетными записями, выданными администратором.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
