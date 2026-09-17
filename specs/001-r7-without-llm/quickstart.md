# Воспроизведение

Предусловия: локальный development-стенд korkem-clean-bench-1 поднят,
оба custom apps установлены. Не запускать параллельно с другой bench-операцией.

Из корня:

```sh
export SPECIFY_FEATURE_DIRECTORY=specs/001-r7-without-llm
.specify/scripts/bash/check-prerequisites.sh --json --require-spec --require-tasks --include-tasks
infra/frappe_bench/scripts/run_tests.sh --module korkem_manufacturing.test_without_llm
infra/frappe_bench/scripts/run_tests.sh --module korkem_manufacturing.test_without_llm
infra/frappe_bench/scripts/run_tests.sh korkem_manufacturing
git diff --check
```

Ожидается: exit 0, без ошибок и пропусков в R7-модуле. Точные результаты
фиксируются после прогона в evaluation.md. Настоящие LLM-ключи не нужны.

Это integration test API-функций, не HTTP/device E2E. Для проверки пользовательского
интерфейса на устройстве понадобится отдельная приёмка.
