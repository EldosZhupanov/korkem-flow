"use client";

import * as React from "react";
import { 
  Building2, 
  Save, 
  CheckCircle2, 
  AlertCircle, 
  Loader2, 
  Mail, 
  Phone, 
  MapPin, 
  FileText, 
  Globe, 
  Coins 
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { LoadingState } from "@/components/ui/loading-state";
import { korkemApi, type CompanyDetails } from "@/lib/korkem-api";

export default function CompanyPage() {
  const { user, company, refresh } = useAuth();
  
  const [formData, setFormData] = React.useState<CompanyDetails>({
    company_name: "",
    owner_name: "",
    email: "",
    phone: "",
    address: "",
    tax_id: "",
    currency: "KZT",
    website: "",
  });

  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [saveSuccess, setSaveSuccess] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    async function loadCompany() {
      try {
        setLoading(true);
        const details = await korkemApi.getCompanyDetails();
        if (details) {
          setFormData({
            company_name: details.company_name || "",
            owner_name: details.owner_name || "",
            email: details.email || "",
            phone: details.phone || "",
            address: details.address || "",
            tax_id: details.tax_id || "",
            currency: details.currency || "KZT",
            website: details.website || "",
          });
        }
      } catch (err: any) {
        console.warn("Could not load company details:", err);
      } finally {
        setLoading(false);
      }
    }

    loadCompany();
  }, [user]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSaveSuccess(false);

    try {
      await korkemApi.saveCompanyDetails(formData);
      setSaveSuccess(true);
      await refresh();
      setTimeout(() => setSaveSuccess(false), 4000);
    } catch (err: any) {
      setError(err.message || "Не удалось сохранить данные компании");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return <LoadingState message="Загрузка данных компании..." />;
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      <PageHeader
        title="Профиль компании"
        description="Реквизиты мебельного производства, контакты и параметры учета"
        breadcrumbs={[
          { label: "Обзор", href: "/app" },
          { label: "Компания" },
        ]}
      />

      <form onSubmit={handleSave}>
        <div className="space-y-6">
          {error && (
            <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-4 text-xs text-destructive">
              <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          {saveSuccess && (
            <div className="flex items-center gap-2 rounded-lg bg-emerald-500/10 p-4 text-xs text-emerald-600">
              <CheckCircle2 className="h-4 w-4 shrink-0" />
              <span>Данные компании успешно сохранены в ERPNext!</span>
            </div>
          )}

          {/* Section 1: Basic details */}
          <Card className="border-border/70 shadow-sm">
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <Building2 className="h-4 w-4 text-primary" />
                <span>Основная информация</span>
              </CardTitle>
              <CardDescription>
                Наименование и контактные данные, используемые в накладных и спецификациях
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground" htmlFor="company_name">
                    Название компании / фабрики *
                  </label>
                  <Input
                    id="company_name"
                    value={formData.company_name}
                    onChange={(e) => setFormData({ ...formData, company_name: e.target.value })}
                    placeholder="ТОО Мебель Мастер"
                    required
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground" htmlFor="owner_name">
                    ФИО руководителя
                  </label>
                  <Input
                    id="owner_name"
                    value={formData.owner_name}
                    onChange={(e) => setFormData({ ...formData, owner_name: e.target.value })}
                    placeholder="Сериков Серик Серикович"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="email">
                    <Mail className="h-3.5 w-3.5 text-muted-foreground" />
                    Контактный Email
                  </label>
                  <Input
                    id="email"
                    type="email"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    placeholder="info@mebel.kz"
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="phone">
                    <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                    Контактный телефон
                  </label>
                  <Input
                    id="phone"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    placeholder="+7 (701) 123-45-67"
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Section 2: Legal & Address */}
          <Card className="border-border/70 shadow-sm">
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <FileText className="h-4 w-4 text-primary" />
                <span>Юридические реквизиты и адрес цеха</span>
              </CardTitle>
              <CardDescription>
                Данные для автоматического формирования договоров с клиентами и счетов
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground" htmlFor="tax_id">
                    БИН / ИИН предприятия
                  </label>
                  <Input
                    id="tax_id"
                    value={formData.tax_id}
                    onChange={(e) => setFormData({ ...formData, tax_id: e.target.value })}
                    placeholder="12-значный БИН или ИИН"
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="currency">
                    <Coins className="h-3.5 w-3.5 text-muted-foreground" />
                    Валюта расчетов
                  </label>
                  <Input
                    id="currency"
                    value={formData.currency}
                    onChange={(e) => setFormData({ ...formData, currency: e.target.value })}
                    placeholder="KZT"
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="address">
                  <MapPin className="h-3.5 w-3.5 text-muted-foreground" />
                  Адрес мебельного цеха / шоурума
                </label>
                <Input
                  id="address"
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  placeholder="г. Алматы, пр. Райымбека, 212"
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground flex items-center gap-1.5" htmlFor="website">
                  <Globe className="h-3.5 w-3.5 text-muted-foreground" />
                  Сайт компании
                </label>
                <Input
                  id="website"
                  value={formData.website}
                  onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                  placeholder="https://mebel-master.kz"
                />
              </div>
            </CardContent>
            <CardFooter className="flex justify-end border-t border-border/40 py-4">
              <Button type="submit" disabled={saving} className="gap-2">
                {saving ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    <span>Сохранение...</span>
                  </>
                ) : (
                  <>
                    <Save className="h-4 w-4" />
                    <span>Сохранить изменения</span>
                  </>
                )}
              </Button>
            </CardFooter>
          </Card>
        </div>
      </form>
    </div>
  );
}
