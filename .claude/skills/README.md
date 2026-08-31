# .claude/skills

25 записей: 5 скиллов написаны под KORKEM, 18 взяты из
[ImL1s/flutter-claude-skills](https://github.com/ImL1s/flutter-claude-skills)
(MIT, © iml1s), 2 — symlink на `.agents/skills/` (Orca, управляются
`skills-lock.json`).

---

## KORKEM-специфичные — читать первыми

| скилл | когда |
|---|---|
| **korkem-architecture** | перед проектированием чего угодно, что трогает бизнес-данные, права, инструменты AI, каналы, личность или хранилище. Десять инвариантов. |
| **korkem-domain-service** | когда добавляете бизнес-действие или вытаскиваете его из `korkem_ai/tools/`. Это рецепт Горизонта 1. |
| **korkem-flutter** | перед любым `.dart`. Перебивает общие советы по Flutter, которые иначе притащат freezed, build_runner и GraphQL — здесь их нет намеренно. |
| **korkem-bench** | запуск стенда, тесты, деплой, отладка «приложение не видит сервер». Отдельный раздел: отказы, которые выглядят как баги и ими не являются. |
| **korkem-docs** | перед написанием любого `.md`. Что авторитетно, что архив, как не расплодить документы заново. |

## Процесс работы

`verification-before-completion` · `systematic-debugging` · `root-cause-tracing`
· `writing-plans` · `executing-plans` · `requesting-code-review` ·
`receiving-code-review`

`verification-before-completion` совпадает с культурой этого репозитория
дословно: ничего не называется проверенным, если не было измерено.

## Качество кода

`test-driven-development` · `testing-anti-patterns` · `defense-in-depth` ·
`condition-based-waiting`

`condition-based-waiting` прямо полезен здесь: Riverpod 3 автоматически
повторяет упавший провайдер, из-за чего тесты на таймаутах врут.

## Flutter

`flutter-unit-testing` · `flutter-integration-testing` ·
`flutter-mobile-debugging` · `flutter-windows-ui-testing` ·
`flutter-background-tasks`

`flutter-windows-ui-testing` пригодится в Горизонте 2, когда появится
Windows-таргет. Сейчас его нет — существуют только `android/` и `linux/`.

## Написание скиллов

`skill-creator` · `writing-skills`

---

## Что отклонено и почему

Отклонённое перечислено, чтобы это не пришлось выяснять заново.

**Весь репозиторий [dagovalsusa/claude-flutter-skills](https://github.com/dagovalsusa/claude-flutter-skills)** —
жёстко завязан на `freezed`, `json_serializable`, `riverpod_generator`,
`build_runner`, GraphQL и приватный пакет `package:aworld/`. Каждый из этих
пунктов **прямо противоречит** `CLAUDE.md` и ADR-0005. Установка сделала бы
хуже: агент начал бы писать генерируемые модели и GraphQL-запросы в проект, где
и то и другое запрещено осознанно и с записанной причиной.

**`flutter-social-login`, `firebase-*`** — построены вокруг Firebase Auth.
Firebase переносит владение личностью и данными в Google, что нарушает
инвариант R6 (данные у клиента). Знания об OAuth оттуда пригодятся в Г3, но
скилл в этом виде опасен.

**`figma-*`, `playwright-*`, `admob-*`, `revenuecat-*`, `kmp`,
`store-screenshot-beautifier`, `brand-guidelines`, `webapp-testing`** —
не относятся к этому продукту.

**`flutter-verify`, `api-contract-testing`, `verify-ui-auto`, `release-app`,
`store-console-playbooks`** — большей частью на китайском и дублируют то, что
уже точнее описано в `korkem-flutter` и `korkem-bench` под конкретные команды
этого репозитория.

**`dispatching-parallel-agents`, `subagent-driven-development`,
`testing-skills-with-subagents`** — многоагентная работа здесь не включена.

**Релизные скиллы** (`macos-notarization`, `mobile-store-upload-cli`,
`fvm-flutter-release`, `apple-appstore-manager`, `release-preflight`) — понадобятся
не раньше публикации в сторы; ставить сейчас значит шуметь. Взять из апстрима,
когда дойдёт до дела.
