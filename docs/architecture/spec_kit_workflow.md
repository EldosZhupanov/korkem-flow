# Spec Kit в KORKEM

Дата: 2026-09-09. Статус: пилот процесса.

## Источники и границы

PROJECT.md, PLAN.md, ROADMAP.md, NOW.md и CLAUDE.md сохраняют свои роли.
[Адаптер](../../.specify/memory/constitution.md) связывает Spec Kit с ними и
задаёт проверку всех R1–R10. Он не является шестым источником продуктовых решений.
Спецификации задач в specs/ — рабочие уточнения со ссылкой на ROADMAP.
Они не заменяют архитектуру и не доказывают наличие функциональности.

## Установка и воспроизведение

Использован официальный [GitHub Spec Kit](https://github.com/github/spec-kit),
релиз v1.0.4; commit и происхождение записаны в
[upstream.json](../../.specify/upstream.json), лицензия — в .specify/LICENSE.
В репозитории только штатные scaffold-файлы, адаптер и overrides, без исходного
репозитория Spec Kit, виртуального окружения и кэша uv.

CLI для обслуживания устанавливается так (Python ≥3.11, uv):

```sh
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@cb610277fdea781fcfa83d20522c2db37c94068d
specify integration status
```

Штатные Bash-скрипты и шаблоны уже в проекте. После clone не нужно повторять
init: это может перезаписать управляемые файлы. При обновлении сначала проверить
новый release, затем diff штатных файлов и сохранение overrides/constitution.
Версии зависимостей CLI разрешает uv; commit фиксирует Spec Kit, но не весь
транзитивный Python lock. CLI не является зависимостью backend или приложения.

Claude: официальные skills .claude/skills/speckit-*/SKILL.md.
Codex: официальные skills .agents/skills/speckit-*/SKILL.md.
Для их автоматического обнаружения может понадобиться новая сессия агента;
в текущей сессии командные инструкции можно читать напрямую.
Не менять CODEX_HOME и не переносить сюда credentials.

## Рабочий цикл

1. Прочитать основной контекст и адаптер. Выбрать один открытый пункт.
2. spec: польза, сценарии, отказы, FR, критерии и baseline.
3. clarify: разрешить вопросы по существующим документам/коду; к владельцу
   выносить только действительно отсутствующее продуктовое решение.
4. plan: существующие сервисы, R1–R10, матрица FR → задача → проверка.
5. tasks и analyze: проверить полноту до кода.
6. implement и converge: фактические проверки, исправление обнаруженного,
   перечень ограничений. Не считать модельный отчёт результатом теста.
7. Обновить NOW/ROADMAP ссылкой на evidence и оценить пользу процесса.

Имена в Claude: /speckit-specify, /speckit-plan, /speckit-tasks,
/speckit-analyze, /speckit-implement, /speckit-converge.
В Codex соответствующие имена skills: $speckit-specify и т.д.
Это инструкции агенту; CLI не реализует бизнес-функции самостоятельно.

Контекст пилота в новой сессии задаётся явно:

```sh
export SPECIFY_FEATURE_DIRECTORY=specs/001-r7-without-llm
.specify/scripts/bash/check-prerequisites.sh --json --require-spec --require-tasks --include-tasks
```

.specify/feature.json — локальный указатель, исключён штатным .gitignore.
Имя BRANCH в JSON штатного helper — идентификатор feature; без Git extension
он не означает, что Git-ветка создана. Не установлены внешние расширения,
Git hooks, issue publishing, фоновые агенты или платные сервисы.

## Пилот

[Г1: реальные действия без LLM](../../specs/001-r7-without-llm/spec.md).
Измерения и ограничения — в [evaluation.md](../../specs/001-r7-without-llm/evaluation.md).
Полный цикл применяется к существенным задачам; мелкому исправлению не нужны
семь новых документов. Один пилот не является статистикой ускорения разработки.
