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
            Центр загрузок KORKEM • Версия 0.3.0 (Сборка 5)
          </Badge>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-foreground">
            Скачайте приложения для всех ваших устройств
          </h1>
          <p className="mt-4 text-base sm:text-lg text-muted-foreground leading-relaxed">
            Управляйте заказами и раскроем в цеху на смартфонах, ноутбуках и десктопных компьютерах.
          </p>
        </div>

        {/* Primary Download Platforms */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          {/* Android Card */}
          <div className="rounded-2xl border-2 border-emerald-500/30 bg-card p-6 sm:p-7 shadow-sm relative overflow-hidden flex flex-col justify-between">
            <div>
              <div className="absolute top-0 right-0 bg-emerald-500 text-white text-[10px] font-bold px-3 py-1 rounded-bl-lg uppercase tracking-wider">
                Релиз 0.3.0
              </div>
              <div className="flex items-center gap-4 mb-4">
                <div className="h-12 w-12 rounded-2xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
                  <Smartphone className="h-6 w-6" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-foreground">Android</h3>
                  <p className="text-xs text-muted-foreground">Смартфоны и планшеты цеха</p>
                </div>
              </div>

              <p className="text-xs text-muted-foreground mb-4 leading-relaxed">
                APK-пакет для смартфонов и планшетов (Android 8.0+). Поддерживает замеры, фотофиксацию, отметку операций Job Card и автообновление.
              </p>

              <div className="space-y-1.5 mb-6 rounded-xl bg-muted/40 p-3 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Версия:</span>
                  <span className="font-semibold text-foreground">0.3.0 (Сборка 5)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Размер файла:</span>
                  <span className="font-semibold text-foreground">68.1 МБ</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Формат:</span>
                  <span className="font-semibold text-foreground">APK / AAB</span>
                </div>
              </div>
            </div>

            <Button size="lg" className="w-full bg-emerald-600 hover:bg-emerald-700 text-white gap-2 h-11 text-sm font-semibold shadow-md" asChild>
              <a href="/files/korkem-flow.apk" download="korkem-flow.apk">
                <Download className="h-4 w-4" />
                <span>Скачать APK (68.1 МБ)</span>
              </a>
            </Button>
          </div>

          {/* Windows Desktop Card */}
          <div className="rounded-2xl border-2 border-blue-500/30 bg-card p-6 sm:p-7 shadow-sm relative overflow-hidden flex flex-col justify-between">
            <div>
              <div className="absolute top-0 right-0 bg-blue-500 text-white text-[10px] font-bold px-3 py-1 rounded-bl-lg uppercase tracking-wider">
                Windows x64
              </div>
              <div className="flex items-center gap-4 mb-4">
                <div className="h-12 w-12 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center">
                  <Laptop className="h-6 w-6" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-foreground">Windows</h3>
                  <p className="text-xs text-muted-foreground">Рабочие места конструкторов</p>
                </div>
              </div>

              <p className="text-xs text-muted-foreground mb-4 leading-relaxed">
                Портативный ZIP-архив для Windows 10 / 11 (64-бит). Не требует установки: распакуйте и запустите <code className="bg-muted px-1 py-0.5 rounded">korkem_flow.exe</code>.
              </p>

              <div className="space-y-1.5 mb-6 rounded-xl bg-muted/40 p-3 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Версия:</span>
                  <span className="font-semibold text-foreground">0.3.0 (Сборка 5)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Размер архива:</span>
                  <span className="font-semibold text-foreground">30.6 МБ</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Формат:</span>
                  <span className="font-semibold text-foreground">Portable ZIP</span>
                </div>
              </div>
            </div>

            <Button size="lg" className="w-full bg-blue-600 hover:bg-blue-700 text-white gap-2 h-11 text-sm font-semibold shadow-md" asChild>
              <a href="/files/korkem-flow-windows-x64.zip" download="korkem-flow-windows-x64.zip">
                <Download className="h-4 w-4" />
                <span>Скачать для Windows (30.6 МБ)</span>
              </a>
            </Button>
          </div>

          {/* Linux Desktop Card */}
          <div className="rounded-2xl border-2 border-indigo-500/30 bg-card p-6 sm:p-7 shadow-sm relative overflow-hidden flex flex-col justify-between">
            <div>
              <div className="absolute top-0 right-0 bg-indigo-500 text-white text-[10px] font-bold px-3 py-1 rounded-bl-lg uppercase tracking-wider">
                Linux x64
              </div>
              <div className="flex items-center gap-4 mb-4">
                <div className="h-12 w-12 rounded-2xl bg-indigo-500/10 text-indigo-600 flex items-center justify-center">
                  <Laptop className="h-6 w-6" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-foreground">Linux</h3>
                  <p className="text-xs text-muted-foreground">Ubuntu, Debian, Fedora x64</p>
                </div>
              </div>

              <p className="text-xs text-muted-foreground mb-4 leading-relaxed">
                Автономный tar.gz бандл для рабочих станций Linux x64 с поддержкой GTK3/OpenGL и ускоренной обработкой карт раскроя.
              </p>

              <div className="space-y-1.5 mb-6 rounded-xl bg-muted/40 p-3 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Версия:</span>
                  <span className="font-semibold text-foreground">0.3.0 (Сборка 5)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Размер архива:</span>
                  <span className="font-semibold text-foreground">29.1 МБ</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Формат:</span>
                  <span className="font-semibold text-foreground">tar.gz</span>
                </div>
              </div>
            </div>

            <Button size="lg" className="w-full bg-indigo-600 hover:bg-indigo-700 text-white gap-2 h-11 text-sm font-semibold shadow-md" asChild>
              <a href="/files/korkem-flow-linux-x64.tar.gz" download="korkem-flow-linux-x64.tar.gz">
                <Download className="h-4 w-4" />
                <span>Скачать для Linux (29.1 МБ)</span>
              </a>
            </Button>
          </div>
        </div>

        {/* Release Verification & Checksums */}
        <div className="rounded-xl border border-border/80 bg-muted/30 p-4 mb-12 flex flex-wrap items-center justify-between gap-4 text-xs">
          <div className="flex items-center gap-2">
            <ShieldCheck className="h-5 w-5 text-emerald-500" />
            <span className="font-medium text-foreground">
              Все бинарные сборки подписаны и проверены контрольными суммами SHA-256.
            </span>
          </div>
          <div className="flex items-center gap-3">
            <a 
              href="/downloads/SHA256SUMS.txt" 
              target="_blank" 
              rel="noreferrer"
              className="text-primary hover:underline font-semibold flex items-center gap-1"
            >
              <span>SHA256SUMS.txt</span>
              <ExternalLink className="h-3 w-3" />
            </a>
            <span className="text-muted-foreground">•</span>
            <a 
              href="/downloads/latest.json" 
              target="_blank" 
              rel="noreferrer"
              className="text-primary hover:underline font-semibold flex items-center gap-1"
            >
              <span>Манифест latest.json</span>
              <ExternalLink className="h-3 w-3" />
            </a>
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
                <p className="text-xs text-muted-foreground">TestFlight (скоро) и Веб-приложение (PWA)</p>
              </div>
            </div>
            <p className="text-xs text-muted-foreground leading-relaxed mb-4">
              Нативная сборка iOS Runner готова к публикации в Apple Developer Program. Прямо сейчас на iPhone доступна быстрая установка веб-приложения:
            </p>
            <ol className="list-decimal list-inside space-y-1.5 text-xs text-foreground bg-muted/30 p-3 rounded-lg">
              <li>Откройте <span className="font-semibold">korkem.localhost</span> (или адрес вашего цеха) в Safari.</li>
              <li>Нажмите кнопку «Поделиться» (квадрат со стрелкой вверх).</li>
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
              На компьютерах Apple с чипами Apple Silicon (M1–M4) и Intel веб-кабинет KORKEM работает на полной скорости в Safari, Chrome и Arc:
            </p>
            <div className="space-y-2">
              <Button variant="outline" size="sm" className="w-full justify-between" asChild>
                <Link href="/app">
                  <span>Открыть KORKEM в браузере macOS</span>
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <p className="text-[11px] text-muted-foreground">
                В браузере Chrome доступна опция "Установить приложение KORKEM", создающая нативное окно в Dock.
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
