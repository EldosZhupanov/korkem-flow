# NOW.md

**Обновлено:** 2026-08-31

Один экран: что делается прямо сейчас, что сломано, чего не трогать.
Этот файл переписывается по ходу работы — история живёт в git, не здесь.

---

## Текущий горизонт

**Г0 — Инженерный фундамент** (`ROADMAP.md`). Ничего из Г1+ не начинать, пока
Г0 не закрыт: без CI и потолка расходов остальное строится вслепую.

## Следующий шаг, конкретно

**Починить подготовку фикстур.** Три класса тестов падают на чистом volume:

```
MySQLdb.IntegrityError: (1062, "Duplicate entry 'Standard Buying' for key 'PRIMARY'")
  raised in setUpClass of:
    korkem_ai.korkem_ai.doctype.agent_conversation.test_agent_conversation
    korkem_ai.korkem_ai.doctype.agent_conversation_message.test_agent_conversation_message
    korkem_ai.korkem_ai.doctype.pending_action.test_pending_action
```

Причина — фикстура создаёт `Price List "Standard Buying"`, который уже создан
установкой ERPNext. Искать в `korkem_ai/install.py:before_tests` и в
`korkem_manufacturing/seed_demo.py` (`seed_buying`, `BUYING_LIST`).

Проверять командой из скилла `korkem-bench`, вывод вставлять в отчёт целиком —
не «прошло», а сколько именно.

---

## Состояние на последний замер

Замер снят с живого стенда `korkem-backend-verify-fixed` 2026-08-31.

| | |
|---|---|
| `korkem_manufacturing` | **13 / 13** ✅ |
| `korkem_ai` | **992 теста · 983 прошли · 9 skip · 3 ошибки** ❌ |
| Flutter | 317 объявленных тестов, **в этой ревизии не запускались** |
| CI | отсутствует |
| Прогон бэкенда | ~26 минут |

Ветка: `dev`. Последний коммит: `973623b feat(pilot)`, 2026-08-17.

---

## Незакоммиченное в рабочем дереве

- `CLAUDE.md` — переписан под новую структуру документации
- `PLAN.md`, `ROADMAP.md`, `NOW.md` — новые
- `docs/` — реструктурирован: `architecture/`, `operations/`, `product/`, `archive/`
- `.ai/` — расформирован, содержимое перенесено в `docs/`
- `agents/`, `prompts/`, `telegram/`, `frontend/` — удалены (были пустыми
  заглушками; код живёт в `backend/korkem_ai/`)
- `.claude/skills/` — 18 внешних скиллов + 5 KORKEM-специфичных

**Ничего из этого ещё не закоммичено.** Коммитить по частям, не одним куском.

---

## Чего не трогать

- **Вендорные `erpnext/`, `frappe/`, `crm/`, `relaticle/`** — отдельные
  репозитории, должны оставаться чистыми. После любой пересборки:
  `git -C <repo> status` и откатить лишнее.
- **`backend/korkem_ai/` и `backend/korkem_manufacturing/`** — тоже отдельные
  git-репозитории. Коммитить внутри них, не из корня.
- **Регрессионный тест на `signIn` без `AsyncValue.loading()`** — он держит
  реальный баг, из-за которого любая ошибка входа выглядела как пустая форма.
- **Глобальный teardown каналов** — удаляет `Notification Delivery` и
  `Channel Event` целиком. Любую проверку снимать **до** следующего прогона.

---

## Открытые вопросы к владельцу

Блокируют планирование, не код. Полный список — `ROADMAP.md`.

1. **Кто клиент первого релиза** — обобщённая фабрика или KORKEM с фасадами?
   От этого зависит, идёт ли Г8 раньше Г7.
2. **Форма поставки узла** — mini-PC, NAS или WSL2 на машине владельца?
   Блокирует весь Г2. `PLAN.md` §3.2 объясняет, почему это нельзя обойти.
3. **Ingress** — Caddy или Cloudflare Tunnel?

---

## С чего начинает новый агент

```
NOW.md        ← вы здесь
ROADMAP.md    какой горизонт
PLAN.md       какой инвариант нельзя нарушить
CLAUDE.md     как здесь работают
```

И перед кодом — скилл под задачу: `korkem-architecture`,
`korkem-domain-service`, `korkem-flutter`, `korkem-bench`, `korkem-docs`.
