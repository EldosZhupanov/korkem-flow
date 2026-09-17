"use client";

import * as React from "react";
import Link from "next/link";
import { 
  Boxes, 
  Plus, 
  Check, 
  Ban, 
  CheckCircle2, 
  AlertCircle, 
  Loader2, 
  ArrowRight,
  Truck,
  Building,
  RefreshCw
} from "lucide-react";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingState } from "@/components/ui/loading-state";
import { korkemApi, type Warehouse } from "@/lib/korkem-api";

export default function WarehousesPage() {
  const [warehouses, setWarehouses] = React.useState<Warehouse[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Dialog state
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [newWarehouseName, setNewWarehouseName] = React.useState("");
  const [creating, setCreating] = React.useState(false);
  const [createError, setCreateError] = React.useState<string | null>(null);

  // Action status
  const [actionLoadingId, setActionLoadingId] = React.useState<string | null>(null);

  const fetchWarehouses = React.useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await korkemApi.getWarehouses();
      setWarehouses(data);
    } catch (err: any) {
      setError(err.message || "Не удалось загрузить склады");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    fetchWarehouses();
  }, [fetchWarehouses]);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!newWarehouseName.trim()) return;

    setCreating(true);
    setCreateError(null);

    try {
      await korkemApi.createWarehouse({
        warehouse_name: newWarehouseName.trim(),
      });
      setNewWarehouseName("");
      setCreateDialogOpen(false);
      await fetchWarehouses();
    } catch (err: any) {
      setCreateError(err.message || "Ошибка при создании склада");
    } finally {
      setCreating(false);
    }
  }

  async function handleSetShippingDefault(whName: string) {
    try {
      setActionLoadingId(whName);
      await korkemApi.setShippingDefault(whName);
      await fetchWarehouses();
    } catch (err: any) {
      alert(err.message || "Не удалось установить склад по умолчанию");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function handleToggleDisabled(whName: string, currentlyDisabled: boolean) {
    try {
      setActionLoadingId(whName);
      await korkemApi.setWarehouseDisabled(whName, !currentlyDisabled);
      await fetchWarehouses();
    } catch (err: any) {
      alert(err.message || "Не удалось изменить статус склада");
    } finally {
      setActionLoadingId(null);
    }
  }

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      <PageHeader
        title="Склады предприятия"
        description="Управление складами сырья, фурнитуры, распиловочного цеха и отгрузки"
        breadcrumbs={[
          { label: "Обзор", href: "/app" },
          { label: "Склады" },
        ]}
        action={
          <div className="flex gap-2.5">
            <Button
              variant="outline"
              size="sm"
              onClick={() => fetchWarehouses()}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            </Button>
            <Button size="sm" onClick={() => setCreateDialogOpen(true)} className="gap-1.5">
              <Plus className="h-4 w-4" />
              <span>Создать склад</span>
            </Button>
          </div>
        }
      />

      {error && (
        <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-4 text-xs text-destructive">
          <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      {loading ? (
        <LoadingState message="Загрузка структуры складов..." />
      ) : warehouses.length === 0 ? (
        <EmptyState
          icon={Boxes}
          title="Склады еще не созданы"
          description="Создайте первый склад предприятия для учета плитных материалов (ЛДСП/МДФ) и мебельной фурнитуры."
          action={
            <Button onClick={() => setCreateDialogOpen(true)}>
              <Plus className="h-4 w-4 mr-1.5" />
              Создать склад
            </Button>
          }
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {warehouses.map((wh) => {
            const isDefault = Boolean(wh.is_shipping_default);
            const isDisabled = Boolean(wh.disabled);
            const isActing = actionLoadingId === wh.name;

            return (
              <Card 
                key={wh.name} 
                className={`border-border/70 shadow-sm transition-all hover:border-primary/40 ${
                  isDisabled ? "opacity-60 bg-muted/30" : "bg-card"
                }`}
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2.5">
                      <div className={`h-9 w-9 rounded-lg flex items-center justify-center shrink-0 ${
                        isDefault 
                          ? "bg-primary/10 text-primary" 
                          : "bg-muted text-muted-foreground"
                      }`}>
                        <Boxes className="h-5 w-5" />
                      </div>
                      <div className="overflow-hidden">
                        <CardTitle className="text-sm font-bold truncate">
                          {wh.warehouse_name || wh.name}
                        </CardTitle>
                        <CardDescription className="text-[11px] truncate">
                          {wh.name}
                        </CardDescription>
                      </div>
                    </div>
                  </div>
                </CardHeader>

                <CardContent className="space-y-4 pt-1">
                  <div className="flex flex-wrap gap-2 text-xs">
                    {isDefault ? (
                      <Badge className="bg-primary/10 text-primary border-primary/20 hover:bg-primary/20 gap-1">
                        <Truck className="h-3 w-3" />
                        <span>Основной для отгрузки</span>
                      </Badge>
                    ) : (
                      <Badge variant="outline" className="text-muted-foreground">
                        Обычный склад
                      </Badge>
                    )}

                    {isDisabled ? (
                      <Badge variant="secondary" className="text-destructive bg-destructive/10">
                        Отключен
                      </Badge>
                    ) : (
                      <Badge variant="outline" className="text-emerald-600 bg-emerald-500/10 border-emerald-300">
                        Активен
                      </Badge>
                    )}
                  </div>

                  <div className="pt-2 border-t border-border/40 flex flex-col gap-2">
                    {!isDefault && !isDisabled && (
                      <Button
                        variant="outline"
                        size="sm"
                        className="w-full text-xs justify-between"
                        disabled={isActing}
                        onClick={() => handleSetShippingDefault(wh.name)}
                      >
                        <span>Назначить основным</span>
                        {isActing ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Check className="h-3.5 w-3.5" />}
                      </Button>
                    )}

                    <div className="flex items-center justify-between gap-2 pt-1">
                      <Button
                        variant="ghost"
                        size="sm"
                        className={`text-xs h-8 px-2 ${
                          isDisabled ? "text-emerald-600 hover:text-emerald-700" : "text-muted-foreground hover:text-destructive"
                        }`}
                        disabled={isActing}
                        onClick={() => handleToggleDisabled(wh.name, isDisabled)}
                      >
                        {isDisabled ? "Включить склад" : "Отключить склад"}
                      </Button>

                      <Link
                        href={`/app/warehouses/${encodeURIComponent(wh.name)}`}
                        className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
                      >
                        <span>Детали</span>
                        <ArrowRight className="h-3.5 w-3.5" />
                      </Link>
                    </div>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* Create Warehouse Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent>
          <form onSubmit={handleCreate}>
            <DialogHeader>
              <DialogTitle>Создать новый склад</DialogTitle>
              <DialogDescription>
                Укажите название склада или производственной зоны цеха. Склад будет привязан к вашей компании в ERPNext.
              </DialogDescription>
            </DialogHeader>

            <div className="py-4 space-y-4">
              {createError && (
                <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-3 text-xs text-destructive">
                  <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                  <span>{createError}</span>
                </div>
              )}

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground" htmlFor="warehouse_name">
                  Название склада *
                </label>
                <Input
                  id="warehouse_name"
                  placeholder="Например: Склад ЛДСП и МДФ, Цех кромления, Отгрузка"
                  value={newWarehouseName}
                  onChange={(e) => setNewWarehouseName(e.target.value)}
                  disabled={creating}
                  required
                  autoFocus
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setCreateDialogOpen(false)}
                disabled={creating}
              >
                Отмена
              </Button>
              <Button type="submit" disabled={creating}>
                {creating ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-1.5" />
                    <span>Создание...</span>
                  </>
                ) : (
                  <span>Создать склад</span>
                )}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
