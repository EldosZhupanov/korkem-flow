import Link from "next/link";
import { 
  ArrowRight, 
  Check, 
  Layers, 
  Cpu, 
  Boxes, 
  Users, 
  FileText, 
  Smartphone, 
  QrCode, 
  Calculator, 
  TrendingUp,
  CreditCard,
  MessageSquare
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function FeaturesPage() {
  return (
    <div className="py-12 md:py-20">
      <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mx-auto text-center mb-16">
          <Badge variant="outline" className="mb-4 border-primary/30 text-primary">
            Функционал KORKEM Flow
          </Badge>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-foreground">
            Полный цикл мебельного производства в единой системе
          </h1>
          <p className="mt-4 text-base sm:text-lg text-muted-foreground leading-relaxed">
            От первого звонка клиента и замера до отгрузки готовой мебели и контроля гарантийного обслуживания.
          </p>
        </div>

        {/* Feature Sections */}
        <div className="space-y-20">
          {/* Feature 1: CRM & Calculation */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            <div className="lg:col-span-7 space-y-4">
              <div className="inline-flex items-center gap-2 rounded-lg bg-blue-500/10 px-3 py-1 text-xs font-semibold text-blue-600">
                <Calculator className="h-4 w-4" />
                <span>Заказы и Спецификации</span>
              </div>
              <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-foreground">
                Точный расчет себестоимости и оформление заказов за 5 минут
              </h2>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Больше никаких ошибок в расчетах на коленке или в Excel. Менеджер или замерщик вносит параметры кухни, шкафа-купе или гардеробной: размеры, материалы фасадов, корпуса, фурнитуру (петли с доводчиками, направляющие скрытого монтажа).
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Автоматический расчет квадратуры ЛДСП, МДФ и метров кромки</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Учет стоимости работ: распил, кромление, присадка, монтаж</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Печать коммерческого предложения и договора с эскизом</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Интеграция с Kaspi Pay и быстрая отправка в WhatsApp</span>
                </div>
              </div>
            </div>
            <div className="lg:col-span-5 rounded-2xl border border-border/80 bg-muted/40 p-6">
              <div className="space-y-4 text-xs">
                <div className="flex items-center justify-between border-b pb-2">
                  <span className="font-semibold text-foreground">Заказ №KZ-2026-089</span>
                  <Badge variant="outline" className="bg-emerald-500/10 text-emerald-600 border-emerald-300">В производстве</Badge>
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between text-muted-foreground">
                    <span>Изделие:</span>
                    <span className="font-medium text-foreground">Кухонный гарнитур "Лофт"</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Материал корпуса:</span>
                    <span className="font-medium text-foreground">ЛДСП Egger 18мм Дуб Галифакс</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Фурнитура:</span>
                    <span className="font-medium text-foreground">Blum петли Clip-Top + Tandembox</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Себестоимость мат.:</span>
                    <span className="font-medium text-foreground">284 500 ₸</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Работы и монтаж:</span>
                    <span className="font-medium text-foreground">95 000 ₸</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground border-t pt-2 font-bold text-foreground">
                    <span>Итого к оплате:</span>
                    <span className="text-primary text-sm">490 000 ₸</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Feature 2: Nesting & CNC */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            <div className="lg:col-span-5 order-2 lg:order-1 rounded-2xl border border-border/80 bg-muted/40 p-6">
              <div className="space-y-3 text-xs">
                <div className="flex items-center justify-between border-b pb-2">
                  <span className="font-semibold text-foreground">Карта раскроя Лист 1 (2800x2070)</span>
                  <span className="text-emerald-600 font-bold">93.8% КИМ</span>
                </div>
                <div className="h-32 rounded-lg border border-dashed border-primary/40 bg-primary/5 flex items-center justify-center text-center p-4">
                  <p className="text-xs text-muted-foreground">
                    Интерактивная 2D карта раскроя: 14 деталей, 2 поворота, нулевые сколы кромки
                  </p>
                </div>
                <div className="flex justify-between text-muted-foreground pt-1">
                  <span>Деловой обрезок:</span>
                  <span className="text-foreground font-medium">1240 x 600 мм (сохранен на склад)</span>
                </div>
                <div className="flex justify-between text-muted-foreground">
                  <span>Станок:</span>
                  <span className="text-foreground font-medium">CNC Rover A / Biesse G-Code</span>
                </div>
              </div>
            </div>
            <div className="lg:col-span-7 order-1 lg:order-2 space-y-4">
              <div className="inline-flex items-center gap-2 rounded-lg bg-purple-500/10 px-3 py-1 text-xs font-semibold text-purple-600">
                <Cpu className="h-4 w-4" />
                <span>Раскрой и ЧПУ</span>
              </div>
              <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-foreground">
                Автоматическая оптимизация раскроя и экспорт в ЧПУ
              </h2>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Алгоритм KORKEM за секунды рассчитывает раскрой с максимальным коэффициентом использования материала (КИМ до 94%). Учитывается направление древесных волокон, технологический отступ и толщина пропила дисковой пилы.
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Печать бирок со штрихкодами и маркировкой сторон кромления</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Генерация файлов G-Code для фрезерных и сверлильно-присадочных станков</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Учет остатков: обрезки больше заданного размера автоматически попадают на склад</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Десктопное приложение для Windows x64 с высокой скоростью вычислений</span>
                </div>
              </div>
            </div>
          </div>

          {/* Feature 3: Warehouse */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            <div className="lg:col-span-7 space-y-4">
              <div className="inline-flex items-center gap-2 rounded-lg bg-amber-500/10 px-3 py-1 text-xs font-semibold text-amber-600">
                <Boxes className="h-4 w-4" />
                <span>Склад и Запасы</span>
              </div>
              <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-foreground">
                Многоскладской учет и моментальное списание материалов
              </h2>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Полный контроль над тем, где находится каждая пачка ЛДСП, бухта кромки или комплект направляющих. Разделяйте основной сырьевой склад, цеховой накопитель и склад готовой продукции.
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Резервирование материалов сразу при запуске заказа в работу</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Контроль неснижаемого остатка и предупреждения о дефиците</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Быстрое перемещение между складами через веб-кабинет или сканер</span>
                </div>
                <div className="flex items-start gap-2.5 text-xs text-foreground">
                  <Check className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                  <span>Синхронизация складских остатков с ERPNext в реальном времени</span>
                </div>
              </div>
            </div>
            <div className="lg:col-span-5 rounded-2xl border border-border/80 bg-muted/40 p-6">
              <div className="space-y-3 text-xs">
                <div className="flex items-center justify-between border-b pb-2">
                  <span className="font-semibold text-foreground">Склады предприятия</span>
                  <Badge variant="secondary">3 активных склада</Badge>
                </div>
                <div className="p-3 bg-background rounded-lg border space-y-1">
                  <div className="flex justify-between font-medium text-foreground">
                    <span>Склад плитных материалов (Основной)</span>
                    <span className="text-emerald-600">420 листов</span>
                  </div>
                  <p className="text-[11px] text-muted-foreground">ЛДСП 16мм, 18мм, 22мм, МДФ, ХДФ</p>
                </div>
                <div className="p-3 bg-background rounded-lg border space-y-1">
                  <div className="flex justify-between font-medium text-foreground">
                    <span>Склад фурнитуры и крепежа</span>
                    <span className="text-primary">1 850 ед.</span>
                  </div>
                  <p className="text-[11px] text-muted-foreground">Петли, газлифты, направляющие, конфирматы</p>
                </div>
                <div className="p-3 bg-background rounded-lg border space-y-1">
                  <div className="flex justify-between font-medium text-foreground">
                    <span>Цех готовой продукции</span>
                    <span className="text-muted-foreground">12 заказов</span>
                  </div>
                  <p className="text-[11px] text-muted-foreground">Упакованные модули к отгрузке</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* CTA */}
        <div className="mt-20 text-center rounded-2xl bg-muted/50 border border-border/60 p-8 sm:p-12">
          <h3 className="text-2xl font-bold text-foreground">Попробуйте все возможности в работе</h3>
          <p className="mt-2 text-sm text-muted-foreground max-w-xl mx-auto">
            Создайте компанию в KORKEM Flow и настройте структуру производства за несколько простых шагов.
          </p>
          <div className="mt-6 flex justify-center gap-4">
            <Button size="lg" asChild>
              <Link href="/register">Начать регистрацию</Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link href="/download">Скачать приложения</Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
