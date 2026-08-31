# KORKEM Flow

Локальная операционная система мебельного предприятия. Производственные данные
остаются у клиента; управление идёт через пять равноправных интерфейсов —
Desktop, мобильное приложение, терминал цеха, Telegram/WhatsApp и AI-ассистент —
поверх одного Service API.

---

## Читать в этом порядке

| файл | вопрос |
|---|---|
| **[NOW.md](./NOW.md)** | что делается прямо сейчас и что сломано |
| **[ROADMAP.md](./ROADMAP.md)** | что строим, в каком порядке, зачем |
| **[PLAN.md](./PLAN.md)** | целевая архитектура и десять инвариантов |
| **[PROJECT.md](./PROJECT.md)** | чем продукт является и не является |
| **[CLAUDE.md](./CLAUDE.md)** | как здесь работает AI-агент |

Эти пять — источник правды. Если документ в `docs/` им противоречит,
правы они. Если код противоречит всем — прав код, а документ надо исправить.

## Что где лежит

```
backend/
  korkem_manufacturing/   доменный слой: бизнес-правила и Service API
  korkem_ai/              оркестратор LLM, инструменты, каналы, уведомления
mobile/korkem_flow/       Flutter: Android + Linux (Windows — Г2)
infra/frappe_bench/       Docker Compose: dev, pilot, public
scripts/                  deploy_pilot.sh
docs/
  architecture/           ADR, доменная модель, дизайн-система
  operations/             развёртывание, бэкапы, релиз, приватность
  product/                спецификация заказчика
  archive/                история. НЕ описание системы сегодня.
.claude/skills/           23 скилла: 5 KORKEM-специфичных + 18 внешних
erpnext/ frappe/ crm/ relaticle/   вендорные, отдельные git-репозитории
```

## Быстрый старт

```sh
cp infra/frappe_bench/.env.example infra/frappe_bench/.env   # заполнить
docker compose -f infra/frappe_bench/docker-compose.yml up -d
# → http://korkem.localhost:8000

cd mobile/korkem_flow && flutter pub get
flutter run -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000
```

Подробности и ловушки, которые выглядят как баги, — скилл `korkem-bench`.

## Проверка

```sh
# бэкенд, ~26 минут
docker compose -f infra/frappe_bench/docker-compose.yml exec -T bench bash -o pipefail -lc \
  'cd /home/frappe/frappe-bench && bench --site korkem.localhost run-tests --app korkem_ai 2>&1 | tee /tmp/korkem-ai-test.log'

# мобильное
cd mobile/korkem_flow
flutter analyze && dart format --set-exit-if-changed lib test && flutter test
```

## Лицензии

`.claude/skills/` содержит скиллы, взятые из
[ImL1s/flutter-claude-skills](https://github.com/ImL1s/flutter-claude-skills)
(MIT). Список принятых и отклонённых — `.claude/skills/README.md`.
