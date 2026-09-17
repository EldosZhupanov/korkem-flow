"use client";

import * as React from "react";
import { 
  Users, 
  UserPlus, 
  Shield, 
  CheckCircle2, 
  AlertCircle, 
  Loader2, 
  Mail, 
  Ban, 
  RefreshCw, 
  Briefcase,
  UserCheck,
  Copy,
  Check,
  ExternalLink,
  Share2,
  Trash2,
  Clock,
  Phone,
  QrCode
} from "lucide-react";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingState } from "@/components/ui/loading-state";
import { korkemApi, type StaffMember } from "@/lib/korkem-api";

const CANONICAL_ROLES_LIST = [
  { key: "PRODUCTION_MANAGER", label: "Начальник производства" },
  { key: "DESIGNER_TECHNOLOGIST", label: "Конструктор-технолог" },
  { key: "MEASURER", label: "Замерщик" },
  { key: "CUTTING_OPERATOR", label: "Оператор раскроя" },
  { key: "EDGEBANDING_OPERATOR", label: "Оператор кромкооблицовки" },
  { key: "CNC_OPERATOR", label: "Оператор ЧПУ" },
  { key: "ASSEMBLER", label: "Сборщик цеха" },
  { key: "INSTALLER", label: "Монтажник / Сборщик на объекте" },
  { key: "DRIVER", label: "Водитель-доставщик" },
  { key: "ACCOUNTANT", label: "Бухгалтер / Кассир" },
  { key: "ADMIN", label: "Администратор" },
];

export default function TeamPage() {
  const [activeTab, setActiveTab] = React.useState<"active" | "invited">("active");
  const [members, setMembers] = React.useState<StaffMember[]>([]);
  const [invitations, setInvitations] = React.useState<any[]>([]);
  const [canInvite, setCanInvite] = React.useState(true);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Invite modal state
  const [inviteOpen, setInviteOpen] = React.useState(false);
  const [selectedRole, setSelectedRole] = React.useState("CUTTING_OPERATOR");
  const [invitePhone, setInvitePhone] = React.useState("");
  const [inviting, setInviting] = React.useState(false);
  const [inviteResult, setInviteResult] = React.useState<any | null>(null);
  const [copiedLink, setCopiedLink] = React.useState(false);

  // Change position modal state
  const [changePosMember, setChangePosMember] = React.useState<StaffMember | null>(null);
  const [newPosition, setNewPosition] = React.useState("");
  const [changingPos, setChangingPos] = React.useState(false);

  // Action status
  const [actingEmail, setActingEmail] = React.useState<string | null>(null);

  const loadData = React.useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const [mList, invList, canInv] = await Promise.allSettled([
        korkemApi.getStaffMembers(),
        korkemApi.listInvitations(),
        korkemApi.canInvite(),
      ]);

      if (mList.status === "fulfilled") setMembers(mList.value);
      if (invList.status === "fulfilled") setInvitations(invList.value);
      if (canInv.status === "fulfilled") setCanInvite(canInv.value);
    } catch (err: any) {
      setError(err.message || "Не удалось загрузить данные команды");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    loadData();
  }, [loadData]);

  async function handleCreateInvite(e: React.FormEvent) {
    e.preventDefault();
    setInviting(true);
    setError(null);

    try {
      const res = await korkemApi.createInvitation({
        role_name: selectedRole,
        phone: invitePhone.trim() || undefined,
        expires_days: 7,
      });

      setInviteResult(res);
      await loadData();
    } catch (err: any) {
      alert(err.message || "Не удалось создать приглашение");
    } finally {
      setInviting(false);
    }
  }

  function handleCopyInvite(url: string) {
    navigator.clipboard.writeText(url);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  }

  async function handleRevokeInvite(invitationId: string) {
    if (!confirm("Вы уверены, что хотите отозвать это приглашение?")) return;
    try {
      await korkemApi.revokeInvitation(invitationId);
      await loadData();
    } catch (err: any) {
      alert(err.message || "Не удалось отозвать приглашение");
    }
  }

  async function handleResendInvite(invitationId: string) {
    try {
      const res = await korkemApi.resendInvitation(invitationId);
      setInviteResult(res);
      setInviteOpen(true);
      await loadData();
    } catch (err: any) {
      alert(err.message || "Не удалось обновить приглашение");
    }
  }

  async function handleChangePositionSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!changePosMember || !newPosition) return;

    setChangingPos(true);
    try {
      const targetEmail = changePosMember.email || changePosMember.user;
      if (!targetEmail) return;
      await korkemApi.changePosition(targetEmail, newPosition);
      setChangePosMember(null);
      await loadData();
    } catch (err: any) {
      alert(err.message || "Не удалось изменить должность");
    } finally {
      setChangingPos(false);
    }
  }

  async function handleToggleStatus(email: string, currentlyDisabled: boolean) {
    try {
      setActingEmail(email);
      if (currentlyDisabled) {
        await korkemApi.reactivateStaff(email);
      } else {
        await korkemApi.deactivateStaff(email);
      }
      await loadData();
    } catch (err: any) {
      alert(err.message || "Не удалось изменить статус доступа");
    } finally {
      setActingEmail(null);
    }
  }

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      <PageHeader
        title="Команда производства"
        description="Сотрудники мебельной фабрики, их роли, приглашения и доступ к рабочим модулям"
        breadcrumbs={[
          { label: "Обзор", href: "/app" },
          { label: "Команда" },
        ]}
        action={
          <div className="flex gap-2.5">
            <Button
              variant="outline"
              size="sm"
              onClick={() => loadData()}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            </Button>
            {canInvite && (
              <Button size="sm" onClick={() => { setInviteResult(null); setInviteOpen(true); }} className="gap-1.5">
                <UserPlus className="h-4 w-4" />
                <span>Пригласить сотрудника</span>
              </Button>
            )}
          </div>
        }
      />

      {error && (
        <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-4 text-xs text-destructive">
          <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      {/* Tabs: Active vs Invited */}
      <Tabs value={activeTab} onValueChange={(v: any) => setActiveTab(v)}>
        <TabsList className="grid w-full max-w-md grid-cols-2">
          <TabsTrigger value="active" className="text-xs font-semibold">
            Активные ({members.length})
          </TabsTrigger>
          <TabsTrigger value="invited" className="text-xs font-semibold">
            Приглашенные ({invitations.filter(i => i.status === "ACTIVE").length})
          </TabsTrigger>
        </TabsList>

        {/* Tab 1: Active Staff */}
        <TabsContent value="active" className="pt-3">
          {loading ? (
            <LoadingState message="Загрузка списка команды..." />
          ) : members.length === 0 ? (
            <EmptyState
              icon={Users}
              title="Сотрудники еще не добавлены"
              description="Пригласите мастера раскроя, конструктора или замерщика по ссылке."
              action={
                canInvite ? (
                  <Button onClick={() => { setInviteResult(null); setInviteOpen(true); }}>
                    <UserPlus className="h-4 w-4 mr-1.5" />
                    Пригласить первого сотрудника
                  </Button>
                ) : undefined
              }
            />
          ) : (
            <div className="rounded-xl border border-border/80 bg-card overflow-hidden shadow-sm">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="border-b bg-muted/40 text-muted-foreground font-semibold">
                    <tr>
                      <th className="py-3.5 px-4">Сотрудник</th>
                      <th className="py-3.5 px-4">Должность в цеху</th>
                      <th className="py-3.5 px-4">Статус</th>
                      <th className="py-3.5 px-4 text-right">Действия</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border/60">
                    {members.map((member) => {
                      const email = member.email || member.user;
                      const posKey = member.position || member.role || "worker";
                      const matchedRole = CANONICAL_ROLES_LIST.find(r => r.key === posKey.toUpperCase());
                      const posLabel = matchedRole?.label || member.designation || posKey;
                      const isDisabled = member.status === "Inactive" || member.enabled === false;
                      const isActing = actingEmail === email;

                      return (
                        <tr key={email} className="hover:bg-muted/20 transition-colors">
                          <td className="py-3.5 px-4">
                            <div className="flex items-center gap-3">
                              <div className="h-8 w-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs uppercase">
                                {(member.first_name || member.full_name || email).charAt(0)}
                              </div>
                              <div>
                                <div className="font-semibold text-foreground">
                                  {member.first_name || member.full_name || email.split("@")[0]}
                                </div>
                                <div className="text-[11px] text-muted-foreground flex items-center gap-1">
                                  <Mail className="h-3 w-3" />
                                  <span>{email}</span>
                                </div>
                              </div>
                            </div>
                          </td>

                          <td className="py-3.5 px-4">
                            <Badge variant="secondary" className="font-medium gap-1 text-[11px]">
                              <Briefcase className="h-3 w-3 text-muted-foreground" />
                              <span>{posLabel}</span>
                            </Badge>
                          </td>

                          <td className="py-3.5 px-4">
                            {isDisabled ? (
                              <Badge variant="destructive" className="text-[10px]">
                                Доступ закрыт
                              </Badge>
                            ) : (
                              <Badge variant="outline" className="text-emerald-600 bg-emerald-500/10 border-emerald-300 text-[10px]">
                                Активен
                              </Badge>
                            )}
                          </td>

                          <td className="py-3.5 px-4 text-right">
                            <div className="inline-flex items-center gap-2">
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 text-xs"
                                onClick={() => {
                                  setChangePosMember(member);
                                  setNewPosition(posKey);
                                }}
                              >
                                Сменить роль
                              </Button>

                              <Button
                                variant="ghost"
                                size="sm"
                                disabled={isActing}
                                onClick={() => handleToggleStatus(email, isDisabled)}
                                className={`h-7 text-xs ${
                                  isDisabled ? "text-emerald-600 hover:text-emerald-700" : "text-destructive hover:bg-destructive/10"
                                }`}
                              >
                                {isActing ? (
                                  <Loader2 className="h-3 w-3 animate-spin" />
                                ) : isDisabled ? (
                                  "Включить"
                                ) : (
                                  "Отключить"
                                )}
                              </Button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </TabsContent>

        {/* Tab 2: Pending Invitations */}
        <TabsContent value="invited" className="pt-3">
          {invitations.length === 0 ? (
            <EmptyState
              icon={UserPlus}
              title="Нет активных приглашений"
              description="Создайте приглашение по ссылке для отправки в WhatsApp или Telegram."
              action={
                canInvite ? (
                  <Button onClick={() => { setInviteResult(null); setInviteOpen(true); }}>
                    <UserPlus className="h-4 w-4 mr-1.5" />
                    Создать ссылку приглашения
                  </Button>
                ) : undefined
              }
            />
          ) : (
            <div className="rounded-xl border border-border/80 bg-card overflow-hidden shadow-sm">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="border-b bg-muted/40 text-muted-foreground font-semibold">
                    <tr>
                      <th className="py-3.5 px-4">Должность</th>
                      <th className="py-3.5 px-4">Телефон / Контакт</th>
                      <th className="py-3.5 px-4">Срок действия</th>
                      <th className="py-3.5 px-4">Статус</th>
                      <th className="py-3.5 px-4 text-right">Действия</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border/60">
                    {invitations.map((inv) => {
                      const isActive = inv.status === "ACTIVE";
                      return (
                        <tr key={inv.id} className="hover:bg-muted/20 transition-colors">
                          <td className="py-3.5 px-4">
                            <Badge variant="outline" className="font-semibold text-primary">
                              {inv.role_title_ru}
                            </Badge>
                          </td>

                          <td className="py-3.5 px-4 font-mono text-[11px] text-muted-foreground">
                            {inv.phone || "Без привязки к номеру"}
                          </td>

                          <td className="py-3.5 px-4 text-muted-foreground flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            <span>до {new Date(inv.expires_at).toLocaleDateString()}</span>
                          </td>

                          <td className="py-3.5 px-4">
                            {inv.status === "ACTIVE" ? (
                              <Badge variant="outline" className="text-emerald-600 bg-emerald-500/10 border-emerald-300 text-[10px]">
                                Ожидает входа
                              </Badge>
                            ) : inv.status === "ACCEPTED" ? (
                              <Badge variant="secondary" className="text-[10px]">
                                Принято
                              </Badge>
                            ) : inv.status === "EXPIRED" ? (
                              <Badge variant="destructive" className="text-[10px]">
                                Истекло
                              </Badge>
                            ) : (
                              <Badge variant="destructive" className="text-[10px]">
                                Отозвано
                              </Badge>
                            )}
                          </td>

                          <td className="py-3.5 px-4 text-right">
                            <div className="inline-flex items-center gap-1.5">
                              {isActive && (
                                <>
                                  <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-7 text-xs text-primary"
                                    onClick={() => handleResendInvite(inv.id)}
                                  >
                                    Поделиться
                                  </Button>
                                  <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-7 text-xs text-destructive hover:bg-destructive/10"
                                    onClick={() => handleRevokeInvite(inv.id)}
                                  >
                                    Отозвать
                                  </Button>
                                </>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* Invite Dialog with Sharing */}
      <Dialog open={inviteOpen} onOpenChange={setInviteOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>
              {inviteResult ? "Приглашение создано" : "Пригласить сотрудника в цех"}
            </DialogTitle>
            <DialogDescription className="text-xs">
              {inviteResult 
                ? "Отправьте эту ссылку сотруднику в мессенджер. Он сможет сразу войти и приступить к работе."
                : "Выберите должность. Ссылка действует 7 дней и может быть использована 1 раз."}
            </DialogDescription>
          </DialogHeader>

          {inviteResult ? (
            <div className="py-3 space-y-4">
              <div className="p-3 bg-muted/40 rounded-xl border space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">Должность:</span>
                  <Badge variant="default">{inviteResult.role_title_ru}</Badge>
                </div>
                <div className="flex items-center gap-2">
                  <Input
                    readOnly
                    value={inviteResult.invite_url}
                    className="font-mono text-xs bg-background"
                  />
                  <Button
                    type="button"
                    size="icon"
                    variant="outline"
                    onClick={() => handleCopyInvite(inviteResult.invite_url)}
                  >
                    {copiedLink ? <Check className="h-4 w-4 text-emerald-600" /> : <Copy className="h-4 w-4" />}
                  </Button>
                </div>
              </div>

              {/* 1-Tap Sharing Buttons */}
              <div className="grid grid-cols-2 gap-2">
                <Button
                  asChild
                  className="bg-[#25D366] hover:bg-[#20bd5a] text-white text-xs gap-1.5"
                >
                  <a
                    href={inviteResult.whatsapp_url_ru}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <Share2 className="h-3.5 w-3.5" />
                    WhatsApp
                  </a>
                </Button>

                <Button
                  asChild
                  className="bg-[#0088cc] hover:bg-[#0077b5] text-white text-xs gap-1.5"
                >
                  <a
                    href={inviteResult.telegram_url_ru}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <Share2 className="h-3.5 w-3.5" />
                    Telegram
                  </a>
                </Button>
              </div>

              <div className="text-center pt-2">
                <Button variant="outline" className="w-full text-xs" onClick={() => setInviteOpen(false)}>
                  Готово
                </Button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleCreateInvite} className="py-3 space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground">Должность в цеху *</label>
                <select
                  value={selectedRole}
                  onChange={(e) => setSelectedRole(e.target.value)}
                  className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  {CANONICAL_ROLES_LIST.map((r) => (
                    <option key={r.key} value={r.key}>
                      {r.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-medium text-foreground">Номер телефона сотрудника</label>
                  <span className="text-[10px] text-muted-foreground">Необязательно</span>
                </div>
                <Input
                  type="tel"
                  placeholder="+7 (701) 000-00-00"
                  value={invitePhone}
                  onChange={(e) => setInvitePhone(e.target.value)}
                />
              </div>

              <DialogFooter className="pt-2">
                <Button type="button" variant="outline" onClick={() => setInviteOpen(false)}>
                  Отмена
                </Button>
                <Button type="submit" disabled={inviting} className="gap-1.5">
                  {inviting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Share2 className="h-4 w-4" />}
                  Создать ссылку
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>

      {/* Change Position Dialog */}
      <Dialog open={!!changePosMember} onOpenChange={(open) => !open && setChangePosMember(null)}>
        <DialogContent>
          <form onSubmit={handleChangePositionSubmit}>
            <DialogHeader>
              <DialogTitle>Сменить должность сотрудника</DialogTitle>
              <DialogDescription>
                Изменение должности мгновенно обновит роли доступа и открытые рабочие экраны.
              </DialogDescription>
            </DialogHeader>

            <div className="py-4 space-y-3">
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Сотрудник</label>
                <div className="text-sm font-semibold">
                  {changePosMember?.first_name || changePosMember?.full_name || changePosMember?.email}
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground">Новая должность</label>
                <select
                  value={newPosition}
                  onChange={(e) => setNewPosition(e.target.value)}
                  className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  {CANONICAL_ROLES_LIST.map((r) => (
                    <option key={r.key} value={r.key}>
                      {r.label}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setChangePosMember(null)}>
                Отмена
              </Button>
              <Button type="submit" disabled={changingPos}>
                {changingPos ? "Сохранение..." : "Сохранить"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
