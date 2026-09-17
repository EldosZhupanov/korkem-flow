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
  UserCheck
} from "lucide-react";
import { PageHeader } from "@/components/ui/page-header";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingState } from "@/components/ui/loading-state";
import { korkemApi, type StaffMember } from "@/lib/korkem-api";

const POSITION_LABELS: Record<string, string> = {
  manager: "Менеджер по продажам",
  measurer: "Замерщик",
  designer: "Конструктор / Технолог",
  shop_manager: "Начальник цеха",
  cutter: "Раскройщик",
  edge_banding: "Мастер кромления",
  cnc: "Оператор станков ЧПУ",
  painter: "Маляр",
  assembler: "Сборщик мебели",
  installer: "Монтажник на объекте",
  storekeeper: "Кладовщик",
  accountant: "Бухгалтер",
  owner: "Владелец компании",
};

export default function TeamPage() {
  const [members, setMembers] = React.useState<StaffMember[]>([]);
  const [positions, setPositions] = React.useState<{ position: string; roles: string[] }[]>([]);
  const [canInvite, setCanInvite] = React.useState(true);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Invite modal state
  const [inviteOpen, setInviteOpen] = React.useState(false);
  const [inviteEmail, setInviteEmail] = React.useState("");
  const [inviteName, setInviteName] = React.useState("");
  const [invitePosition, setInvitePosition] = React.useState("designer");
  const [inviting, setInviting] = React.useState(false);
  const [inviteError, setInviteError] = React.useState<string | null>(null);

  // Change position modal state
  const [changePosMember, setChangePosMember] = React.useState<StaffMember | null>(null);
  const [newPosition, setNewPosition] = React.useState("");
  const [changingPos, setChangingPos] = React.useState(false);

  // Action status
  const [actingEmail, setActingEmail] = React.useState<string | null>(null);

  const loadTeam = React.useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const [mList, pList, canInv] = await Promise.allSettled([
        korkemApi.getStaffMembers(),
        korkemApi.getPositions(),
        korkemApi.canInvite(),
      ]);

      if (mList.status === "fulfilled") setMembers(mList.value);
      if (pList.status === "fulfilled") {
        setPositions(pList.value);
        if (pList.value.length > 0 && !invitePosition) {
          setInvitePosition(pList.value[0].position);
        }
      }
      if (canInv.status === "fulfilled") setCanInvite(canInv.value);
    } catch (err: any) {
      setError(err.message || "Не удалось загрузить список сотрудников");
    } finally {
      setLoading(false);
    }
  }, [invitePosition]);

  React.useEffect(() => {
    loadTeam();
  }, [loadTeam]);

  async function handleInvite(e: React.FormEvent) {
    e.preventDefault();
    if (!inviteEmail.trim() || !invitePosition) return;

    setInviting(true);
    setInviteError(null);

    try {
      await korkemApi.inviteEmployee({
        email: inviteEmail.trim(),
        first_name: inviteName.trim(),
        position: invitePosition,
      });

      setInviteEmail("");
      setInviteName("");
      setInviteOpen(false);
      await loadTeam();
    } catch (err: any) {
      setInviteError(err.message || "Не удалось отправить приглашение");
    } finally {
      setInviting(false);
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
      await loadTeam();
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
      await loadTeam();
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
        description="Сотрудники мебельной фабрики, их роли, должности и права доступа"
        breadcrumbs={[
          { label: "Обзор", href: "/app" },
          { label: "Команда" },
        ]}
        action={
          <div className="flex gap-2.5">
            <Button
              variant="outline"
              size="sm"
              onClick={() => loadTeam()}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            </Button>
            {canInvite && (
              <Button size="sm" onClick={() => setInviteOpen(true)} className="gap-1.5">
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

      {loading ? (
        <LoadingState message="Загрузка списка команды..." />
      ) : members.length === 0 ? (
        <EmptyState
          icon={Users}
          title="Сотрудники еще не добавлены"
          description="Пригласите конструктора, мастера цеха или замерщика для совместной работы в KORKEM."
          action={
            canInvite ? (
              <Button onClick={() => setInviteOpen(true)}>
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
                  const posLabel = POSITION_LABELS[posKey] || member.designation || posKey;
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

      {/* Invite Dialog */}
      <Dialog open={inviteOpen} onOpenChange={setInviteOpen}>
        <DialogContent>
          <form onSubmit={handleInvite}>
            <DialogHeader>
              <DialogTitle>Пригласить сотрудника</DialogTitle>
              <DialogDescription>
                Укажите рабочий email и выберите должность на производстве. Система автоматически выдаст сотруднику права доступа в ERPNext.
              </DialogDescription>
            </DialogHeader>

            <div className="py-4 space-y-4">
              {inviteError && (
                <div className="flex items-start gap-2 rounded-lg bg-destructive/10 p-3 text-xs text-destructive">
                  <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                  <span>{inviteError}</span>
                </div>
              )}

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground" htmlFor="invite_email">
                  Email сотрудника *
                </label>
                <Input
                  id="invite_email"
                  type="email"
                  placeholder="technologist@mebel.kz"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  disabled={inviting}
                  required
                  autoFocus
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground" htmlFor="invite_name">
                  Имя сотрудника
                </label>
                <Input
                  id="invite_name"
                  type="text"
                  placeholder="Алексей"
                  value={inviteName}
                  onChange={(e) => setInviteName(e.target.value)}
                  disabled={inviting}
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground" htmlFor="invite_pos">
                  Должность на фабрике *
                </label>
                <select
                  id="invite_pos"
                  className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                  value={invitePosition}
                  onChange={(e) => setInvitePosition(e.target.value)}
                  disabled={inviting}
                >
                  {positions.length > 0 ? (
                    positions.map((p) => (
                      <option key={p.position} value={p.position} className="bg-background text-foreground">
                        {POSITION_LABELS[p.position] || p.position}
                      </option>
                    ))
                  ) : (
                    Object.entries(POSITION_LABELS).map(([key, label]) => (
                      <option key={key} value={key} className="bg-background text-foreground">
                        {label}
                      </option>
                    ))
                  )}
                </select>
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setInviteOpen(false)}
                disabled={inviting}
              >
                Отмена
              </Button>
              <Button type="submit" disabled={inviting}>
                {inviting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-1.5" />
                    <span>Отправка...</span>
                  </>
                ) : (
                  <span>Выслать приглашение</span>
                )}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Change Position Dialog */}
      <Dialog open={Boolean(changePosMember)} onOpenChange={(open) => !open && setChangePosMember(null)}>
        <DialogContent>
          <form onSubmit={handleChangePositionSubmit}>
            <DialogHeader>
              <DialogTitle>Сменить должность</DialogTitle>
              <DialogDescription>
                Изменение должности изменит права доступа пользователя {changePosMember?.email} в системе.
              </DialogDescription>
            </DialogHeader>

            <div className="py-4 space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-medium text-foreground" htmlFor="change_pos">
                  Новая должность
                </label>
                <select
                  id="change_pos"
                  className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                  value={newPosition}
                  onChange={(e) => setNewPosition(e.target.value)}
                  disabled={changingPos}
                >
                  {positions.length > 0 ? (
                    positions.map((p) => (
                      <option key={p.position} value={p.position} className="bg-background text-foreground">
                        {POSITION_LABELS[p.position] || p.position}
                      </option>
                    ))
                  ) : (
                    Object.entries(POSITION_LABELS).map(([key, label]) => (
                      <option key={key} value={key} className="bg-background text-foreground">
                        {label}
                      </option>
                    ))
                  )}
                </select>
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setChangePosMember(null)}
                disabled={changingPos}
              >
                Отмена
              </Button>
              <Button type="submit" disabled={changingPos}>
                {changingPos ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-1.5" />
                    <span>Сохранение...</span>
                  </>
                ) : (
                  <span>Обновить должность</span>
                )}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
