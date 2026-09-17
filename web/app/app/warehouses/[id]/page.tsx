"use client";

import * as React from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { 
  Boxes, 
  ArrowLeft, 
  Check, 
  Truck, 
  ShieldCheck, 
  Building2, 
  AlertCircle, 
  Loader2 
} from "lucide-react";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { LoadingState } from "@/components/ui/loading-state";
import { korkemApi, type Warehouse } from "@/lib/korkem-api";

export default function WarehouseDetailPage() {
  const params = useParams();
  const router = useRouter();
  const warehouseId = decodeURIComponent((params?.id as string) || "");

  const [warehouse, setWarehouse] = React.useState<Warehouse | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [acting, setActing] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const fetchWarehouse = React.useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const list = await korkemApi.getWarehouses();
      const found = list.find((w) => w.name === warehouseId);
      if (found) {
        setWarehouse(found);
      } else {
        setError("Склад не найден или не принадлежит вашей компании.");
      }
    } catch (err: any) {
      setError(err.message || "Ошибка при получении данных склада");
    } finally {
      setLoading(false);
    }
  }, [warehouseId]);

  React.useEffect(() => {
    if (warehouseId) {
      fetchWarehouse();
    }
  }, [warehouseId, fetchWarehouse]);

  async function handleSetShippingDefault() {
    if (!warehouse) return;
    try {
      setActing(true);
      await korkemApi.setShippingDefault(warehouse.name);
      await fetchWarehouse();
    } catch (err: any) {
      alert(err.message || "Не удалось назначить склад основным");
    } finally {
      setActing(false);
    }
  }

  async function handleToggleDisabled() {
    if (!warehouse) return;
    try {
      setActing(true);
      await korkemApi.setWarehouseDisabled(warehouse.name, !warehouse.disabled);
      await fetchWarehouse();
    } catch (err: any) {
      alert(err.message || "Не удалось изменить статус склада");
    } finally {
      setActing(false);
    }
  }

  if (loading) {
    return <LoadingState message="Загрузка информации о складе..." />;
  }

  if (error || !warehouse) {
    return (
      <div className="max-w-xl mx-auto py-12 space-y-4 text-center">
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-destructive/10 text-destructive">
          <AlertCircle className="h-6 w-6" />
        </div>
        <h2 className="text-lg font-bold text-foreground">Склад не найден</h2>
        <p className="text-xs text-muted-foreground">{error || "Указанный склад отсутствует"}</p>
        <Button variant="outline" asChild className="gap-2">
          <Link href="/app/warehouses">
            <ArrowLeft className="h-4 w-4" />
            <span>Вернуться к списку складов</span>
          </Link>
        </Button>
      </div>
    );
  }

  const isDefault = Boolean(warehouse.is_shipping_default);
  const isDisabled = Boolean(warehouse.disabled);

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <PageHeader
        title={warehouse.warehouse_name || warehouse.name}
        description={`ERPNext ID: ${warehouse.name}`}
        breadcrumbs={[
          { label: "Обзор", href: "/app" },
          { label: "Склады", href: "/app/warehouses" },
          { label: warehouse.warehouse_name || warehouse.name },
        ]}
        action={
          <Button variant="outline" size="sm" asChild className="gap-1.5">
            <Link href="/app/warehouses">
              <ArrowLeft className="h-4 w-4" />
              <span>Все склады</span>
            </Link>
          </Button>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Main Details */}
        <Card className="md:col-span-2 border-border/70 shadow-sm">
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Boxes className="h-4 w-4 text-primary" />
              <span>Параметры склада</span>
            </CardTitle>
            <CardDescription>
              Склад используется для резервирования ЛДСП, кромки и отгрузки заказов
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4 text-xs">
            <div className="grid grid-cols-2 gap-4 pb-3 border-b">
              <div>
                <span className="text-muted-foreground block mb-1">Наименование:</span>
                <span className="font-semibold text-foreground text-sm">
                  {warehouse.warehouse_name}
                </span>
              </div>
              <div>
                <span className="text-muted-foreground block mb-1">Системный идентификатор:</span>
                <span className="font-mono text-foreground">
                  {warehouse.name}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4 pb-3 border-b">
              <div>
                <span className="text-muted-foreground block mb-1">Компания:</span>
                <span className="font-medium text-foreground">
                  {warehouse.company || "Текущее предприятие"}
                </span>
              </div>
              <div>
                <span className="text-muted-foreground block mb-1">Тип узла:</span>
                <span className="font-medium text-foreground">
                  {warehouse.is_group ? "Группа складов" : "Склад хранения"}
                </span>
              </div>
            </div>

            <div className="flex items-center justify-between pt-1">
              <span className="text-muted-foreground">Статус в системе:</span>
              {isDisabled ? (
                <Badge variant="destructive">Отключен (архивный)</Badge>
              ) : (
                <Badge variant="outline" className="text-emerald-600 bg-emerald-500/10 border-emerald-300">
                  Активен и доступен
                </Badge>
              )}
            </div>

            <div className="flex items-center justify-between pt-1">
              <span className="text-muted-foreground">Роль в отгрузке:</span>
              {isDefault ? (
                <Badge className="bg-primary/10 text-primary border-primary/20">
                  Склад по умолчанию для отгрузок
                </Badge>
              ) : (
                <span className="text-muted-foreground">Дополнительный склад</span>
              )}
            </div>
          </CardContent>
          <CardFooter className="flex items-center justify-between border-t border-border/40 py-4">
            <Button
              variant="outline"
              size="sm"
              disabled={acting}
              onClick={handleToggleDisabled}
              className={isDisabled ? "text-emerald-600 hover:text-emerald-700" : "text-destructive hover:bg-destructive/10"}
            >
              {acting ? <Loader2 className="h-4 w-4 animate-spin mr-1.5" /> : null}
              {isDisabled ? "Включить склад" : "Отключить склад"}
            </Button>

            {!isDefault && !isDisabled && (
              <Button
                size="sm"
                disabled={acting}
                onClick={handleSetShippingDefault}
                className="gap-1.5"
              >
                {acting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
                <span>Сделать основным</span>
              </Button>
            )}
          </CardFooter>
        </Card>

        {/* Info Column */}
        <div className="space-y-4">
          <Card className="border-border/70 shadow-sm bg-muted/20">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                <ShieldCheck className="h-4 w-4 text-emerald-600" />
                <span>Изоляция остатков</span>
              </CardTitle>
            </CardHeader>
            <CardContent className="text-xs text-muted-foreground space-y-2">
              <p>
                Товары и материалы на данном складе доступны только пользователям с правами доступа к вашей компании.
              </p>
              <p>
                Мастера цеха в мобильном приложении Android видят остатки этого склада при сканировании штрих-кода.
              </p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
