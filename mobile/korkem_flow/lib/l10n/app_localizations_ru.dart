// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'KORKEM Flow';

  @override
  String get filterNoResults => 'По этому фильтру ничего нет.';

  @override
  String get actionClearHistory => 'Очистить историю';

  @override
  String get actionClearSearch => 'Очистить поиск';

  @override
  String get actionRefresh => 'Обновить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionClearFilter => 'Сбросить фильтр';

  @override
  String get actionFilter => 'Фильтр';

  @override
  String get actionSelectAll => 'Все';

  @override
  String get errorGeneric => 'Что-то пошло не так.';

  @override
  String get errorOffline => 'Нет связи с сервером.';

  @override
  String get outboxQueued => 'Нет связи. Команда ждёт отправки.';

  @override
  String outboxPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count команды ждут отправки',
      many: '$count команд ждут отправки',
      few: '$count команды ждут отправки',
      one: '$count команда ждёт отправки',
    );
    return '$_temp0';
  }

  @override
  String get outboxRetry => 'Отправить сейчас';

  @override
  String outboxRejected(String reason) {
    return 'Команда из очереди отклонена: $reason';
  }

  @override
  String get errorNoAccess => 'У вас нет доступа к этому разделу.';

  @override
  String get errorNotFound => 'Не найдено.';

  @override
  String get emptyTitle => 'Здесь пока пусто';

  @override
  String get emptyGeneric => 'Новые записи появятся здесь автоматически.';

  @override
  String get searchHint => 'Поиск';

  @override
  String searchNoResults(String query) {
    return 'Ничего не найдено по запросу «$query»';
  }

  @override
  String semanticStatus(String status) {
    return 'Статус: $status';
  }

  @override
  String get navDeals => 'Сделки';

  @override
  String get navTasks => 'Задачи';

  @override
  String get navProfile => 'Профиль';

  @override
  String get tasksOverdue => 'Просрочено';

  @override
  String get tasksToday => 'Сегодня';

  @override
  String get tasksUpcoming => 'Предстоящие';

  @override
  String get tasksEmpty => 'Нет открытых задач';

  @override
  String get tasksEmptyBody => 'Назначенная работа появится здесь.';

  @override
  String get taskComplete => 'Завершить';

  @override
  String get taskCompleted => 'Задача завершена';

  @override
  String taskCompleteFailed(String reason) {
    return 'Не удалось завершить задачу. $reason';
  }

  @override
  String taskForeignAssigneeExplanation(String assignee) {
    return 'Задача: $assignee. Закрыть может исполнитель или старший смены';
  }

  @override
  String get actionUndo => 'Отменить';

  @override
  String get taskProduction => 'Производство';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileAppearance => 'Оформление';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileVersion => 'Версия';

  @override
  String get themeSystem => 'Системная';

  @override
  String get languageSystem => 'Язык устройства';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get profileServer => 'Сервер';

  @override
  String get taskPriorityHigh => 'Высокий приоритет';

  @override
  String get authSubtitle => 'Подключитесь к рабочему пространству KORKEM';

  @override
  String get authServer => 'Адрес сервера';

  @override
  String get authServerHint => 'korkem.example.kz';

  @override
  String get authEmail => 'Электронная почта';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authShowPassword => 'Показать пароль';

  @override
  String get authHidePassword => 'Скрыть пароль';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authSignOut => 'Выйти';

  @override
  String get authSignOutConfirm => 'Выйти на этом устройстве?';

  @override
  String get authSignOutBody =>
      'Чтобы войти снова, понадобятся адрес сервера и пароль.';

  @override
  String get authFieldRequired => 'Обязательное поле';

  @override
  String get authInvalidServer => 'Некорректный адрес.';

  @override
  String get authRegister => 'Регистрация';

  @override
  String get authNoAccount => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get authAlreadyHaveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get authRegisterSubtitle =>
      'Создайте рабочее пространство для вашего мебельного цеха';

  @override
  String get authCompanyName => 'Название компании / цеха';

  @override
  String get authCompanyNameHint => 'Например: Мебель Астана, ИП Марат';

  @override
  String get authOwnerName => 'Ваше имя';

  @override
  String get authOwnerNameHint => 'Имя и фамилия';

  @override
  String get authConfirmPassword => 'Повторите пароль';

  @override
  String get authPasswordsDoNotMatch => 'Пароли не совпадают.';

  @override
  String get authPasswordTooShort => 'Пароль должен быть не менее 6 символов.';

  @override
  String get authCustomServer => 'Настройки сервера';

  @override
  String get authHideServer => 'Скрыть настройки сервера';

  @override
  String get claimTitle => 'Первый запуск';

  @override
  String get claimSubtitle => 'Создание компании и учётной записи владельца';

  @override
  String get claimCode => 'Код первого запуска';

  @override
  String get claimCodeHint => '16 символов из журнала узла';

  @override
  String get claimCodeHelper =>
      'Код показан в терминале узла при первом запуске';

  @override
  String get claimCompany => 'Название компании';

  @override
  String get claimOwnerName => 'Имя владельца';

  @override
  String get claimOwnerEmail => 'Электронная почта владельца';

  @override
  String get claimOwnerPassword => 'Пароль владельца';

  @override
  String get claimConfirmPassword => 'Подтверждение пароля';

  @override
  String get claimPasswordMismatch => 'Пароли не совпадают';

  @override
  String get claimLanguage => 'Язык системы';

  @override
  String get claimSubmit => 'Создать компанию';

  @override
  String get claimAlreadyClaimed =>
      'Этот узел уже занят. Попросите у владельца приглашение';

  @override
  String get claimCodeRefused =>
      'Неверный код. Он показан в журнале узла при запуске';

  @override
  String get claimNodeUnconfiguredBanner =>
      'Этот узел ожидает настройки. Вы можете создать компанию и стать её владельцем.';

  @override
  String get claimSetupCompanyAction => 'Настроить компанию';

  @override
  String get claimLangRu => 'Русский';

  @override
  String get claimLangKk => 'Қазақша';

  @override
  String get claimLangEn => 'English';

  @override
  String get adminStatsTitle => 'Цифровой администратор';

  @override
  String get adminStatsSubtitle =>
      'Доказательство ценности: результат работы без найма человека';

  @override
  String get adminStatsPeriodWeek => 'Неделя';

  @override
  String get adminStatsPeriodMonth => 'Месяц';

  @override
  String get adminStatsPeriodQuarter => '3 месяца';

  @override
  String get adminStatsStaleHeroLabel => 'ТРЕБУЕТ ВНИМАНИЯ: ПРОТУХЛО';

  @override
  String adminStatsStaleHeroText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count обращений не переданы в работу более 24 часов',
      few: '$count обращения не переданы в работу более 24 часов',
      one: '1 обращение не передано в работу более 24 часов',
    );
    return '$_temp0';
  }

  @override
  String get adminStatsZeroStaleHeroLabel => 'ОТЛИЧНЫЙ РЕЗУЛЬТАТ';

  @override
  String adminStatsZeroStaleHeroText(int days) {
    return 'За $days дней не потеряно ни одного обращения';
  }

  @override
  String get adminStatsZeroStaleHeroSub =>
      'Все зафиксированные обращения вовремя переданы человеку или закрыты';

  @override
  String get adminStatsEmptyTitle => 'Пока ничего не поймано';

  @override
  String get adminStatsEmptyMessage =>
      'За выбранный период не зафиксировано обращений. Новые сообщения из каналов и мессенджеров появятся здесь.';

  @override
  String get adminStatsCaught => 'Поймано обращений';

  @override
  String get adminStatsCaughtHelper => 'Всего зафиксировано системой';

  @override
  String get adminStatsHandedOver => 'Передано человеку';

  @override
  String get adminStatsHandedOverHelper => 'Созданы задачи сотрудникам';

  @override
  String get adminStatsConverted => 'Стало заказами';

  @override
  String get adminStatsConvertedHelper => 'Доведено до договора и оплаты';

  @override
  String get adminStatsDismissed => 'Отброшено осознанно';

  @override
  String get adminStatsDismissedHelper => 'Спам или отказ клиента';

  @override
  String get adminStatsStaleMetric => 'Протухло (без задачи)';

  @override
  String get adminStatsStaleMetricHelper => 'Висят без исполнителя >24ч';

  @override
  String get adminStatsSummaryTitle => 'Итог для решения о найме';

  @override
  String adminStatsSummaryText(int caught, int converted, int stale) {
    return 'Система обработала $caught обращений. $converted принесли заказы, $stale требуют внимания.';
  }

  @override
  String get adminStatsRetry => 'Повторить попытку';

  @override
  String get teamTitle => 'Команда';

  @override
  String get teamSubtitle => 'Сотрудники компании и их должности';

  @override
  String get teamInviteButton => 'Пригласить сотрудника';

  @override
  String get teamInviteTitle => 'Пригласить сотрудника';

  @override
  String get teamInviteSubtitle =>
      'Выберите должность и укажите почту для доступа';

  @override
  String get teamEmailLabel => 'Электронная почта';

  @override
  String get teamEmailHint => 'worker@company.kz';

  @override
  String get teamEmailError => 'Введите корректный адрес почты';

  @override
  String get teamFirstNameLabel => 'Имя сотрудника';

  @override
  String get teamFirstNameHint => 'Айдос';

  @override
  String get teamPositionLabel => 'Должность';

  @override
  String get teamPositionManager => 'Менеджер';

  @override
  String get teamPositionManagerDesc => 'Отдел продаж, клиенты, сделки';

  @override
  String get teamPositionWarehouse => 'Кладовщик';

  @override
  String get teamPositionWarehouseDesc => 'Склад, остатки, приёмка материалов';

  @override
  String get teamPositionAccountant => 'Бухгалтер';

  @override
  String get teamPositionAccountantDesc => 'Счета, оплаты, финансовые отчёты';

  @override
  String get teamPositionShopFloor => 'Рабочий цеха';

  @override
  String get teamPositionShopFloorDesc =>
      'Станки, сменные задания, отчёты о работе';

  @override
  String get teamPositionMeasurer => 'Замерщик';

  @override
  String get teamPositionMeasurerDesc =>
      'Выезжает к клиенту, снимает размеры и фото';

  @override
  String get teamPositionDesigner => 'Конструктор-дизайнер';

  @override
  String get teamPositionDesignerDesc =>
      'Чертёж, спецификация, выгрузка из БАЗИС';

  @override
  String get teamPositionShopManager => 'Начальник цеха';

  @override
  String get teamPositionShopManagerDesc =>
      'Распределяет работу и следит за сроками';

  @override
  String get teamPositionCutter => 'Раскройщик';

  @override
  String get teamPositionCutterDesc => 'Распил ЛДСП и плитных материалов';

  @override
  String get teamPositionEdgeBanding => 'Кромщик';

  @override
  String get teamPositionEdgeBandingDesc => 'Кромкооблицовочный станок';

  @override
  String get teamPositionCnc => 'Оператор ЧПУ';

  @override
  String get teamPositionCncDesc => 'Присадка и фрезеровка';

  @override
  String get teamPositionPainter => 'Маляр';

  @override
  String get teamPositionPainterDesc => 'Покраска и покрытие';

  @override
  String get teamPositionAssembler => 'Сборщик';

  @override
  String get teamPositionAssemblerDesc => 'Сборка и упаковка изделия';

  @override
  String get teamPositionInstaller => 'Монтажник';

  @override
  String get teamPositionInstallerDesc => 'Доставка и установка у клиента';

  @override
  String get teamPositionOwner => 'Владелец';

  @override
  String get teamPositionOwnerDesc => 'Полный доступ к управлению предприятием';

  @override
  String get teamEmptyTitle => 'Пока вы один';

  @override
  String get teamEmptyMessage =>
      'Пригласите сотрудников цеха, склада или отдела продаж, чтобы распределять задачи и контролировать производство.';

  @override
  String get teamInviteSuccess => 'Приглашение отправлено';

  @override
  String get teamInviteSuccessTitle => 'Сотрудник приглашён';

  @override
  String teamInviteSuccessDetail(String name, String position) {
    return 'Сотрудник $name добавлен с должностью «$position»';
  }

  @override
  String get teamNextStepTitle => 'Следующий шаг';

  @override
  String get teamPasswordNotSet => 'Пароль не установлен';

  @override
  String get teamPositionsLoading => 'Загрузка должностей...';

  @override
  String get teamPositionsLoadError => 'Не удалось загрузить список должностей';

  @override
  String get teamForbiddenTitle => 'Только для владельца';

  @override
  String get teamForbiddenMessage =>
      'Приглашать новых сотрудников и назначать должности может только владелец компании.';

  @override
  String get teamSendInvite => 'Отправить приглашение';

  @override
  String get teamSectionMembers => 'Сотрудники';

  @override
  String get teamChangePositionTitle => 'Сменить должность';

  @override
  String get teamChangePositionAction => 'Сменить должность';

  @override
  String get teamSavePosition => 'Сохранить должность';

  @override
  String teamChangePositionSuccess(String name, String position) {
    return 'Должность сотрудника $name изменена на «$position»';
  }

  @override
  String get teamDeactivateAction => 'Закрыть доступ';

  @override
  String get teamDeactivateDialogTitle => 'Закрыть доступ?';

  @override
  String teamDeactivateConfirmMessage(String name) {
    return 'Закрыть доступ сотруднику $name? Человек потеряет доступ к системе и будут завершены все открытые сеансы работы.';
  }

  @override
  String get teamDeactivateConfirmButton => 'Закрыть доступ';

  @override
  String teamDeactivateSuccess(int count) {
    return 'Доступ закрыт, завершено сеансов: $count';
  }

  @override
  String get teamReactivateAction => 'Вернуть доступ';

  @override
  String get teamReactivateDialogTitle => 'Вернуть доступ?';

  @override
  String teamReactivateConfirmMessage(String name) {
    return 'Вернуть доступ сотруднику $name?';
  }

  @override
  String get teamReactivateConfirmButton => 'Вернуть доступ';

  @override
  String get teamReactivateSuccess => 'Доступ возвращён';

  @override
  String get teamStatusDisabled => 'Доступ закрыт';

  @override
  String get teamStatusActive => 'Активен';

  @override
  String get teamSectionDisabled => 'Отключённые сотрудники';

  @override
  String get teamCannotModifySelf =>
      'Нельзя изменить собственную должность или закрыть себе доступ';

  @override
  String get settingsTeamTitle => 'Команда и сотрудники';

  @override
  String get settingsTeamSubtitle =>
      'Приглашение сотрудников и выбор должностей';

  @override
  String get companyDetailsTitle => 'Реквизиты компании';

  @override
  String get companyDetailsSubtitle => 'Адрес, БИН и банковские реквизиты';

  @override
  String get warehousesSettingsTitle => 'Склады';

  @override
  String get warehousesSettingsSubtitle => 'Места хранения и склад отгрузки';

  @override
  String get warehousesTitle => 'Склады';

  @override
  String get warehousesSubtitle =>
      'Места хранения и склад отгрузки готовой продукции';

  @override
  String get warehousesTipTitle => 'Как сменить имя склада в документах';

  @override
  String get warehousesTipBody =>
      'В ERPNext нельзя переименовать склад напрямую. Чтобы в накладных стояло понятное имя: заведите свой склад с нужным названием → назначьте его складом отгрузки → отключите английский Finished Goods.';

  @override
  String get warehousesSectionActive => 'Склады';

  @override
  String get warehousesSectionDisabled => 'Отключённые склады';

  @override
  String get warehousesShippingDefaultBadge => 'Склад отгрузки';

  @override
  String get warehousesStatusDisabled => 'Отключён';

  @override
  String warehousesPositionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count позиций',
      few: '$count позиции',
      one: '$count позиция',
    );
    return '$_temp0';
  }

  @override
  String get warehousesActionSetShippingDefault => 'Сделать складом отгрузки';

  @override
  String get warehousesActionDisable => 'Отключить склад';

  @override
  String get warehousesActionEnable => 'Включить склад';

  @override
  String get warehousesCreateButton => 'Новый склад';

  @override
  String get warehousesCreateDialogTitle => 'Новый склад';

  @override
  String get warehousesCreateDialogSubtitle =>
      'Второй цех, арендованное помещение, машина';

  @override
  String get warehousesNameLabel => 'Название склада';

  @override
  String get warehousesNameHint => 'напр. Склад материалов';

  @override
  String get warehousesNameError => 'Введите название склада';

  @override
  String warehousesCreateSuccess(String name) {
    return 'Склад «$name» создан';
  }

  @override
  String warehousesSetShippingDefaultSuccess(String name) {
    return 'Склад «$name» назначен складом отгрузки';
  }

  @override
  String get warehousesDisableDialogTitle => 'Отключить склад?';

  @override
  String warehousesDisableDialogMessage(String name) {
    return 'Отключить склад «$name»? Склад перестанет предлагаться в новых документах, история остатков сохранится.';
  }

  @override
  String warehousesDisableSuccess(String name) {
    return 'Склад «$name» отключён';
  }

  @override
  String get warehousesEnableDialogTitle => 'Включить склад?';

  @override
  String warehousesEnableDialogMessage(String name) {
    return 'Включить склад «$name»? Он снова станет доступен для выбора в складских документах.';
  }

  @override
  String warehousesEnableSuccess(String name) {
    return 'Склад «$name» включён';
  }

  @override
  String get warehousesEmptyTitle => 'Склады не найдены';

  @override
  String get warehousesEmptyMessage => 'Список складов компании пуст.';

  @override
  String get bazisImportTitle => 'Спецификация из БАЗИС';

  @override
  String get bazisImportSubtitle =>
      'Проверка выгрузки и создание спецификации изделия';

  @override
  String get bazisPickFileAction => 'Выбрать файл БАЗИС';

  @override
  String get bazisChangeFileAction => 'Выбрать другой файл';

  @override
  String get bazisPickFileHint =>
      'XML-выгрузка проекта из БАЗИС-Мебельщик (.xml)';

  @override
  String bazisTotalsSummary(
    int products,
    int parts,
    int materials,
    int operations,
  ) {
    return 'Изделий: $products · Деталей: $parts · Материалов: $materials · Операций: $operations';
  }

  @override
  String get bazisCreateSpecificationAction => 'Создать спецификацию';

  @override
  String get bazisCreatingSpecification => 'Создание спецификации…';

  @override
  String get bazisInspectingFile => 'Чтение выгрузки…';

  @override
  String get bazisProductLabel => 'Изделие';

  @override
  String bazisArticleLabel(String article) {
    return 'Артикул: $article';
  }

  @override
  String bazisOrderLabel(String order) {
    return 'Заказ: $order';
  }

  @override
  String bazisPriceLabel(String price) {
    return 'Цена: $price';
  }

  @override
  String bazisQtyLabel(String qty) {
    return '$qty шт.';
  }

  @override
  String bazisPartsTab(int count) {
    return 'Детали ($count)';
  }

  @override
  String bazisMaterialsTab(int count) {
    return 'Материалы ($count)';
  }

  @override
  String bazisOperationsTab(int count) {
    return 'Операции ($count)';
  }

  @override
  String bazisPartBlockLabel(String block) {
    return 'Блок: $block';
  }

  @override
  String bazisPartDimensions(String length, String width, String thickness) {
    return '$length × $width × $thickness мм';
  }

  @override
  String bazisPartEdges(String edges) {
    return 'Кромка: $edges';
  }

  @override
  String bazisMaterialUnitQty(String qty, String unit) {
    return '$qty $unit';
  }

  @override
  String bazisOperationMinutes(String minutes) {
    return '$minutes мин.';
  }

  @override
  String get bazisBomStatusCreated => 'Спецификация создана';

  @override
  String get bazisBomStatusUpdated => 'Черновик спецификации обновлён';

  @override
  String get bazisMaterialsWithoutQtyAlert =>
      'Материалы без расчёта количества (не вошли в спецификацию):';

  @override
  String get bazisOperationsAwaitingWorkstationAlert =>
      'Операции без назначенного рабочего места (внесены в справочник, но не включены в маршрут):';

  @override
  String get bazisImportSuccessTitle => 'Спецификация готова';

  @override
  String get bazisImportAnotherAction => 'Загрузить другую выгрузку';

  @override
  String bazisBomDocLabel(String bom) {
    return 'Спецификация BOM: $bom';
  }

  @override
  String bazisItemDocLabel(String item) {
    return 'Номенклатура: $item';
  }

  @override
  String get bazisEmptyParts => 'В изделии нет деталей';

  @override
  String get bazisEmptyMaterials => 'В изделии нет материалов';

  @override
  String get bazisEmptyOperations => 'В изделии нет технологических операций';

  @override
  String get integrationsTitle => 'Интеграции';

  @override
  String get integrationsSubtitle => 'Ключи TrustMe и Kaspi Pay';

  @override
  String get integrationsSecurityNote =>
      'Это ключи вашей компании. Они хранятся в зашифрованном виде на вашем сервере и наружу не передаются.';

  @override
  String get trustmeTitle => 'TrustMe';

  @override
  String get trustmeSubtitle => 'Электронное подписание договоров';

  @override
  String get trustmeBinLabel => 'БИН организации';

  @override
  String get trustmeBinHint => '12 цифр';

  @override
  String get trustmeApiTokenLabel => 'API-токен';

  @override
  String get trustmeApiTokenHint => 'Введите новый токен для изменения';

  @override
  String get trustmeWebhookSecretLabel => 'Секрет вебхука (Webhook Secret)';

  @override
  String get trustmeWebhookSecretHint => 'Введите новый секрет для изменения';

  @override
  String get kaspiTitle => 'Kaspi Pay';

  @override
  String get kaspiSubtitle => 'Приём оплаты и выставление счетов';

  @override
  String get kaspiMerchantIdLabel => 'ID мерчанта / Точки';

  @override
  String get kaspiMerchantIdHint => 'Идентификатор в Kaspi Pay';

  @override
  String get kaspiApiKeyLabel => 'API-ключ';

  @override
  String get kaspiApiKeyHint => 'Введите новый ключ для изменения';

  @override
  String get kaspiWebhookSecretLabel => 'Секрет вебхука (Webhook Secret)';

  @override
  String get kaspiWebhookSecretHint => 'Введите новый секрет для изменения';

  @override
  String get integrationSecretConfigured => 'Ключ задан';

  @override
  String get integrationSecretNotConfigured => 'Ключа нет';

  @override
  String get integrationClearSecretAction => 'Удалить';

  @override
  String get integrationSaveAction => 'Сохранить';

  @override
  String get integrationSavedSuccess => 'Настройки сохранены';

  @override
  String get integrationClearDialogTitle => 'Удалить ключ?';

  @override
  String integrationClearDialogMessage(String secretName, String providerName) {
    return 'Удалить $secretName? Интеграция $providerName перестанет работать до ввода нового ключа.';
  }

  @override
  String get integrationClearSuccess => 'Ключ удалён';

  @override
  String integrationLastStatusLabel(String status) {
    return 'Статус: $status';
  }

  @override
  String integrationLastErrorLabel(String error) {
    return 'Ошибка: $error';
  }

  @override
  String integrationLastCheckedLabel(String date) {
    return 'Проверено: $date';
  }

  @override
  String get integrationEnableToggle => 'Включить интеграцию';

  @override
  String get companyDetailsDocNote =>
      'Реквизиты используются для формирования договоров, счетов и накладных.';

  @override
  String get companyDetailsSectionGeneral => 'Основные данные';

  @override
  String get companyDetailsNameLabel => 'Наименование компании';

  @override
  String get companyDetailsNameHint => 'ТОО «Көркем Жиһаз»';

  @override
  String get companyDetailsBinLabel => 'БИН';

  @override
  String get companyDetailsBinHint => '12 цифр';

  @override
  String get companyDetailsBinError => 'БИН должен содержать ровно 12 цифр';

  @override
  String get companyDetailsSectionContacts => 'Контакты и адрес';

  @override
  String get companyDetailsCityLabel => 'Город';

  @override
  String get companyDetailsCityHint => 'Алматы';

  @override
  String get companyDetailsAddressLabel => 'Юридический адрес';

  @override
  String get companyDetailsAddressHint => 'ул. Абая, 150, офис 401';

  @override
  String get companyDetailsPhoneLabel => 'Телефон';

  @override
  String get companyDetailsPhoneHint => '+7 777 123 45 67';

  @override
  String get companyDetailsEmailLabel => 'Электронная почта';

  @override
  String get companyDetailsEmailHint => 'info@korkem.kz';

  @override
  String get companyDetailsEmailError => 'Введите корректный адрес почты';

  @override
  String get companyDetailsWebsiteLabel => 'Веб-сайт';

  @override
  String get companyDetailsWebsiteHint => 'korkem.kz';

  @override
  String get companyDetailsReadOnlyNameNotice =>
      'Название компании задаётся при создании и меняется в профиле компании';

  @override
  String get companyDetailsSectionBank => 'Банковские реквизиты';

  @override
  String get companyDetailsBankNameLabel => 'Наименование банка';

  @override
  String get companyDetailsBankNameHint => 'АО «Kaspi Bank»';

  @override
  String get companyDetailsIbanLabel => 'Расчётный счёт (IBAN)';

  @override
  String get companyDetailsIbanHint => 'KZ...';

  @override
  String get companyDetailsIbanHelper =>
      'Формат: KZ и 18 знаков (например, KZ69...)';

  @override
  String get companyDetailsIbanError =>
      'IBAN Казахстана должен начинаться с KZ и содержать 20 символов';

  @override
  String get companyDetailsBikLabel => 'БИК банка';

  @override
  String get companyDetailsBikHint => 'CASPKZ2A';

  @override
  String get companyDetailsBikError =>
      'БИК должен содержать от 8 до 11 символов';

  @override
  String get companyDetailsSaveButton => 'Сохранить реквизиты';

  @override
  String get companyDetailsSaveSuccess => 'Реквизиты успешно сохранены';

  @override
  String get companyDetailsLoadError =>
      'Не удалось загрузить реквизиты компании';

  @override
  String get itemsTitle => 'Номенклатура и цены';

  @override
  String get itemsSubtitle => 'Каталог изделий, единицы измерения и цены';

  @override
  String get itemsSearchHint => 'Поиск по названию или коду';

  @override
  String get itemsEmptyTitle => 'В каталоге пока нет позиций';

  @override
  String get itemsEmptyMessage => 'Добавьте первую позицию номенклатуры';

  @override
  String get itemsAddItem => 'Добавить позицию';

  @override
  String get itemsCreateTitle => 'Новая позиция';

  @override
  String get itemsNameLabel => 'Название позиции';

  @override
  String get itemsNameHint => 'Шкаф распашной двухдверный';

  @override
  String get itemsNameRequired => 'Введите название позиции';

  @override
  String get itemsCodeLabel => 'Код / артикул (необязательно)';

  @override
  String get itemsCodeHint => 'CAB-01';

  @override
  String get itemsUnitLabel => 'Единица измерения';

  @override
  String get itemsUnitHint => 'Выберите единицу';

  @override
  String get itemsUnitRequired => 'Единица измерения обязательна';

  @override
  String get itemsDescriptionLabel => 'Описание';

  @override
  String get itemsDescriptionHint => 'Материалы, фурнитура, особенности';

  @override
  String get itemsPriceLabel => 'Цена продажи (необязательно)';

  @override
  String get itemsPriceHint => '0 ₸';

  @override
  String get itemsPriceOnRequest => 'Цена по расчёту';

  @override
  String get itemsPriceLabelShort => 'Цена';

  @override
  String get itemsSetPriceTitle => 'Изменить цену';

  @override
  String get itemsSetPriceAction => 'Установить цену';

  @override
  String get itemsPriceRequired => 'Укажите цену';

  @override
  String get itemsPriceInvalid => 'Некорректная сумма';

  @override
  String get itemsPriceUpdated => 'Цена обновлена';

  @override
  String get itemsCreateSuccess => 'Позиция добавлена';

  @override
  String get itemsUnitsLoading => 'Загрузка единиц...';

  @override
  String get itemsUnitsLoadError => 'Не удалось загрузить единицы измерения';

  @override
  String get itemsCatalogAction => 'Каталог позиций';

  @override
  String get navItems => 'Номенклатура';

  @override
  String get settingsEnquiryFlowTitle => 'Проводка заявки';

  @override
  String get settingsEnquiryFlowSubtitle =>
      'Цепочка от первого обращения до заказа в цех';

  @override
  String get enquiryFlowTitle => 'Проводка заявки';

  @override
  String get enquiryFlowSubtitle =>
      'Цепочка от первого обращения до заказа в цех';

  @override
  String get enquiryFlowStep1 => 'Заявка';

  @override
  String get enquiryFlowStep2 => 'Замер';

  @override
  String get enquiryFlowStep3 => 'КП';

  @override
  String get enquiryFlowStep4 => 'Заказ';

  @override
  String get enquiryFlowSelectCapture => 'Выберите обращение для проводки';

  @override
  String get enquiryFlowSpokenText => 'Со слов клиента';

  @override
  String get enquiryFlowCustomerName => 'Имя клиента';

  @override
  String get enquiryFlowAssignMeasurer => 'Назначить замерщика';

  @override
  String get enquiryFlowMeasureDate => 'Дата замера';

  @override
  String get enquiryFlowConvertAction => 'Создать заявку';

  @override
  String get enquiryFlowAmbiguousTitle => 'Найдено несколько похожих клиентов';

  @override
  String get enquiryFlowAmbiguousSubtitle =>
      'Выберите существующего клиента или создайте нового:';

  @override
  String get enquiryFlowCreateNewCustomer => 'Создать как нового клиента';

  @override
  String get enquiryFlowDimensions => 'Размеры помещения / изделия';

  @override
  String get enquiryFlowDimensionsHint => '3200×600, h=2100, угол слева';

  @override
  String get enquiryFlowNotes => 'Примечания и материалы';

  @override
  String get enquiryFlowNotesHint => 'МДФ белый глянец, фурнитура Blum';

  @override
  String get enquiryFlowAddress => 'Адрес доставки и замера';

  @override
  String get enquiryFlowAddressHint => 'ул. Абая 45, кв. 12';

  @override
  String get enquiryFlowCity => 'Город';

  @override
  String get enquiryFlowCityHint => 'Алматы';

  @override
  String get enquiryFlowRecordMeasurementAction => 'Записать результат замера';

  @override
  String get enquiryFlowAttachPhotos => 'Фотографии и референсы';

  @override
  String get enquiryFlowTakePhoto => 'Сделать фото';

  @override
  String get enquiryFlowPickGallery => 'Из галереи';

  @override
  String enquiryFlowPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото приложено',
      many: '$count фото приложено',
      few: '$count фото приложено',
      one: '$count фото приложено',
    );
    return '$_temp0';
  }

  @override
  String get enquiryFlowRemovePhoto => 'Удалить фото';

  @override
  String get enquiryFlowPermissionDenied =>
      'Доступ к камере или галерее не предоставлен. Разрешите доступ в настройках устройства, чтобы прикрепить фото замера.';

  @override
  String get enquiryFlowItemCode => 'Наименование позиции';

  @override
  String get enquiryFlowItemCodeHint => 'Кухонный гарнитур';

  @override
  String get enquiryFlowItemDesc => 'Описание позиции';

  @override
  String get enquiryFlowItemDescHint => 'Фасады МДФ, столешница камень';

  @override
  String get enquiryFlowItemQty => 'Количество';

  @override
  String get enquiryFlowItemRate => 'Цена за единицу (₸)';

  @override
  String get enquiryFlowAddItem => '+ Добавить позицию';

  @override
  String get enquiryFlowValidDays => 'Срок действия КП (дней)';

  @override
  String get enquiryFlowDraftProposalAction => 'Создать черновик КП';

  @override
  String get enquiryFlowDeliveryDate => 'Срок готовности / доставки';

  @override
  String get enquiryFlowDeliveryDateRequired =>
      'Укажите срок сдачи для создания заказа';

  @override
  String get enquiryFlowPickDeliveryDate => 'Выбрать дату';

  @override
  String get enquiryFlowAcceptOrderAction => 'Принять и создать заказ';

  @override
  String get enquiryFlowOrderCompleted => 'Заказ передан в производство';

  @override
  String get enquiryFlowViewOrder => 'Перейти к заказу';

  @override
  String get enquiryFlowEmptyCaptures => 'Нет доступных обращений';

  @override
  String get enquiryFlowEmptyCapturesDesc =>
      'Создайте новое обращение голосом или текстом, чтобы провести его по цепочке.';

  @override
  String get orderDesignSection => 'Дизайн и чертежи';

  @override
  String get orderDesignStatusNotAssigned => 'Не поручен';

  @override
  String get orderDesignStatusAssigned => 'В работе';

  @override
  String get orderDesignStatusDelivered => 'Принят';

  @override
  String get orderDesignStatusOverdue => 'Просрочен';

  @override
  String get orderDesignNoTaskTitle => 'Дизайн ещё не поручен';

  @override
  String get orderDesignNoTaskBody =>
      'Чертёж и спецификация необходимы до запуска заказа в цех.';

  @override
  String get orderDesignAssignAction => 'Поручить дизайн';

  @override
  String get orderDesignDesignerLabel => 'Дизайнер';

  @override
  String get orderDesignDueDateLabel => 'Срок сдачи чертежа';

  @override
  String get orderDesignDueDateRequired => 'Укажите срок сдачи чертежа';

  @override
  String get orderDesignFilesHeader => 'Приложенные файлы';

  @override
  String get orderDesignNoFilesNotice =>
      'Ожидается чертёж. Без приложенного файла дизайн не может быть принят.';

  @override
  String get orderDesignAttachFileAction => 'Приложить чертёж';

  @override
  String get orderDesignAttachDialogTitle => 'Прикрепить чертёж к заказу';

  @override
  String get orderDesignFileNameLabel => 'Имя файла чертежа';

  @override
  String get orderDesignFileNameHint => 'чертёж_кухня.dxf';

  @override
  String get orderDesignAttachButton => 'Прикрепить файл';

  @override
  String get orderDesignDeliverAction => 'Принять дизайн';

  @override
  String get orderDesignCompletedNotice => 'Дизайн принят, чертежи проверены';

  @override
  String get orderInstallationSection => 'Монтаж';

  @override
  String get orderInstallationStatusNotScheduled => 'Не назначен';

  @override
  String get orderInstallationStatusScheduled => 'Назначен';

  @override
  String get orderInstallationStatusCompleted => 'Выполнен';

  @override
  String get orderInstallationStatusOverdue => 'Просрочен';

  @override
  String get orderInstallationNoDeliveryNotice =>
      'Сначала отгрузка, потом монтаж. Бригада, приехавшая к клиенту без мебели, теряет день, а клиент — доверие.';

  @override
  String get orderInstallationReadyToSchedule =>
      'Мебель отгружена. Назначьте дату выезда монтажной бригады.';

  @override
  String get orderInstallationScheduleAction => 'Назначить монтаж';

  @override
  String get orderInstallationInstallerLabel => 'Монтажник / Бригада';

  @override
  String get orderInstallationDateLabel => 'Дата монтажа';

  @override
  String get orderInstallationDateRequired => 'Укажите дату монтажа';

  @override
  String get orderInstallationCompleteAction => 'Монтаж выполнен';

  @override
  String get orderInstallationCompleteDialogTitle => 'Завершение монтажа';

  @override
  String get orderInstallationNotesLabel => 'Заметки бригады';

  @override
  String get orderInstallationNotesHint =>
      'Например: стена оказалась кривой, ставили с доборным элементом';

  @override
  String get orderInstallationCompletedNotice => 'Монтаж успешно завершён';

  @override
  String get orderWarrantySection => 'Гарантия';

  @override
  String get orderWarrantyNotStartedNotice =>
      'Гарантия начнётся после отгрузки.';

  @override
  String orderWarrantyShippedOn(String date) {
    return 'Отгружено: $date';
  }

  @override
  String get orderWarrantyStatusActive => 'Действует';

  @override
  String get orderWarrantyStatusExpired => 'Закончилась';

  @override
  String get orderWarrantyStatusNoWarranty => 'Без гарантии';

  @override
  String orderWarrantyUntil(String date) {
    return 'до $date';
  }

  @override
  String orderWarrantyPeriodDays(int days) {
    return '$days дн.';
  }

  @override
  String get orderWarrantyClaimAction => 'Оформить рекламацию';

  @override
  String get orderWarrantyClaimDialogTitle => 'Оформление рекламации';

  @override
  String get orderWarrantyItemLabel => 'Позиция';

  @override
  String get orderWarrantyComplaintLabel => 'Что случилось';

  @override
  String get orderWarrantyComplaintHint =>
      'Опишите дефект подробно: что сломалось, при каких условиях';

  @override
  String get orderWarrantyComplaintRequired => 'Опишите причину рекламации';

  @override
  String orderWarrantyClaimSuccessNotice(String claim) {
    return 'Рекламация $claim успешно зарегистрирована';
  }

  @override
  String get orderInvoicingSection => 'Счёт';

  @override
  String get orderInvoicingStatusNotDrafted => 'Не выставлен';

  @override
  String get orderInvoicingStatusDrafted => 'Выставлен';

  @override
  String get orderInvoicingStatusPaid => 'Оплачен';

  @override
  String get orderInvoicingOrderNotSubmittedNotice =>
      'Заказ ещё не проведён. Счёт по черновику — это счёт за то, о чём никто окончательно не договорился.';

  @override
  String get orderInvoicingNoDeliveryNotice =>
      'По заказу ничего не отгружено. Счёт за непривезённую мебель — самый быстрый способ поссориться с довольным клиентом.';

  @override
  String get orderInvoicingCreateAction => 'Выставить счёт';

  @override
  String get orderInvoicingNumberLabel => 'Номер счёта';

  @override
  String get orderInvoicingTotalLabel => 'Сумма счёта';

  @override
  String orderInvoicingSuccessNotice(String invoice) {
    return 'Счёт $invoice успешно сформирован';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAccount => 'Учётная запись';

  @override
  String get settingsSignedInAs => 'Вы вошли как';

  @override
  String get settingsConnection => 'Подключение';

  @override
  String get settingsLookAndLanguage => 'Оформление и язык';

  @override
  String get navDashboard => 'Главная';

  @override
  String get dashboardGreeting => 'Сегодня';

  @override
  String get dashboardMyWork => 'Моя работа';

  @override
  String dashboardWorkload(int overdue, int total) {
    return '$overdue из $total просрочены';
  }

  @override
  String get dashboardAttention => 'Требует внимания';

  @override
  String get dashboardAllClear => 'Сейчас ничего не требует вашего участия';

  @override
  String get dashboardAllClearBody =>
      'Здесь появятся просроченные задачи и решения, которые ждут вас.';

  @override
  String get metricOpenDeals => 'Открытые сделки';

  @override
  String get metricOpenLeads => 'Лиды';

  @override
  String get metricMyOpenTasks => 'Мои задачи';

  @override
  String get metricOverdueTasks => 'Просрочено';

  @override
  String get metricPendingActions => 'Ждут решения';

  @override
  String get metricWorkOrders => 'В производстве';

  @override
  String get attentionPendingAction => 'Нужно решение';

  @override
  String get attentionOverdueTask => 'Просроченная задача';

  @override
  String get navSales => 'Продажи';

  @override
  String get navLeads => 'Лиды';

  @override
  String get navCustomers => 'Клиенты';

  @override
  String get dealsEmptyAssigned => 'На вас пока ничего не назначено';

  @override
  String get dealsEmptyAssignedBody =>
      'Вы видите только свои сделки и те, где вы назначены. Попросите руководителя назначить вам сделку.';

  @override
  String get leadsEmpty => 'Лидов нет';

  @override
  String get leadsEmptyBody =>
      'Новые обращения появятся здесь по мере поступления.';

  @override
  String get leadConverted => 'Сконвертирован';

  @override
  String get customersEmpty => 'Клиентов нет';

  @override
  String get customersEmptyBody =>
      'Организации появятся здесь, как только по ним заведут сделку.';

  @override
  String get detailPipeline => 'Воронка';

  @override
  String get detailCommercial => 'Коммерция';

  @override
  String get detailOwnership => 'Ответственность';

  @override
  String get detailCompany => 'Компания';

  @override
  String get fieldStage => 'Стадия';

  @override
  String get fieldValue => 'Сумма';

  @override
  String get fieldProbability => 'Вероятность';

  @override
  String get fieldExpectedClose => 'Ожидаемое закрытие';

  @override
  String get fieldNextStep => 'Следующий шаг';

  @override
  String get fieldOwner => 'Ответственный';

  @override
  String get fieldSource => 'Источник';

  @override
  String get fieldTerritory => 'Регион';

  @override
  String get fieldIndustry => 'Отрасль';

  @override
  String get fieldWebsite => 'Сайт';

  @override
  String get fieldEmployees => 'Сотрудников';

  @override
  String get fieldRevenue => 'Годовой оборот';

  @override
  String get fieldOriginLead => 'Из лида';

  @override
  String get fieldUpdated => 'Обновлено';

  @override
  String get actionCall => 'Позвонить';

  @override
  String get actionEmail => 'Письмо';

  @override
  String get actionWhatsApp => 'WhatsApp';

  @override
  String get navApprovals => 'Согласования';

  @override
  String get navProduction => 'Производство';

  @override
  String get approvalsEmpty => 'Решений не требуется';

  @override
  String get approvalsEmptyBody =>
      'Здесь появятся решения, которых ждёт агент.';

  @override
  String get approvalApprove => 'Согласовать';

  @override
  String get approvalReject => 'Отклонить';

  @override
  String get approvalApproved => 'Согласовано';

  @override
  String get approvalRejected => 'Отклонено';

  @override
  String get approvalRejectDialogTitle => 'Отклонить действие';

  @override
  String get approvalRejectReasonHint => 'Причина отказа (необязательно)';

  @override
  String get approvalExpires => 'Истекает';

  @override
  String get approvalExpired => 'Истекло';

  @override
  String get productionEmpty => 'Заказов нет';

  @override
  String get productionEmptyBody =>
      'Заказы появятся, когда сделка уйдёт в производство.';

  @override
  String get paPending => 'Ожидает';

  @override
  String get paApproved => 'Согласовано';

  @override
  String get paRejected => 'Отклонено';

  @override
  String get paExpired => 'Истекло';

  @override
  String get woDraft => 'Черновик';

  @override
  String get woSubmitted => 'Подтверждён';

  @override
  String get woNotStarted => 'Не начат';

  @override
  String get woInProcess => 'В работе';

  @override
  String get woStockReserved => 'Материалы зарезервированы';

  @override
  String get woStockPartial => 'Материалы частично';

  @override
  String get woCompleted => 'Завершён';

  @override
  String get woStopped => 'Остановлен';

  @override
  String get woClosed => 'Закрыт';

  @override
  String get woCancelled => 'Отменён';

  @override
  String get navQuotes => 'Счета';

  @override
  String get navWarehouse => 'Склад';

  @override
  String get navOperations => 'Операции';

  @override
  String get quotesEmpty => 'Счетов нет';

  @override
  String get quotesEmptyBody => 'Счета появятся, когда их выставят по сделке.';

  @override
  String get warehouseEmpty => 'Позиций нет';

  @override
  String get warehouseEmptyBody => 'Складские позиции появятся здесь.';

  @override
  String get fieldValidTill => 'Действителен до';

  @override
  String get fieldReserved => 'Резерв';

  @override
  String get warehouseNoStock => 'Нет ни на одном складе';

  @override
  String get quoteExpiredSoon => 'Истекает';

  @override
  String get qDraft => 'Черновик';

  @override
  String get qOpen => 'Открыт';

  @override
  String get qReplied => 'Есть ответ';

  @override
  String get qPartiallyOrdered => 'Частично заказан';

  @override
  String get qOrdered => 'Заказан';

  @override
  String get qLost => 'Проигран';

  @override
  String get qCancelled => 'Отменён';

  @override
  String get qExpired => 'Истёк';

  @override
  String get navNotifications => 'Уведомления';

  @override
  String get notificationsEmpty => 'Пока ничего не отправлялось.';

  @override
  String get notificationsEmptyBody =>
      'Назначения, упоминания и оповещения появятся здесь.';

  @override
  String get notificationsMarkAllRead => 'Отметить все';

  @override
  String get navAssistant => 'Ассистент';

  @override
  String get navMenu => 'Меню';

  @override
  String get chatNew => 'Новый чат';

  @override
  String get chatRecent => 'Недавние';

  @override
  String get chatGreeting => 'Чем могу помочь?';

  @override
  String get chatPlaceholder => 'Спросите KORKEM о чём угодно…';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatDictate => 'Продиктовать';

  @override
  String get chatDictateStop => 'Остановить диктовку';

  @override
  String get chatDictateUnavailable =>
      'Микрофон недоступен. Разрешите доступ в настройках телефона или продиктуйте текстом.';

  @override
  String get chatLocalMode => 'Локальный режим · данные KORKEM';

  @override
  String get chatThinking => 'Думаю';

  @override
  String get chatEmptyThreads => 'Разговоров пока нет';

  @override
  String get chatEmptyThreadsBody =>
      'Здесь появятся ваши диалоги с ассистентом.';

  @override
  String get chatOpen => 'Открыть';

  @override
  String get chatNotConnected =>
      'Я пока не подключён к языковой модели и не могу на это ответить. Могу показать данные KORKEM:';

  @override
  String get chatSuggestDeals => 'Покажи мои сделки';

  @override
  String get chatSuggestAttention => 'Что требует внимания?';

  @override
  String get chatSuggestOverdue => 'Что просрочено?';

  @override
  String get chatSuggestProduction => 'Что сейчас в производстве?';

  @override
  String get chatCardOpenDeals => 'Открытые сделки';

  @override
  String get chatCardAttention => 'Требует внимания';

  @override
  String get chatCardTasks => 'Мои задачи';

  @override
  String get chatCardProduction => 'В производстве';

  @override
  String get chatHistory => 'История';

  @override
  String get chatHistoryEmpty => 'Разговоров пока нет.';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String get chatEarlier => 'Ранее';

  @override
  String get chatScrollToEnd => 'К последнему сообщению';

  @override
  String get chatWorkspace => 'AI Workspace';

  @override
  String get chatRename => 'Переименовать';

  @override
  String get chatDelete => 'Удалить';

  @override
  String get chatDeleteTitle => 'Удалить разговор?';

  @override
  String chatDeleteBody(String title) {
    return 'Разговор «$title» будет удалён с этого устройства. Отменить нельзя.';
  }

  @override
  String get chatRenameTitle => 'Название разговора';

  @override
  String get navClients => 'Клиенты';

  @override
  String get chatErrorNotConfigured =>
      'ИИ ещё не настроен на сервере. Обратитесь к администратору KORKEM.';

  @override
  String get chatErrorOffline =>
      'Не удалось связаться с KORKEM. Проверьте подключение.';

  @override
  String get chatErrorRefused => 'Недостаточно прав для этого запроса.';

  @override
  String get chatErrorUnknown => 'Не удалось ответить. Попробуйте ещё раз.';

  @override
  String get chatWorking => 'Работаю…';

  @override
  String get chatToolDeals => 'Ищу сделки…';

  @override
  String get chatToolLeads => 'Ищу лиды…';

  @override
  String get chatToolCustomers => 'Ищу клиентов…';

  @override
  String get chatToolTasks => 'Ищу задачи…';

  @override
  String get chatToolProduction => 'Смотрю производство…';

  @override
  String get chatToolOrders => 'Смотрю заказы…';

  @override
  String get chatToolShortage => 'Считаю дефицит материалов…';

  @override
  String get chatToolStock => 'Проверяю остатки…';

  @override
  String get chatToolProcurement => 'Готовлю заявку на закупку…';

  @override
  String get chatToolProfile => 'Проверяю ваш профиль…';

  @override
  String get chatErrorProviderUnavailable =>
      'Сервис ИИ не отвечает. Попробуйте чуть позже.';

  @override
  String get chatErrorRateLimited =>
      'Сервис ИИ перегружен. Подождите немного и повторите.';

  @override
  String get chatErrorToolError =>
      'Не удалось выполнить это действие в KORKEM.';

  @override
  String get chatConfirmTitle => 'Подтвердите действие';

  @override
  String get chatConfirmBody =>
      'Помощник хочет внести изменение. Пока ничего не произошло.';

  @override
  String get chatConfirmApprove => 'Подтвердить';

  @override
  String get chatConfirmReject => 'Отменить';

  @override
  String get chatConfirmRejected => 'Отменено. Ничего не изменилось.';

  @override
  String get chatFallbackBadge => 'Без ИИ — прямые данные';

  @override
  String get chatExternalMessageDefault => 'Сообщение клиента';

  @override
  String get chatExternalDataNotice =>
      'Чужой текст — ассистент его не выполняет';

  @override
  String get chatErrorTimedOut =>
      'Сервис ИИ отвечал слишком долго. Попробуйте ещё раз.';

  @override
  String get chatErrorModelNotFound =>
      'Выбранная модель недоступна. Выберите другую в настройках ИИ.';

  @override
  String get chatErrorContextTooLarge =>
      'Этот диалог слишком длинный. Начните новый.';

  @override
  String get aiSettingsTitle => 'Провайдеры ИИ';

  @override
  String get aiSettingsSubtitle =>
      'Выберите, какой ИИ отвечает, и подключите его.';

  @override
  String get aiSettingsDefault => 'По умолчанию';

  @override
  String get aiSettingsMakeDefault => 'Сделать основным';

  @override
  String get aiSettingsNotConfigured => 'Не настроен';

  @override
  String get aiSettingsConnected => 'Подключено';

  @override
  String get aiSettingsTestFailed => 'Не удалось подключиться';

  @override
  String get aiSettingsTest => 'Проверить подключение';

  @override
  String get aiSettingsSave => 'Сохранить';

  @override
  String get aiSettingsApiKey => 'API-ключ';

  @override
  String get aiSettingsApiKeyStored =>
      'Ключ сохранён. Оставьте пустым, чтобы не менять.';

  @override
  String get aiSettingsModel => 'Модель';

  @override
  String get aiSettingsBaseUrl => 'Базовый URL';

  @override
  String get aiSettingsKeyNeverLeaves =>
      'Ключи хранятся на сервере KORKEM и никогда не передаются на это устройство.';

  @override
  String get aiSettingsCapabilities => 'Возможности';

  @override
  String get aiSettingsLocalNoKey => 'Работает локально — ключ не нужен.';

  @override
  String get channelsTitle => 'Каналы';

  @override
  String get channelsSubtitle =>
      'Подключите ботов Telegram и WhatsApp и укажите, кто на другой стороне.';

  @override
  String get channelsSecretsNote =>
      'Токены хранятся на сервере KORKEM и никогда не передаются на это устройство.';

  @override
  String get channelsStateNotConfigured => 'Не настроен';

  @override
  String get channelsStateDisabled => 'Выключен';

  @override
  String get channelsStateReady => 'Готов';

  @override
  String get channelsTest => 'Проверить связь';

  @override
  String get channelsTestOk => 'Связь есть';

  @override
  String get channelsTestFailed => 'Связи нет';

  @override
  String get channelsEnabled => 'Включён';

  @override
  String get channelsSave => 'Сохранить';

  @override
  String get channelsStored => 'Сохранено. Оставьте пустым, чтобы не менять.';

  @override
  String get channelsBotToken => 'Токен бота';

  @override
  String get channelsWebhookSecret => 'Секрет вебхука';

  @override
  String get channelsAccessToken => 'Токен доступа';

  @override
  String get channelsPhoneNumberId => 'ID номера';

  @override
  String get channelsVerifyToken => 'Токен проверки';

  @override
  String get channelsWebhookUrl => 'URL вебхука';

  @override
  String get channelsIdentities => 'Кто пишет';

  @override
  String get channelsIdentityUnlinked => 'Не связан';

  @override
  String get channelsLink => 'Связать';

  @override
  String get channelsUnlink => 'Отвязать';

  @override
  String get channelsUser => 'Пользователь KORKEM';

  @override
  String get channelsIdentitiesEmpty => 'Боту ещё никто не писал.';

  @override
  String get channelsStateConnected => 'Связь есть';

  @override
  String get channelsStateInvalid => 'Учётные данные отклонены';

  @override
  String get channelsStateWebhookError => 'Проблема с вебхуком';

  @override
  String get channelsStateUnavailable => 'Провайдер недоступен';

  @override
  String get channelsConfigureWebhook => 'Настроить вебхук';

  @override
  String get channelsRemoveWebhook => 'Убрать вебхук';

  @override
  String get channelsWebhookManual =>
      'Вставьте этот адрес в панель провайдера.';

  @override
  String get channelsLastChecked => 'Последняя проверка';

  @override
  String get channelsPending => 'Ожидает у провайдера';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsSubtitle =>
      'Что система сообщила людям и что доставить не удалось.';

  @override
  String get notificationsRetry => 'Повторить';

  @override
  String get notificationsRetryAll => 'Повторить все';

  @override
  String get notificationsCancel => 'Отменить';

  @override
  String get notificationsAttempts => 'Попыток';

  @override
  String get notificationsNextAttempt => 'Следующая попытка';

  @override
  String get notificationsFilterAll => 'Все';

  @override
  String get instructionsTitle => 'Поручения';

  @override
  String get instructionsSubtitle => 'Кого попросили и что он ответил.';

  @override
  String get instructionsEmpty => 'Поручений пока нет.';

  @override
  String get instructionsAnsweredIn => 'Ответ через';

  @override
  String get channelsSendTest => 'Отправить тестовое';

  @override
  String get channelsDisconnect => 'Отключить';

  @override
  String get channelsLastInbound => 'Последнее входящее';

  @override
  String get channelsLastOutbound => 'Последнее исходящее';

  @override
  String get channelsFailedDeliveries => 'Не доставлено';

  @override
  String get channelsPendingRetries => 'Ждут повтора';

  @override
  String get channelsStateForbidden => 'Заблокировано провайдером';

  @override
  String get channelsStateRateLimited => 'Ограничение частоты';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get ordersEmpty => 'Заказов пока нет';

  @override
  String get ordersEmptyBody => 'Новые заказы клиентов появятся здесь.';

  @override
  String get ordersActionStartProduction => 'Запустить производство';

  @override
  String get ordersStartingProduction => 'Запуск производства...';

  @override
  String ordersStartSuccess(String id) {
    return 'Производство запущено по $id';
  }

  @override
  String ordersTopUpSuccess(String id) {
    return 'Материал передан по $id';
  }

  @override
  String ordersAlreadyStarted(String id) {
    return 'Производство по $id уже запущено';
  }

  @override
  String ordersNothingToStart(String id) {
    return 'По заказу $id нечего запускать';
  }

  @override
  String get ordersBlockedTitle => 'Недостаточно материалов';

  @override
  String get ordersBlockedBody =>
      'Для запуска производства не хватает материалов на складе:';

  @override
  String ordersBlockedSummary(String id) {
    return 'Нельзя запустить $id: не хватает материалов на складе';
  }

  @override
  String ordersDeliveredProgress(String percent) {
    return 'Отгружено $percent%';
  }

  @override
  String ordersDeliveryDate(String date) {
    return 'Доставка: $date';
  }

  @override
  String ordersTransactionDate(String date) {
    return 'От $date';
  }

  @override
  String get soDraft => 'Черновик';

  @override
  String get soToDeliverAndBill => 'К отгрузке и оплате';

  @override
  String get soToBill => 'К оплате';

  @override
  String get soToDeliver => 'К отгрузке';

  @override
  String get soCompleted => 'Завершён';

  @override
  String get soCancelled => 'Отменён';

  @override
  String get soClosed => 'Закрыт';

  @override
  String get soOnHold => 'На удержании';

  @override
  String get todayTitle => 'Что требует внимания';

  @override
  String get todaySubtitle =>
      'Ежедневный контроль цепочки производства и продаж';

  @override
  String get todayActiveOrders => 'Активные заказы';

  @override
  String todayLateOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count просрочено',
      many: '$count просрочено',
      few: '$count просрочено',
      one: '$count просрочен',
    );
    return '$_temp0';
  }

  @override
  String get todayOrdersAllOnTrack => 'Все в графике';

  @override
  String get todayInProduction => 'В производстве';

  @override
  String todayWorkOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заданий',
      many: '$count заданий',
      few: '$count задания',
      one: '$count задание',
    );
    return '$_temp0';
  }

  @override
  String get todayProductionAllOnTrack => 'Без задержек';

  @override
  String get todayApprovals => 'Ожидают подтверждения';

  @override
  String todayApprovalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count решений',
      many: '$count решений',
      few: '$count решения',
      one: '$count решение',
    );
    return '$_temp0';
  }

  @override
  String get todayApprovalsNone => 'Все согласованы';

  @override
  String get todayStockDeficit => 'Дефицит склада';

  @override
  String todayDeficitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count позиций ниже нуля',
      many: '$count позиций ниже нуля',
      few: '$count позиции ниже нуля',
      one: '$count позиция ниже нуля',
    );
    return '$_temp0';
  }

  @override
  String get todayDeficitNone => 'Дефицита нет';

  @override
  String get todayAttentionTitle => 'Требует внимания';

  @override
  String get todayAllClearTitle => 'Всё в порядке';

  @override
  String get todayAllClearSubtitle =>
      'Критических задержек и дефицита на производстве нет';

  @override
  String get todayQuickNav => 'Быстрый переход';

  @override
  String get todayTileError => 'Не удалось загрузить';

  @override
  String get todayUnassignedCapturesTitle => 'Не передано в работу';

  @override
  String get todayUnassignedCapturesEmpty =>
      'Ничего не потеряно: все обращения переданы в работу';

  @override
  String get todayOverdueTasksTitle => 'Просроченные задачи';

  @override
  String get todayOverdueTasksEmpty =>
      'Всё в срок: нет просроченных замеров, дизайнов и монтажей';

  @override
  String get todayOrdersWithoutDesignTitle => 'Заказы без дизайна';

  @override
  String get todayOrdersWithoutDesignEmpty => 'По всем заказам назначен дизайн';

  @override
  String get todayDeliveredNotInvoicedTitle => 'Отгружено без счёта';

  @override
  String get todayDeliveredNotInvoicedEmpty => 'Все отгрузки закрыты счетами';

  @override
  String get todayAllClearHeadline => 'Всё под контролем';

  @override
  String get todayAllClearDescription =>
      'Все обращения переданы, просрочек нет, дизайн назначен по всем заказам, а отгрузки закрыты счетами.';

  @override
  String todayOverdueWasDue(String date) {
    return 'Срок истёк: $date';
  }

  @override
  String todayDeliveryDue(String date) {
    return 'Срок сдачи: $date';
  }

  @override
  String todayBilledProgress(String delivered, String billed) {
    return 'Отгружено $delivered%, выставлено $billed%';
  }

  @override
  String todayHeaderDate(String date) {
    return 'Сегодня, $date';
  }

  @override
  String get todayImportantOverdue => 'Просрочено';

  @override
  String get todayImportantDueToday => 'Сдать сегодня';

  @override
  String get todayImportantDueThisWeek => 'Сдать на этой неделе';

  @override
  String get todayImportantUnpaid => 'Не оплачено';

  @override
  String get todayImportantMaterialDeficit => 'Материала не хватает';

  @override
  String get todayImportantInstallationToday => 'Монтаж сегодня';

  @override
  String get todayImportantRequiresDecision => 'Требует решения';

  @override
  String todayOrdersCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'заказа',
      many: 'заказов',
      few: 'заказа',
      one: 'заказ',
    );
    return '$_temp0';
  }

  @override
  String todayPositionsCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'позиций',
      many: 'позиций',
      few: 'позиции',
      one: 'позиция',
    );
    return '$_temp0';
  }

  @override
  String todayApprovalsCountUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'согласований',
      many: 'согласований',
      few: 'согласования',
      one: 'согласование',
    );
    return '$_temp0';
  }

  @override
  String get todayEmptyStateTitle => 'Всё под контролем';

  @override
  String get todayEmptyStateDescription =>
      'На сегодня нет просрочек, дефицита материалов и действий, требующих решения.';

  @override
  String get orderProductionSection => 'Производство';

  @override
  String get orderNoProductionTitle => 'Производство ещё не запущено';

  @override
  String get orderNoProductionBody =>
      'По этому заказу нет ни одного задания. Запустите производство, когда заказ подтверждён.';

  @override
  String get workOrderLinkedSalesOrder => 'Связанный заказ';

  @override
  String get workOrderNoLinkedSalesOrder => 'Заказ не привязан';

  @override
  String workOrderPlannedEnd(String date) {
    return 'Плановое окончание: $date';
  }

  @override
  String workOrderActualEnd(String date) {
    return 'Фактическое окончание: $date';
  }

  @override
  String workOrderBomNo(String bom) {
    return 'Спецификация: $bom';
  }

  @override
  String workOrderWipWarehouse(String warehouse) {
    return 'Склад незавершённого производства: $warehouse';
  }

  @override
  String workOrderFgWarehouse(String warehouse) {
    return 'Склад готовой продукции: $warehouse';
  }

  @override
  String workOrderProducedProgress(String produced, String qty) {
    return 'Изготовлено: $produced из $qty';
  }

  @override
  String get workOrderOperationsSection => 'Операции';

  @override
  String get workOrderNoOperationsTitle => 'Нет операций';

  @override
  String get workOrderNoOperationsBody =>
      'В этом производственном задании операции не заданы.';

  @override
  String workOrderOperationSequence(int sequence) {
    return '№ $sequence';
  }

  @override
  String workOrderOperationWorkstation(String workstation) {
    return 'Рабочий центр: $workstation';
  }

  @override
  String workOrderOperationCompleted(String qty) {
    return 'Выполнено: $qty';
  }

  @override
  String workOrderOperationScrap(String qty) {
    return 'Брак: $qty';
  }

  @override
  String workOrderOperationTime(int minutes) {
    return 'План: $minutes мин';
  }

  @override
  String get opPending => 'Ожидает';

  @override
  String get opInProgress => 'В работе';

  @override
  String get opCompleted => 'Выполнено';

  @override
  String get opClosed => 'Закрыто';

  @override
  String get opCancelled => 'Отменено';

  @override
  String get stockBalancesSection => 'Остатки по складам';

  @override
  String get stockSummarySection => 'Итого по всем складам';

  @override
  String get stockActualQty => 'Фактический остаток';

  @override
  String get stockReservedQty => 'В резерве';

  @override
  String get stockProjectedQty => 'Прогноз';

  @override
  String get stockDeficitAlert => 'Дефицит на складе';

  @override
  String get stockNoBalancesTitle => 'Нет на складах';

  @override
  String get stockNoBalancesBody =>
      'Позиция не числится ни на одном складе компании.';

  @override
  String get warehouseActionOpen => 'Открыть';

  @override
  String get outboxTitle => 'Очередь команд';

  @override
  String get outboxEmptyTitle => 'Все команды отправлены';

  @override
  String get outboxEmptyBody =>
      'Нет ожидающих или отклонённых команд. При потере связи новые действия сохранятся здесь.';

  @override
  String outboxPendingSection(int count) {
    return 'Ждут отправки ($count)';
  }

  @override
  String outboxRejectedSection(int count) {
    return 'Отклонены ($count)';
  }

  @override
  String outboxRejectedPending(int count) {
    return 'Требуют внимания: $count';
  }

  @override
  String get outboxDismissRejected => 'Понятно, убрать';

  @override
  String get outboxDismissAll => 'Убрать все';

  @override
  String outboxCommandStartProduction(String order) {
    return 'Запуск производства по $order';
  }

  @override
  String outboxCommandCompleteOperation(String operation) {
    return 'Отчёт по операции: $operation';
  }

  @override
  String outboxCommandReceiveReceipt(String order) {
    return 'Приёмка по $order';
  }

  @override
  String outboxCommandCreatePurchaseOrder(String request) {
    return 'Заказ поставщику по $request';
  }

  @override
  String outboxCommandCreateDelivery(String order) {
    return 'Отгрузка по $order';
  }

  @override
  String outboxCommandGeneric(String path) {
    return 'Команда: $path';
  }

  @override
  String outboxParamItem(String item) {
    return 'Позиция: $item';
  }

  @override
  String outboxParamSupplier(String supplier) {
    return 'Поставщик: $supplier';
  }

  @override
  String outboxParamWorkOrder(String workOrder) {
    return 'Задание: $workOrder';
  }

  @override
  String outboxParamCompletedQty(String qty) {
    return 'Готово: $qty';
  }

  @override
  String outboxParamScrapQty(String qty) {
    return 'Брак: $qty';
  }

  @override
  String get todayOutboxTitle => 'Не отправлено';

  @override
  String get todayOutboxAllSent => 'Всё отправлено';

  @override
  String get orderDeliveriesSection => 'Отгрузки';

  @override
  String get orderNoDeliveriesTitle => 'Отгрузок ещё не было';

  @override
  String get orderNoDeliveriesBody =>
      'Здесь появятся накладные, когда товары будут отгружены.';

  @override
  String get searchTitle => 'Поиск';

  @override
  String get searchPlaceholder => 'Заказ, клиент, материал...';

  @override
  String get searchEmptyPromptTitle => 'Поиск по всей системе';

  @override
  String get searchEmptyPromptBody =>
      'Введите номер заказа, имя клиента, задание или код материала.';

  @override
  String get searchNoResultsTitle => 'Ничего не найдено';

  @override
  String searchNoResultsBody(String query) {
    return 'По запросу «$query» ничего не найдено.';
  }

  @override
  String searchSectionOrders(int count) {
    return 'Заказы ($count)';
  }

  @override
  String searchSectionWorkOrders(int count) {
    return 'Задания ($count)';
  }

  @override
  String searchSectionStock(int count) {
    return 'Склад ($count)';
  }

  @override
  String searchSectionError(String section) {
    return 'Не удалось загрузить раздел: $section';
  }

  @override
  String get searchNavTooltip => 'Поиск';

  @override
  String get ordersSelectPromptTitle => 'Выберите заказ';

  @override
  String get ordersSelectPromptBody =>
      'Выберите заказ из списка слева, чтобы посмотреть его параметры, статус, задания производства и отгрузки.';

  @override
  String get productionSelectPromptTitle => 'Выберите задание';

  @override
  String get productionSelectPromptBody =>
      'Выберите задание из списка, чтобы просмотреть его параметры и технологические операции.';

  @override
  String get warehouseSelectPromptTitle => 'Выберите позицию';

  @override
  String get warehouseSelectPromptBody =>
      'Выберите позицию из списка, чтобы просмотреть остатки по складам и параметры.';

  @override
  String get completeOperationAction => 'Закрыть';

  @override
  String get completeOperationTitle => 'Закрытие операции';

  @override
  String get completeOperationQtyLabel => 'Готовая продукция';

  @override
  String get completeOperationScrapQtyLabel => 'Брак';

  @override
  String completeOperationSuccess(String operation) {
    return 'Операция «$operation» завершена';
  }

  @override
  String get completeOperationAlreadyComplete =>
      'Операция уже была закрыта ранее';

  @override
  String get completeOperationInvalidQty =>
      'Введите корректное неотрицательное число';

  @override
  String get completeOperationBlockedTitle => 'Не удалось закрыть операцию';

  @override
  String get ordersActionCreateDelivery => 'Создать отгрузку';

  @override
  String orderDeliverySuccess(String note) {
    return 'Отгрузка $note создана';
  }

  @override
  String orderDeliveryAdjustedSuccess(String note) {
    return 'Частичная отгрузка $note создана по наличию на складе';
  }

  @override
  String get orderAlreadyDelivered => 'Заказ уже полностью отгружен';

  @override
  String get orderNothingShippable =>
      'На складе нет готовых позиций для отгрузки';

  @override
  String get orderDeliveryBlockedTitle => 'Не удалось создать отгрузку';

  @override
  String get warehouseActionReceive => 'Принять поставку';

  @override
  String get receiveDeliveryDialogTitle => 'Приёмка поставки';

  @override
  String get receivePurchaseOrderFieldLabel => 'Номер заказа поставщику';

  @override
  String get receivePurchaseOrderFieldHint => 'напр. PUR-ORD-2026-00001';

  @override
  String receiveSuccess(String receipt) {
    return 'Поступление $receipt принято';
  }

  @override
  String get receiveNothingOutstanding =>
      'Все позиции по этому заказу поставщику уже приняты';

  @override
  String get receiveBlockedTitle => 'Не удалось принять поставку';

  @override
  String get warehouseActionPurchaseOrder => 'Создать закупку';

  @override
  String get createPurchaseOrderDialogTitle => 'Создание заказа поставщику';

  @override
  String get materialRequestFieldLabel => 'Номер заявки на материалы';

  @override
  String get materialRequestFieldHint => 'напр. MAT-MR-2026-00001';

  @override
  String get supplierFieldLabel => 'Поставщик (необязательно)';

  @override
  String purchaseOrderSuccess(String order) {
    return 'Заказ поставщику $order создан';
  }

  @override
  String get purchaseOrderBlockedTitle => 'Не удалось создать заказ поставщику';

  @override
  String get receiveNoOrdersTitle => 'Нет ожидаемых поставок';

  @override
  String get receiveNoOrdersBody =>
      'Все заказы поставщикам уже приняты либо нет активных заказов.';

  @override
  String get orderableNoRequestsTitle => 'Нет заявок на материалы';

  @override
  String get orderableNoRequestsBody =>
      'Все заявки на закупку материалов уже обработаны.';

  @override
  String materialRequestNeededDate(String date) {
    return 'Потребность к: $date';
  }

  @override
  String purchaseOrderExpectedDate(String date) {
    return 'Ожидается: $date';
  }

  @override
  String get workstationsTitle => 'Рабочие места';

  @override
  String get workstationsSubtitle => 'Очередь операций по станкам';

  @override
  String get workstationsEmptyTitle => 'Нет активных заданий';

  @override
  String get workstationsEmptyBody =>
      'Все станки свободны, незавершённых операций нет.';

  @override
  String get stationQueueEmptyTitle => 'На этом месте всё сделано';

  @override
  String get stationQueueEmptyBody => 'Нет ожидающих операций на этом станке.';

  @override
  String workstationWaitingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count операций',
      few: '$count операции',
      one: '$count операция',
    );
    return '$_temp0';
  }

  @override
  String workstationDueOn(String date) {
    return 'Срок: $date';
  }

  @override
  String workstationItemLabel(String item) {
    return 'Изделие: $item';
  }

  @override
  String workstationQtyLabel(String qty) {
    return 'Количество: $qty';
  }

  @override
  String workstationDuration(String minutes) {
    return '$minutes мин';
  }

  @override
  String updateAvailable(String version) {
    return 'Доступно обновление $version';
  }

  @override
  String get updateInstall => 'Обновить';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get updateDialogTitle => 'Обновление KORKEM Flow';

  @override
  String updateBuildLabel(String version, int build) {
    return 'Версия $version (сборка $build)';
  }

  @override
  String get updateNotesTitle => 'Что нового:';

  @override
  String get updateDownloading => 'Загрузка обновления...';

  @override
  String get updateCheckButton => 'Проверить обновления';

  @override
  String get updateUpToDate => 'У вас установлена последняя версия';

  @override
  String get updateOpenBrowser => 'Скачать через браузер';

  @override
  String get updateInstallSystemPrompt =>
      'После загрузки откроется установщик системы.';

  @override
  String get aiCascadeTitle => 'Порядок обращения';

  @override
  String get aiCascadeSubtitle =>
      'Спрашиваем сверху вниз: когда у одной кончается квота, отвечает следующая.';

  @override
  String get aiCascadeFree => 'бесплатно';

  @override
  String get memoryTitle => 'Что KORKEM знает';

  @override
  String get memorySubtitle => 'Память о компании и ваших привычках';

  @override
  String get memorySectionCompany => 'О компании';

  @override
  String get memorySectionUser => 'Обо мне';

  @override
  String get memoryEmptyTitle => 'KORKEM пока ничего о вас не запомнил';

  @override
  String get memoryEmptyBody =>
      'Здесь появятся знания о цехе, правилах работы и ваших предпочтениях, которые ассистент использует в разговорах.';

  @override
  String get memoryEmptyCompany => 'Пока нет фактов о компании';

  @override
  String get memoryEmptyUser => 'Пока нет фактов о вас';

  @override
  String get memoryStatusConfirmed => 'Подтверждено';

  @override
  String get memoryStatusUnconfirmed => 'Выведено системой';

  @override
  String get memoryActionView => 'Посмотреть';

  @override
  String get memoryActionEdit => 'Исправить';

  @override
  String get memoryActionDelete => 'Удалить';

  @override
  String get memoryActionConfirm => 'Подтвердить';

  @override
  String get memoryActionSave => 'Сохранить';

  @override
  String get memoryEditDialogTitle => 'Исправить факт';

  @override
  String get memoryEditHint => 'Текст факта';

  @override
  String get memoryDeleteConfirmTitle => 'Удалить факт?';

  @override
  String get memoryDeleteConfirmBody =>
      'Удалить память легко, вернуть нельзя. KORKEM перестанет учитывать этот факт в разговорах.';

  @override
  String get memoryFactUpdated => 'Факт обновлён';

  @override
  String get memoryFactConfirmed => 'Факт подтверждён';

  @override
  String get memoryFactDeleted => 'Факт удалён';

  @override
  String memorySourcePrefix(String source) {
    return 'Источник: $source';
  }

  @override
  String get promptBreakdownTitle => 'Из чего сложился последний запрос';

  @override
  String promptBreakdownTokens(String count) {
    return '$count токенов';
  }

  @override
  String get promptBreakdownHeaviest => 'самое тяжёлое';

  @override
  String get promptBreakdownEmpty => 'Запросов ещё не было';

  @override
  String get promptBreakdownEmptyBody =>
      'Здесь появится разбивка токенов после первого обращения к ассистенту.';

  @override
  String get tokenCategoryInstruction => 'Инструкция';

  @override
  String get tokenCategoryTools => 'Схемы инструментов';

  @override
  String get tokenCategoryCompanyMemory => 'Память компании';

  @override
  String get tokenCategoryUserMemory => 'Память обо мне';

  @override
  String get tokenCategoryConversation => 'Разговор';

  @override
  String get tokenCategoryOrderData => 'Данные заказа';

  @override
  String get tokenCategoryOther => 'Прочее';

  @override
  String get aiWeeklySummaryTitle => 'Сводка за неделю';

  @override
  String get aiWeeklyTurns => 'Всего ходов';

  @override
  String get aiWeeklyPrimaryModel => 'Первой моделью';

  @override
  String get aiWeeklyReserve => 'Резерв KORKEM';

  @override
  String get aiWeeklyAvgDuration => 'Средняя длительность';

  @override
  String aiWeeklySeconds(String seconds) {
    return '$seconds с';
  }

  @override
  String get assistantCheckTitle => 'Проверка ассистента';

  @override
  String get assistantCheckRunButton => 'Прогнать';

  @override
  String get assistantCheckRunning => 'Идёт проверка...';

  @override
  String get assistantCheckNotRunTitle => 'Проверка не запускалась';

  @override
  String get assistantCheckNotRunDescription =>
      'Запустите проверку, чтобы убедиться, что ассистент справляется с типичными сценариями цеха.';

  @override
  String assistantCheckPassedSummary(int passed, int total) {
    return 'Пройдено $passed из $total';
  }

  @override
  String assistantCheckLastRun(String time) {
    return 'последний прогон $time';
  }

  @override
  String assistantCheckDurationSeconds(String seconds) {
    return '$seconds с';
  }

  @override
  String get assistantCheckTakingLonger =>
      'Проверка идёт дольше обычного. Загляните сюда через минуту.';

  @override
  String get eventsTitle => 'Замечено KORKEM';

  @override
  String get eventsAllClearTitle => 'Всё под контролем';

  @override
  String get eventsAllClearDescription =>
      'Завод идёт по плану, срочных событий нет.';

  @override
  String get eventsSeverityHigh => 'Срочно';

  @override
  String get eventsSeverityMedium => 'Внимание';

  @override
  String get eventsSeverityLow => 'Инфо';

  @override
  String get eventsActionDismiss => 'Скрыть';

  @override
  String get eventsLoadFailed => 'Не удалось загрузить события';

  @override
  String get eventsDismissSuccess => 'Событие скрыто';

  @override
  String get materialsTitle => 'Материалы';

  @override
  String get materialsSubtitle => 'Каталог плит и кромки';

  @override
  String get navMaterials => 'Материалы';

  @override
  String get materialKindBoard => 'Плита';

  @override
  String get materialKindEdge => 'Кромка';

  @override
  String get materialsFilterAll => 'Все';

  @override
  String get materialsFilterBoards => 'Плиты';

  @override
  String get materialsFilterEdges => 'Кромка';

  @override
  String materialsThicknessLabel(String thickness) {
    return '$thickness мм';
  }

  @override
  String materialsFormatDimensions(int width, int height) {
    return '$width×$height мм';
  }

  @override
  String get materialsColorWhite => 'Белый';

  @override
  String get materialsColorWood => 'Дерево';

  @override
  String get materialsColorGrey => 'Серый';

  @override
  String get materialsColorBlack => 'Чёрный';

  @override
  String get materialsFilterThickness16 => '16 мм';

  @override
  String get materialsFilterThickness18 => '18 мм';

  @override
  String get materialsSearchHint =>
      'Поиск по коду декора, названию, производителю';

  @override
  String get materialsEmptyTitle => 'Каталог материалов пуст';

  @override
  String get materialsEmptyMessage =>
      'Позиции каталога появятся здесь после синхронизации.';

  @override
  String get materialsEmptyFilteredTitle => 'Ничего не найдено';

  @override
  String get materialsEmptyFilteredMessage =>
      'Попробуйте изменить параметры поиска или сбросить фильтры.';

  @override
  String get materialsFilterTitle => 'Фильтры';

  @override
  String get materialsFilterThickness => 'Толщина';

  @override
  String get materialsFilterColorFamily => 'Семейство цвета';

  @override
  String get materialsFilterKind => 'Тип материала';

  @override
  String get materialsActive => 'Активен';

  @override
  String get materialsInactive => 'Архив';

  @override
  String materialsFitsThickness(String thickness) {
    return 'под $thickness мм';
  }

  @override
  String materialsEdgeWidth(String width) {
    return 'ширина $width мм';
  }

  @override
  String get hardwareTitle => 'Фурнитура';

  @override
  String get hardwareSubtitle => 'Петли, направляющие и комплектующие';

  @override
  String get navHardware => 'Фурнитура';

  @override
  String get hardwareTypeAll => 'Все типы';

  @override
  String get hardwareTypeHinge => 'Петли';

  @override
  String get hardwareTypeRunner => 'Направляющие';

  @override
  String get hardwareTypeHandle => 'Ручки';

  @override
  String get hardwareTypeLeg => 'Опоры и ножки';

  @override
  String get hardwareTypeShelfSupport => 'Полкодержатели';

  @override
  String get hardwareKindHinge => 'Петля';

  @override
  String get hardwareKindRunner => 'Направляющая';

  @override
  String get hardwareKindHandle => 'Ручка';

  @override
  String get hardwareKindLeg => 'Опора';

  @override
  String get hardwareKindShelfSupport => 'Полкодержатель';

  @override
  String get hardwareOverlayAll => 'Все наложения';

  @override
  String get hardwareOverlayFull => 'Накладная';

  @override
  String get hardwareOverlayHalf => 'Полунакладная';

  @override
  String get hardwareOverlayInset => 'Вкладная';

  @override
  String get hardwareOverlayFullExplanation =>
      'Фасад полностью перекрывает торец корпуса';

  @override
  String get hardwareOverlayHalfExplanation =>
      'Два фасада делят один торец корпуса';

  @override
  String get hardwareOverlayInsetExplanation => 'Фасад утоплен внутрь корпуса';

  @override
  String get hardwareMountingAustrian => 'Австрийская (45 мм)';

  @override
  String get hardwareMountingItalian => 'Итальянская (48 мм)';

  @override
  String get hardwareMountingGerman => 'Немецкая (52 мм)';

  @override
  String get hardwareMountingMini => 'Мини (38 мм)';

  @override
  String hardwareOpeningAngle(String angle) {
    return '$angle°';
  }

  @override
  String hardwareCupSpec(String diameter, String depth) {
    return 'Чашка Ø$diameter×$depth мм';
  }

  @override
  String hardwareCupDiameter(String diameter) {
    return 'Ø$diameter мм';
  }

  @override
  String hardwareLength(String length) {
    return '$length мм';
  }

  @override
  String hardwareLoad(String load) {
    return 'до $load кг';
  }

  @override
  String hardwareHoleSpacing(String spacing) {
    return 'Межцентровое $spacing мм';
  }

  @override
  String get hardwareSoftClose => 'С доводчиком';

  @override
  String get hardwareNoSoftClose => 'Без доводчика';

  @override
  String get hardwareSearchHint => 'Поиск по модели, бренду, названию';

  @override
  String get hardwareEmptyTitle => 'Каталог фурнитуры пуст';

  @override
  String get hardwareEmptyMessage =>
      'Позиции фурнитуры появятся здесь после синхронизации.';

  @override
  String get hardwareEmptyFilteredTitle => 'Фурнитура не найдена';

  @override
  String get hardwareEmptyFilteredMessage =>
      'Попробуйте изменить тип фурнитуры, наложение или сбросить фильтры.';

  @override
  String get priceVisibilityTitle => 'Цены для цеха';

  @override
  String get priceVisibilitySubtitle =>
      'Показывать цеху, складу и водителям цены клиентов и суммы заказов';

  @override
  String get priceVisibilitySaveFailed =>
      'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get defectPhotoAdd => 'Фото брака (по желанию)';

  @override
  String get defectPhotoChosen => 'Фото приложено';

  @override
  String get defectPhotoRemove => 'Убрать';

  @override
  String get defectPhotoNotSent =>
      'Этап записан, но фото брака не отправилось.';

  @override
  String get defectPhotoCameraFailed => 'Не удалось открыть камеру.';

  @override
  String get facadePricesTitle => 'Цены фасадов';

  @override
  String get facadePricesSubtitle => 'Цена за м² по фрезеровке и отделке';

  @override
  String get facadePricesAddMilling => 'Добавить фрезеровку';

  @override
  String get facadePricesMilling => 'Фрезеровка';

  @override
  String get facadePricesFinish => 'Отделка';

  @override
  String get facadePricesPricePerM2 => 'Цена за м²';

  @override
  String get facadePricesSold => 'Продаётся';

  @override
  String get facadePricesNotSold => 'Не продаётся';

  @override
  String get facadePricesSaved => 'Цена сохранена';

  @override
  String get facadePricesSave => 'Сохранить';

  @override
  String get facadeQuoteTitle => 'Расчёт заказа фасадов';

  @override
  String get facadeQuoteAddLine => 'Добавить фасад';

  @override
  String get facadeQuoteDemolition => 'Демонтаж';

  @override
  String get facadeQuotePrepaymentManual => 'Предоплата (если другая)';

  @override
  String facadeQuotePrepaymentDefault(String percent) {
    return 'По умолчанию $percent% от суммы';
  }

  @override
  String get facadeQuoteCalculate => 'Рассчитать';

  @override
  String get facadeQuoteNumberRequired => 'Введите число';

  @override
  String facadeQuoteLine(int number) {
    return 'Фасад $number';
  }

  @override
  String get facadeQuoteRemoveLine => 'Убрать';

  @override
  String get facadeQuoteWidth => 'Ширина, мм';

  @override
  String get facadeQuoteHeight => 'Высота, мм';

  @override
  String get facadeQuoteQty => 'Шт.';

  @override
  String get facadeQuoteDoubleSided => 'Двусторонний';

  @override
  String get facadeQuoteCustomerMaterial => 'Материал заказчика';

  @override
  String get facadeQuotePieces => 'Штук';

  @override
  String get facadeQuoteArea => 'Площадь';

  @override
  String get facadeQuoteTotal => 'Сумма';

  @override
  String get facadeQuotePrepayment => 'Предоплата';

  @override
  String get facadeQuoteBalance => 'Остаток';

  @override
  String get facadeRulesNotOffered => 'Не предлагается';

  @override
  String get facadeRulesTitle => 'Правила расчёта';

  @override
  String get facadeRulesDoubleSidedFactor => 'Коэффициент двустороннего (×)';

  @override
  String get facadeRulesEmptyMeansOff => 'Пусто — не предлагается';

  @override
  String get facadeRulesDiscount => 'Скидка за материал заказчика';

  @override
  String get facadeRulesDemolitionRate => 'Цена демонтажа';

  @override
  String get facadeRulesPrepayment => 'Предоплата по умолчанию';

  @override
  String get facadeOrderSection => 'Оформить заказ';

  @override
  String get facadeOrderPickCustomer => 'Выберите клиента';

  @override
  String get facadeOrderSearchCustomer => 'Имя — нажмите Enter';

  @override
  String get facadeOrderNoCustomers => 'Клиенты не найдены';

  @override
  String get facadeOrderPickDate => 'Выберите срок сдачи';

  @override
  String facadeOrderDueOn(String date) {
    return 'Срок: $date';
  }

  @override
  String get facadeOrderCreate => 'Создать заказ';

  @override
  String facadeOrderCreated(String name) {
    return 'Заказ $name создан';
  }

  @override
  String orderPrepaymentDue(String amount) {
    return 'Ждём предоплату: $amount';
  }

  @override
  String get facadeJobsTitle => 'Фасады в работу';

  @override
  String get facadeJobsEmptyTitle => 'Фасадов в работе нет';

  @override
  String get facadeJobsEmptyMessage =>
      'Фасады появятся здесь, когда будет оформлен заказ.';

  @override
  String facadeJobsDue(String date) {
    return 'срок $date';
  }

  @override
  String get pieceWorkTitle => 'Сдельная оплата';

  @override
  String get pieceWorkMine => 'Моя выработка';

  @override
  String get pieceWorkNothingYet => 'Пока ничего не начислено';

  @override
  String get pieceWorkPending => 'Ждёт утверждения';

  @override
  String get pieceWorkApproved => 'Утверждено';

  @override
  String get pieceWorkPaid => 'Выплачено';

  @override
  String get pieceWorkRejected => 'Отклонено';

  @override
  String get pieceWorkPcs => 'шт.';

  @override
  String get pieceWorkToApprove => 'На утверждение';

  @override
  String get pieceWorkNothingToApprove => 'Утверждать нечего';

  @override
  String get pieceWorkApprove => 'Утвердить';

  @override
  String get pieceWorkReject => 'Отклонить';

  @override
  String get pieceWorkReason => 'Причина — работник её увидит';

  @override
  String get pieceWorkRates => 'Тарифы';

  @override
  String get pieceWorkAddRate => 'Добавить тариф';

  @override
  String get pieceWorkDisabled => 'Отключён';

  @override
  String get pieceWorkCoefficients => 'Сверхурочные и выходные';

  @override
  String get pieceWorkOvertime => 'Сверхурочно';

  @override
  String get pieceWorkWeekend => 'Выходной';

  @override
  String get pieceWorkAfter => 'после';

  @override
  String get pieceWorkNoCoefficient => 'как обычно';

  @override
  String get pieceWorkOperation => 'Операция';

  @override
  String get pieceWorkOperationHint =>
      'Как в цехе (например «Раскрой») или «Фасад» — за готовые фасады';

  @override
  String get pieceWorkPerPiece => 'за штуку';

  @override
  String get pieceWorkRate => 'Тариф';

  @override
  String get pieceWorkEnabled => 'Действует';

  @override
  String get pieceWorkShiftEnd => 'Смена заканчивается в (ЧЧ:ММ)';

  @override
  String get pieceWorkSaturdayOff => 'Суббота — выходной';

  @override
  String get pieceWorkSundayOff => 'Воскресенье — выходной';

  @override
  String pieceWorkEstimate(String amount) {
    return 'Сдельно: ~$amount';
  }

  @override
  String get expensesTitle => 'Срочные расходы';

  @override
  String get expensesAdd => 'Записать расход';

  @override
  String get expensesPendingTotal => 'Ждёт решения';

  @override
  String get expensesEmptyTitle => 'Расходов нет';

  @override
  String get expensesEmptyMessage =>
      'Потратили деньги по работе? Запишите здесь, с чеком.';

  @override
  String get expensesFiled => 'Расход записан';

  @override
  String get expensesReceiptNotSent => 'Записано, но фото чека не отправилось.';

  @override
  String get expensesAmount => 'Сумма';

  @override
  String get expensesPurpose => 'На что';

  @override
  String get expensesCategory => 'Категория';

  @override
  String get expensesReceipt => 'Фото чека';

  @override
  String get pinAdminTitle => 'Вход по PIN';

  @override
  String get pinAdminSubtitle => 'Планшеты цеха и кто на них входит';

  @override
  String get pinAdminTablets => 'Планшеты';

  @override
  String get pinAdminRegisterThis => 'Сделать это устройство планшетом для PIN';

  @override
  String pinAdminThisIs(String label) {
    return 'Это устройство: $label';
  }

  @override
  String get pinAdminRevoked => 'Отключён';

  @override
  String get pinAdminRevoke => 'Отключить';

  @override
  String get pinAdminPeople => 'Сотрудники с PIN';

  @override
  String get pinAdminLocked => 'Заблокирован после неверных попыток';

  @override
  String get pinAdminClear => 'Снять PIN';

  @override
  String get pinAdminAssign => 'Назначить PIN';

  @override
  String get pinAdminTabletName => 'Название планшета, например «Цех, раскрой»';

  @override
  String get pinAdminRegistered => 'Планшет зарегистрирован';

  @override
  String get pinAdminChoosePerson => 'Сотрудник';

  @override
  String get pinAdminNewPin => 'PIN, от 4 до 6 цифр';

  @override
  String get pinAdminPinSet => 'PIN назначен';

  @override
  String get pinLoginTitle => 'Войти по PIN';

  @override
  String get pinLoginSubtitle => 'Выберите себя и введите PIN';

  @override
  String get pinLoginUnavailableTitle => 'Этот планшет не настроен для PIN';

  @override
  String get pinLoginUnavailableMessage =>
      'Попросите администратора зарегистрировать его в настройках.';

  @override
  String get pinLoginPin => 'PIN';

  @override
  String get materialStockTitle => 'Склад материалов';

  @override
  String get materialStockOnHand => 'Остатки';

  @override
  String get materialStockReceive => 'Приход';

  @override
  String get materialStockLists => 'Справочники';

  @override
  String get materialStockEmptyTitle => 'На складе пока ничего нет';

  @override
  String get materialStockEmptyMessage =>
      'Купленное появится здесь после прихода.';

  @override
  String materialStockAverage(String price) {
    return 'Средняя цена $price';
  }

  @override
  String get materialStockFillAll => 'Заполните все поля.';

  @override
  String materialStockReceived(String title, String onHand) {
    return '$title: оприходовано, теперь $onHand';
  }

  @override
  String get materialStockName => 'Название материала';

  @override
  String get materialStockSupplier => 'У кого купили';

  @override
  String get materialStockQty => 'Сколько';

  @override
  String get materialStockUnit => 'Единица';

  @override
  String get materialStockPrice => 'Цена за единицу';

  @override
  String get materialStockSuppliers => 'Поставщики';

  @override
  String get materialStockAdd => 'Добавить';

  @override
  String materialStockAdded(String value) {
    return '«$value» добавлено';
  }

  @override
  String materialStockOff(String value) {
    return '$value (отключено)';
  }

  @override
  String get materialStockOpen => 'Склад материалов';

  @override
  String get directionAll => 'Все';

  @override
  String get directionFurniture => 'Мебель';

  @override
  String get directionFacades => 'Фасады';

  @override
  String get orderUrgent => 'Срочно';

  @override
  String get tierNew => 'Новый';

  @override
  String get tierRegular => 'Постоянный';

  @override
  String get tierVip => 'VIP';

  @override
  String get facadeSpecTitle => 'Технические параметры';

  @override
  String get facadeSpecThickness => 'Толщина, мм';

  @override
  String get facadeSpecDecorTop => 'Декор лицевой';

  @override
  String get facadeSpecDecorBottom => 'Декор обратной';

  @override
  String get facadeSpecEdge => 'Профиль кромки';

  @override
  String get facadeSpecNone => '—';

  @override
  String facadeSpecGroup(String group) {
    return 'группа «$group»';
  }

  @override
  String materialStockHeld(String onHand, String reserved) {
    return 'На складе $onHand · в резерве $reserved';
  }

  @override
  String materialStockFree(String qty) {
    return 'свободно $qty';
  }

  @override
  String get facadeMaterialsTitle => 'Материалы под заказ';

  @override
  String facadeMaterialsLine(String needed, String held, String issued) {
    return 'нужно $needed · в резерве $held · списано $issued';
  }

  @override
  String facadeMaterialsShort(String qty) {
    return 'не хватает $qty';
  }

  @override
  String get facadeMaterialsHeld => 'Всё зарезервировано';

  @override
  String get facadeMaterialsReserve => 'Зарезервировать свободное';

  @override
  String get facadeMaterialsEmpty => 'Со склада ничего не нужно';

  @override
  String get crewTitle => 'Кто делал?';

  @override
  String get crewHint =>
      'Отметьте бригаду. Доли в % — по желанию, пусто — поровну.';

  @override
  String get crewTooSmall => 'Бригада — не меньше двух человек.';

  @override
  String get crewSharesAllOrNone =>
      'Укажите доли всем — или никому, тогда поровну.';

  @override
  String get crewDone => 'Готово';

  @override
  String get crewDoneTogether => 'Готово — делали вместе…';

  @override
  String get payrollTitle => 'Ведомость';

  @override
  String get payrollCopyCsv => 'Скопировать для бухгалтерии (CSV)';

  @override
  String get payrollCsvCopied => 'Ведомость скопирована — вставьте в Excel';

  @override
  String get payrollPrevMonth => 'Предыдущий месяц';

  @override
  String get payrollNextMonth => 'Следующий месяц';

  @override
  String get payrollEmpty => 'За этот месяц начислений нет';

  @override
  String get payrollTotal => 'Итого к выплате';

  @override
  String get payrollPiece => 'Сдельно';

  @override
  String get payrollDailyBonus => 'Премии за день';

  @override
  String get payrollMonthlyBonus => 'Премия за месяц';

  @override
  String get payrollBonus => 'Премия';

  @override
  String get payrollFine => 'Штрафы';

  @override
  String get payrollAdvance => 'Авансы';

  @override
  String payrollPending(String amount) {
    return 'Ещё не утверждено: $amount';
  }

  @override
  String get payrollAdjustments => 'Авансы, штрафы, премии';

  @override
  String get payrollAddAdjustment => 'Внести';

  @override
  String get payrollNoAdjustments => 'В этом месяце нет';

  @override
  String get payrollReverse => 'Сторнировать';

  @override
  String get payrollEmployee => 'Сотрудник';

  @override
  String get payrollAmount => 'Сумма';

  @override
  String get payrollReason => 'Причина';

  @override
  String get bonusToday => 'Премия за день';

  @override
  String get bonusMonth => 'Премия за месяц';

  @override
  String bonusReached(String bonus) {
    return 'Достигнуто — премия $bonus';
  }

  @override
  String bonusLeft(String left, String bonus) {
    return 'До премии $bonus осталось $left';
  }

  @override
  String get bonusRules => 'Премии';

  @override
  String bonusRuleDay(String threshold, String bonus) {
    return 'От $threshold за день — $bonus';
  }

  @override
  String bonusRuleMonth(String threshold, String bonus) {
    return 'От $threshold за месяц — $bonus';
  }

  @override
  String get bonusDayThreshold => 'Порог дня';

  @override
  String get bonusDayAmount => 'Премия за день';

  @override
  String get bonusMonthThreshold => 'Порог месяца';

  @override
  String get bonusMonthAmount => 'Премия за месяц';

  @override
  String get crewSplitPercent => 'В %';

  @override
  String crewSplitByAmount(String unit) {
    return 'Кто сколько, $unit';
  }

  @override
  String get crewHintAmount =>
      'Отметьте бригаду и впишите, кто сколько сделал. Сумма должна сойтись с итогом.';

  @override
  String get crewMadeTogether => 'Делали вместе…';

  @override
  String crewChosen(int count) {
    return 'Бригада: $count чел.';
  }

  @override
  String get crewClear => 'Убрать бригаду';

  @override
  String get unitPieces => 'шт';

  @override
  String get unitSquareMetres => 'м²';

  @override
  String get payrollPaid => 'Выплачено';

  @override
  String get payrollLeft => 'Остаток к выплате';

  @override
  String get payrollMarkPaid => 'Отметить выплату';

  @override
  String payrollMarkPaidConfirm(String name, String amount) {
    return '$name: выплачено $amount? Период закроется — авансы, штрафы и премии за него больше не внести.';
  }

  @override
  String get payrollMarkPaidDone => 'Выплата записана';

  @override
  String get payrollTotalLeft => 'Осталось выплатить';

  @override
  String get tradesAction => 'Профессии в цехе';

  @override
  String get tradesTitle => 'Чем занимается';

  @override
  String get tradesHint =>
      'Можно несколько. Профессии не дают прав — права задаёт должность.';

  @override
  String get tradesOwn => 'Своя профессия';

  @override
  String get tradesAdd => 'Добавить';

  @override
  String get tradesSaved => 'Профессии сохранены';

  @override
  String get oneCTitle => 'Обмен с 1С';

  @override
  String get oneCSubtitle =>
      'Выгрузка продаж, оплат, поступлений и ведомости для бухгалтерии';

  @override
  String get oneCEnabled => 'Обмен с 1С включён';

  @override
  String get oneCOffHint =>
      'Обмен выключен. Если в компании 1С не ведут, так и оставьте.';

  @override
  String get oneCHowTo =>
      'В 1С: «Загрузка данных из табличного документа» — вставьте скопированное. Даты ДД.ММ.ГГГГ, дробная часть через запятую.';

  @override
  String get oneCCopy => 'Скопировать';

  @override
  String oneCCopied(String title, int count) {
    return '$title: строк — $count. Вставьте в 1С.';
  }

  @override
  String get pressLayoutTitle => 'Раскладка на пресс';

  @override
  String get pressTextured => 'ТЕКСТУРА — НЕ ВРАЩАТЬ';

  @override
  String get pressPlain => 'Однотонная — можно вращать';

  @override
  String pressLoad(int count, String metres) {
    return 'Загрузка $count · секция $metres м';
  }

  @override
  String pressFilmTotal(String metres) {
    return 'Плёнка: $metres м';
  }

  @override
  String pressCorrected(String reason, String metres) {
    return 'Поправлено вручную: $reason. По раскладке — $metres м.';
  }

  @override
  String pressTooBig(String positions) {
    return 'Больше стола пресса: позиции $positions';
  }

  @override
  String get pressCorrect => 'Поправить метраж';

  @override
  String get pressMetres => 'Метры плёнки';

  @override
  String get pressReason => 'Почему не по раскладке';

  @override
  String get pressBackToLayout => 'Вернуть по раскладке';

  @override
  String get pressNoFilm => 'В заказе нет фасадов в ПВХ-плёнке.';

  @override
  String get pressSettingsTitle => 'Пресс: поле, зазор, секции';

  @override
  String get pressLength => 'Рабочая длина, мм';

  @override
  String get pressWidth => 'Рабочая ширина, мм';

  @override
  String get pressMargin => 'Отступ от края, мм';

  @override
  String get pressGap => 'Зазор между деталями, мм';

  @override
  String get pressSections => 'Секции: плёнка и рабочая длина';

  @override
  String get pressSectionFilm => 'Плёнка, м';

  @override
  String get pressAddSection => 'Добавить секцию';

  @override
  String get pressSaved => 'Настройки пресса сохранены';

  @override
  String get materialTextured => 'Текстурная плёнка';

  @override
  String get materialTexturedHint =>
      'Детали не вращаются на прессе, на раскладке — «НЕ ВРАЩАТЬ»';

  @override
  String get pressPrint => 'Печать раскладки';

  @override
  String pressPrintLoad(int count, int total, String metres) {
    return 'Загрузка $count из $total · секция $metres м';
  }

  @override
  String pressPrintSheet(int count) {
    return 'Лист № $count';
  }

  @override
  String pressPrintCopies(int count) {
    return 'Кол-во копий: $count';
  }

  @override
  String pressPrintSize(String size) {
    return 'Размер: $size мм';
  }

  @override
  String pressPrintSection(String metres) {
    return 'Секция плёнки: $metres м';
  }

  @override
  String pressPrintArea(String area) {
    return 'S листа: $area м²';
  }

  @override
  String pressPrintParts(String area, String share) {
    return 'S деталей: $area м² ($share%)';
  }

  @override
  String pressPrintWaste(String area, String share) {
    return 'Отходы: $area м² ($share%)';
  }

  @override
  String pressPrintCount(int count) {
    return 'Кол-во деталей: $count';
  }

  @override
  String pressPrintPerimeter(String metres) {
    return 'Периметр деталей: $metres м';
  }

  @override
  String pressPrintGap(String gap, String margin) {
    return 'Зазор: $gap мм · отступ: $margin мм';
  }

  @override
  String get pressPrintDetails => 'Детали';

  @override
  String pressPrintPage(int count) {
    return 'Стр. $count';
  }

  @override
  String get logisticsTitle => 'Логистика';

  @override
  String get logisticsDeliveries => 'Доставки';

  @override
  String get logisticsSummary => 'Итоги';

  @override
  String get logisticsAdd => 'Записать доставку';

  @override
  String get logisticsEmpty => 'В этом месяце доставок нет';

  @override
  String get logisticsEmptyMessage =>
      'Газель, такси, транспортная компания — запишите, сколько стоило привезти материал.';

  @override
  String get logisticsAmount => 'Сколько стоила доставка';

  @override
  String get logisticsFrom => 'Откуда (город)';

  @override
  String get logisticsTransport => 'Чем привезли';

  @override
  String get logisticsCarrier => 'Перевозчик (необязательно)';

  @override
  String get logisticsWhat => 'Что привезли';

  @override
  String get logisticsQty => 'Сколько';

  @override
  String get logisticsUnit => 'Ед.';

  @override
  String get logisticsOrder => 'Заказ № (если для заказа)';

  @override
  String get logisticsOrderedOn => 'Заказали';

  @override
  String get logisticsDeliveredOn => 'Привезли';

  @override
  String get logisticsUrgent => 'Срочно (доплатили за скорость)';

  @override
  String get logisticsNote => 'Заметка';

  @override
  String get logisticsSaved => 'Доставка записана';

  @override
  String get logisticsCancel => 'Отменить запись';

  @override
  String get logisticsCancelReason => 'Почему отменяете';

  @override
  String logisticsCancelled(String reason) {
    return 'Отменено: $reason';
  }

  @override
  String logisticsDays(int count) {
    return 'в пути $count дн.';
  }

  @override
  String logisticsTotal(String amount) {
    return 'Всего за месяц: $amount';
  }

  @override
  String logisticsPrevious(String amount) {
    return 'Прошлый месяц: $amount';
  }

  @override
  String get logisticsByCategory => 'По материалам';

  @override
  String get logisticsByCity => 'По городам';

  @override
  String get logisticsByTransport => 'По способу доставки';

  @override
  String get logisticsByCarrier => 'По перевозчикам';

  @override
  String get logisticsPerUnit => 'За единицу';

  @override
  String logisticsPerUnitLine(String amount, String unit, String qty) {
    return '$amount за $unit · привезли $qty $unit';
  }

  @override
  String logisticsCount(int count) {
    return 'доставок: $count';
  }

  @override
  String logisticsAverageDays(String days) {
    return 'в пути в среднем $days дн.';
  }

  @override
  String logisticsUrgentLine(int count, String amount) {
    return 'Срочные: $count на $amount';
  }

  @override
  String get logisticsUnlinked => 'Приходы без доставки';

  @override
  String get logisticsUnlinkedHint =>
      'Материал пришёл, а доставку не записали. Запишите — или 0 ₸, если привёз поставщик.';

  @override
  String get logisticsWrite => 'Записать';

  @override
  String get logisticsDeliveryOptional => 'Доставка (если платили)';

  @override
  String get materialMin => 'Минимум на складе';

  @override
  String get materialMinHint =>
      'Когда свободного станет меньше, владельцу придёт «пора заказывать». Пусто или 0 — без предупреждения.';

  @override
  String materialLow(String minimum) {
    return 'Мало — минимум $minimum';
  }

  @override
  String get stockCountTab => 'Пересчёт';

  @override
  String get stockCountTitle => 'Что на полке сейчас';

  @override
  String get stockCountHint =>
      'Впишите, сколько насчитали. Пустые строки не трогаются. Расхождения с учётом проводятся одним документом, и расход месяца считается от этой цифры.';

  @override
  String stockCountBooks(String qty) {
    return 'По учёту: $qty';
  }

  @override
  String get stockCountOnShelf => 'на полке';

  @override
  String get stockCountSave => 'Сохранить пересчёт';

  @override
  String get stockCountNothing => 'Ничего не введено.';

  @override
  String stockCountSaved(int count) {
    return 'Пересчёт сохранён, расхождений: $count';
  }

  @override
  String get stockUsageTitle => 'Расход месяца';

  @override
  String get stockUsageNotCounted =>
      'В этом месяце склад ещё не пересчитывали — «осталось» пока по учёту.';

  @override
  String stockUsageCountedOn(String date) {
    return 'Пересчитано $date';
  }

  @override
  String stockUsageLine(String start, String bought, String end, String unit) {
    return 'Было $start · пришло $bought · осталось $end $unit';
  }

  @override
  String stockUsageUsed(String used, String orders) {
    return 'Ушло по факту $used, по заказам $orders';
  }

  @override
  String stockUsageLoss(String qty, String money) {
    return 'Не объяснено: $qty$money';
  }

  @override
  String get navFacades => 'Фасады на заказ';

  @override
  String get navFilmSale => 'Плёнка ПВХ — продажа';

  @override
  String get navWorkshop => 'Производство';

  @override
  String get navGroupSell => 'Что продаём';

  @override
  String get navGroupMoney => 'Деньги';

  @override
  String get navGroupCompany => 'Компания';

  @override
  String get facadesHint => 'МДФ-фасады: от расчёта до выдачи клиенту';

  @override
  String get facadesPath =>
      'Путь заказа — нажмите этап, чтобы открыть план цеха';

  @override
  String facadesStageM2(String area) {
    return '$area м²';
  }

  @override
  String get navMdf => 'МДФ';

  @override
  String get mdfOrders => 'Заказы';

  @override
  String get mdfOrdersHint => 'Все заказы: сроки, оплаты, долг';

  @override
  String get mdfQuoteHint => 'Позиции, м², цена — и сразу заказ';

  @override
  String get mdfJobsHint => 'Что в очереди, что в работе, что готово';

  @override
  String get mdfPress => 'Пресс';

  @override
  String get mdfPressHint => 'Размеры стола и секций; раскладка — из заказа';

  @override
  String get mdfStockHint => 'МДФ и плёнка: остатки, «мало», пересчёт';

  @override
  String get mdfLogisticsHint => 'Доставки МДФ и плёнки, сколько стоили';

  @override
  String get mdfPricesHint => 'Цена за м² по фрезеровке и покрытию';

  @override
  String get facadePricesEmptyNotSold => 'Пусто — не продаётся';

  @override
  String get facadePricesNeedOne => 'Укажите цену хотя бы для одной отделки.';

  @override
  String get mdfOrdersTitle => 'Заказы МДФ';

  @override
  String get mdfOrderNew => 'Новый заказ';

  @override
  String get mdfOrderSearch => '№, клиент, телефон, цвет';

  @override
  String get mdfFilterAll => 'Все';

  @override
  String get mdfFilterOverdue => 'Просрочено';

  @override
  String get mdfFilterDebt => 'С долгом';

  @override
  String get mdfStatusDraft => 'Черновик';

  @override
  String get mdfStatusAccepted => 'Принят';

  @override
  String get mdfStatusInShop => 'В цеху';

  @override
  String get mdfStatusReady => 'Готов';

  @override
  String get mdfStatusHandedOver => 'Выдан';

  @override
  String get mdfStatusOnHold => 'Приостановлен';

  @override
  String get mdfStatusCancelled => 'Отменён';

  @override
  String get mdfStageCut => 'Раскрой';

  @override
  String get mdfStageMill => 'ЧПУ';

  @override
  String get mdfStageSand => 'Шлифовка';

  @override
  String get mdfStageVacuum => 'Вакуум';

  @override
  String get mdfStagePaint => 'Краска';

  @override
  String get mdfEmpty => 'Заказов пока нет';

  @override
  String get mdfEmptyHint => 'Нажмите «Новый заказ», чтобы оформить первый.';

  @override
  String mdfDebt(String amount) {
    return 'Долг $amount';
  }

  @override
  String get mdfCustomer => 'Клиент';

  @override
  String get mdfDue => 'Срок';

  @override
  String get mdfHeadSection => 'Параметры фасада';

  @override
  String get mdfThickness => 'Толщина, мм';

  @override
  String get mdfFinish => 'Покрытие';

  @override
  String get mdfDecorTop => 'Цвет лица';

  @override
  String get mdfDecorBottom => 'Цвет обратной стороны';

  @override
  String get mdfPatina => 'Патина';

  @override
  String get mdfMilling => 'Фрезеровка';

  @override
  String get mdfEdge => 'Кромка';

  @override
  String get mdfExtraName => 'Объект (кухня, адрес)';

  @override
  String get mdfDefaultRate => 'Цена за м² по умолчанию';

  @override
  String get mdfNone => '—';

  @override
  String get mdfLinesSection => 'Позиции';

  @override
  String get mdfHeight => 'Высота';

  @override
  String get mdfWidth => 'Ширина';

  @override
  String get mdfQty => 'Кол.';

  @override
  String get mdfNote => 'Примечание';

  @override
  String get mdfRate => 'Цена м²';

  @override
  String get mdfArea => 'м²';

  @override
  String get mdfAmount => 'Сумма';

  @override
  String get mdfAddLine => 'Добавить строку';

  @override
  String get mdfNoPrice => 'нет цены';

  @override
  String get mdfManualRate => 'цена вручную';

  @override
  String mdfTotals(String pieces, String area, String total) {
    return '$pieces шт · $area м² · $total';
  }

  @override
  String mdfPaidDebt(String paid, String debt) {
    return 'Оплачено $paid · Долг $debt';
  }

  @override
  String get mdfSaveDraft => 'Сохранить';

  @override
  String get mdfAccept => 'Принять заказ';

  @override
  String get mdfDeleteDraft => 'Удалить черновик';

  @override
  String get mdfSaved => 'Заказ сохранён';

  @override
  String get mdfAccepted => 'Заказ принят — цены зафиксированы';

  @override
  String get mdfNeedCustomer => 'Выберите клиента и срок.';

  @override
  String get mdfNeedLine => 'Добавьте хотя бы одну позицию.';

  @override
  String get mdfStagesSection => 'Этапы';

  @override
  String get mdfPaymentsSection => 'Оплаты';

  @override
  String get mdfAddPayment => 'Внести оплату';

  @override
  String get mdfPaymentAmount => 'Сумма, ₸';

  @override
  String get mdfPaymentMethod => 'Способ';

  @override
  String get mdfNoPayments => 'Оплат пока нет';

  @override
  String get mdfHold => 'Приостановить';

  @override
  String get mdfResume => 'Возобновить';

  @override
  String get mdfHoldReason => 'Почему приостановлен';

  @override
  String get mdfCancelOrder => 'Отменить заказ';

  @override
  String get mdfCancelReason => 'Причина отмены';

  @override
  String get mdfHandOver => 'Выдать клиенту';

  @override
  String get mdfHandOverComment => 'Почему выдаём с долгом';

  @override
  String get mdfOverdue => 'Просрочен';

  @override
  String get mdfDueSoon => 'Срок скоро';

  @override
  String get mdfConfirm => 'Готово';

  @override
  String get mdfCancel => 'Отмена';

  @override
  String get mdfLineDelete => 'Удалить строку';

  @override
  String get mdfLineDuplicate => 'Дублировать';

  @override
  String get mdfChangeAccepted =>
      'Принятый заказ меняется через «Изменить заказ» — скоро.';

  @override
  String mdfPrintTitle(String name) {
    return 'Заказ №$name';
  }

  @override
  String get mdfPrintAccepted => 'Принят';

  @override
  String get mdfPrintPhone => 'Телефон';

  @override
  String get mdfPrintPaid => 'Предоплата';

  @override
  String get mdfPrintDebt => 'Остаток';

  @override
  String get mdfPrintTotal => 'Итого:';

  @override
  String get mdfPrintClient => 'Бланк клиенту';

  @override
  String get mdfPrintShop => 'Наряд в цех';

  @override
  String get mdfPasteSizes => 'Вставить размеры';

  @override
  String get mdfPasteHint =>
      'Скопируйте размеры из WhatsApp, Excel или бланка — по одной детали в строке: «348 997 2», «348х997-2шт». Слова после количества станут примечанием.';

  @override
  String mdfPasteFound(int count) {
    return 'Найдено строк: $count';
  }

  @override
  String mdfPasteSkipped(String rows) {
    return 'Пропущено (не размеры): $rows';
  }

  @override
  String get mdfPasteAdd => 'Добавить в заказ';

  @override
  String mdfPasted(int count) {
    return 'Добавлено строк: $count';
  }

  @override
  String get mdfNewCustomer => 'Новый клиент';

  @override
  String mdfNewCustomerOption(String name) {
    return '+ Новый клиент «$name»';
  }

  @override
  String get mdfRepeat => 'Повторить заказ';

  @override
  String get filmShortageTitle => 'Плёнка: что докупить';

  @override
  String get filmShortageEmpty => 'Плёнка для заказов не нужна';

  @override
  String get filmShortageEmptyHint =>
      'Здесь появятся принятые заказы с плёнкой, пока не отмечен вакуум.';

  @override
  String filmShortageTotals(String needed, String toBuy) {
    return 'Нужно $needed м · докупить $toBuy м';
  }

  @override
  String get filmShortageByFilm => 'По плёнке';

  @override
  String get filmShortageByOrder => 'По заказам';

  @override
  String filmShortageLine(
    String orders,
    String needed,
    String held,
    String free,
    String unit,
  ) {
    return 'Заказов $orders · нужно $needed · под заказы $held · свободно $free $unit';
  }

  @override
  String filmShortageBuy(String qty, String unit) {
    return 'Докупить $qty $unit';
  }

  @override
  String get filmShortageEnough => 'Хватает';

  @override
  String filmShortageShort(String qty) {
    return 'не хватает $qty м';
  }

  @override
  String get filmShortageNotOnBooks =>
      'Этой плёнки нет в складе — добавьте её в «Склад».';

  @override
  String get mdfFilmHint => 'Сколько метров какой плёнки заказать у поставщика';

  @override
  String get mdfDebtsTitle => 'Долги';

  @override
  String get mdfDebtsEmpty => 'Долгов нет';

  @override
  String get mdfDebtsEmptyHint => 'Все принятые заказы оплачены.';

  @override
  String mdfDebtsTotal(String amount) {
    return 'Всего долгов: $amount';
  }

  @override
  String get mdfDebtsByCustomer => 'По клиентам';

  @override
  String get mdfDebtsByOrder => 'По заказам';

  @override
  String mdfDebtsOrders(int count) {
    return 'Заказов с долгом: $count';
  }

  @override
  String get mdfDebtsHandedOver => 'Выдан с долгом';

  @override
  String get mdfDebtsHint => 'Кто сколько должен — по клиентам и заказам';

  @override
  String get mdfBatchTitle => 'Детали по плёнке';

  @override
  String get mdfBatchHint =>
      'Все детали открытых заказов одной плёнки — одним списком';

  @override
  String get mdfBatchShow => 'Показать';

  @override
  String mdfBatchTotals(String orders, String pieces, String area) {
    return 'Заказов $orders · деталей $pieces шт · $area м²';
  }

  @override
  String get mdfBatchParts => 'Детали (одинаковые размеры сложены)';

  @override
  String get mdfBatchLong => 'Длина';

  @override
  String get mdfBatchShort => 'Ширина';

  @override
  String get mdfBatchOrders => 'Заказы';

  @override
  String get mdfChangeOrder => 'Изменить заказ';

  @override
  String get mdfChangeReason => 'Что и почему меняется';

  @override
  String get mdfSaveChange => 'Сохранить изменения';

  @override
  String get mdfChanged => 'Заказ изменён — записано в историю';

  @override
  String get mdfHistorySection => 'История';

  @override
  String get mdfPlanTitle => 'Цех — план и факт';

  @override
  String get mdfPlanHint => 'Что ждёт на каждом этапе и сколько м²';

  @override
  String mdfPlanInWork(String area) {
    return 'В работе: $area м²';
  }

  @override
  String get mdfPlanTick => 'Этап готов';

  @override
  String mdfPlanTicked(String order, String stage) {
    return '$order: «$stage» отмечен';
  }

  @override
  String get mdfPlanIntake => 'Приём заказов по дням';

  @override
  String mdfPlanIntakeDay(String orders, String area) {
    return '$orders зак. · $area м²';
  }

  @override
  String get mdfCashTitle => 'Касса';

  @override
  String get mdfCashHint => 'Оплаты по способам, расходы и остаток';

  @override
  String get mdfCashToday => 'Сегодня';

  @override
  String get mdfCashWeek => '7 дней';

  @override
  String get mdfCashMonth => '30 дней';

  @override
  String get mdfCashIn => 'Пришло';

  @override
  String get mdfCashOut => 'Ушло';

  @override
  String get mdfCashNet => 'Остаток';

  @override
  String get mdfCashByDay => 'По дням';

  @override
  String get mdfCashPayments => 'Оплаты';

  @override
  String get mdfCashNoPayments => 'За этот период оплат нет';

  @override
  String get mdfCashExpenses => 'Расходы';

  @override
  String get mdfReportTitle => 'Отчёт по заказам';

  @override
  String get mdfReportHint => 'Сколько заказов, м² и денег за период';

  @override
  String get mdfReportThisMonth => 'Этот месяц';

  @override
  String get mdfReportLastMonth => 'Прошлый';

  @override
  String get mdfReportYear => 'Год';

  @override
  String get mdfReportOrders => 'Заказов';

  @override
  String get mdfReportArea => 'Площадь';

  @override
  String get mdfReportTotal => 'Сумма';

  @override
  String get mdfReportPaid => 'Оплачено';

  @override
  String get mdfReportDebt => 'Долг';

  @override
  String get mdfReportCancelled => 'Отменено';

  @override
  String get mdfReportByDecor => 'По плёнкам';

  @override
  String get mdfReportTopCustomers => 'Лучшие клиенты';

  @override
  String mdfReportLine(String orders, String area, String total) {
    return '$orders зак. · $area м² · $total';
  }

  @override
  String mdfReportOwes(String amount) {
    return 'долг $amount';
  }

  @override
  String mdfVolumeVersus(String arrow, int pct) {
    return '$arrow $pct% к прошлому периоду';
  }

  @override
  String get mdfVolumeDone => 'Сделано по этапам';

  @override
  String get mdfVolumeQueue => 'Ждут сейчас — где пробка';

  @override
  String get mdfVolumeTitle => 'Цех — объём работ';

  @override
  String get mdfVolumeHint => 'Сколько м² сделал каждый по этапам';

  @override
  String get mdfVolumeByWorker => 'По сотрудникам';

  @override
  String get mdfVolumeEmpty => 'За этот период этапы не отмечены';

  @override
  String mdfVolumeUnassigned(String area) {
    return 'Без исполнителя: $area';
  }

  @override
  String get mdfWhoDidIt => 'Кто сделал этот этап?';

  @override
  String get mdfWorkerNobody => 'Не указывать';

  @override
  String get mdfDictTitle => 'Справочники';

  @override
  String get mdfDictHint =>
      'Толщина, покрытие, цвета, патина, фрезеровка, кромка';

  @override
  String get mdfDictOpen => 'Справочник';

  @override
  String get mdfDictDecor => 'Цвет плёнки';

  @override
  String get mdfDictAdd => 'Добавить';

  @override
  String get mdfDictRename => 'Изменить';

  @override
  String get mdfDictDelete => 'Удалить';

  @override
  String get mdfDictValue => 'Значение';

  @override
  String get mdfDictEmpty => 'Список пуст. Нажмите «+», чтобы добавить.';

  @override
  String mdfDictDeleteAsk(String value) {
    return 'Удалить «$value»? Если оно уже есть в заказах, оно просто исчезнет из списка, заказы не изменятся.';
  }

  @override
  String get mdfCustomers => 'Клиенты';

  @override
  String get mdfCustomerSearch => 'Имя, телефон или организация';

  @override
  String get mdfNothingFound => 'Ничего не найдено';

  @override
  String get mdfCustomerName => 'Имя';

  @override
  String get mdfCustomerPhone => 'Телефон';

  @override
  String get mdfCustomerOrg => 'Организация';

  @override
  String mdfCustomerDeleteAsk(String name) {
    return 'Удалить клиента «$name»? Если у него есть заказы, он просто исчезнет из списка, заказы останутся.';
  }

  @override
  String get mdfMaterial => 'Материал';

  @override
  String get mdfFilm => 'Плёнка';

  @override
  String get mdfFilmNone => 'Плёнка не выбрана';

  @override
  String get mdfFilmPick => 'Плёнка группы';

  @override
  String get mdfFilmRate => 'Цена за м²';

  @override
  String get mdfFilmRemove => 'Убрать группу';

  @override
  String mdfFilmRemoveAsk(String film) {
    return 'Убрать группу «$film» вместе с её позициями?';
  }

  @override
  String get mdfFilmSubtotal => 'Итого группы';

  @override
  String get mdfAddFilm => 'Добавить покрытие';

  @override
  String get mdfBackSide => 'Обратная сторона';

  @override
  String get mdfBackSideShort => 'обр.';

  @override
  String get mdfTagUrgent => 'Срочный';

  @override
  String get mdfTagRework => 'Переделка';

  @override
  String get mdfTagWarranty => 'Гарантия';

  @override
  String get mdfTagVip => 'VIP';

  @override
  String get mdfTagFurnitureMaker => 'Мебельщик';

  @override
  String get mdfTagNew => 'Новый';

  @override
  String get mdfTagPrepayOnly => 'Только предоплата';

  @override
  String get mdfFilterUrgent => 'Срочные';

  @override
  String get mdfFilterFurnitureMakers => 'Мебельщики';

  @override
  String get mdfFilterRework => 'Переделки';

  @override
  String get mdfColEdge => 'Край';

  @override
  String get mdfEdgeDefault => 'Край по умолчанию';

  @override
  String get mdfExtraAdd => '+ доп.';

  @override
  String get mdfDeadlineToday => 'Сегодня';

  @override
  String get mdfDeadlineTomorrow => 'Завтра';

  @override
  String get mdfDeadlineLater => 'Дальше';

  @override
  String get mdfAtRisk => 'Не успевает';

  @override
  String get mdfTvTitle => 'Экран цеха';

  @override
  String get mdfTvHint => 'Сегодня, завтра, дальше — для телевизора в цехе';

  @override
  String mdfPrepayOnlyAsk(String customer) {
    return '$customer: только предоплата, а оплаты нет. Всё равно принять?';
  }

  @override
  String get mdfThicknessShort => 'Толщина';

  @override
  String get mdfCopyOrder => 'Копировать заказ';

  @override
  String get mdfAddStage => 'этап';

  @override
  String get mdfStageReady => 'Готово';

  @override
  String get mdfPayTransfer => 'Перевод';

  @override
  String get mdfPayCash => 'Наличные';

  @override
  String get mdfPayCard => 'Карта';

  @override
  String get mdfPayBank => 'Банк';

  @override
  String get mdfDictBank => 'Банки';

  @override
  String get mdfDictLocked => 'Постоянное значение — не удаляется';

  @override
  String get mdfCoatingPvc => 'ПВХ';

  @override
  String get mdfCoatingPaint => 'Краска';

  @override
  String get mdfCoatingRaw => 'Черновой';

  @override
  String get mdfCoatingPick => 'Какое покрытие?';

  @override
  String get mdfColor => 'Цвет';

  @override
  String get mdfDictPaint => 'Краски';

  @override
  String get mdfPaintNone => 'Краска не выбрана';

  @override
  String get mdfCoatingNotChosen => 'Покрытие не выбрано';

  @override
  String mdfCoatingSwitchAsk(String film, String coating) {
    return '«$film» нет в справочнике «$coating». Цвет блока сбросится, позиции, размеры и цены останутся. Сменить?';
  }

  @override
  String get mdfColCoating => 'Покрытие';

  @override
  String get mdfPrintHeightShort => 'Выс.';

  @override
  String get mdfPrintWidthShort => 'Шир.';

  @override
  String get mdfPrintThickShort => 'Толщ.';

  @override
  String get mdfPrintMaterialShort => 'Матер.';

  @override
  String get mdfPrintSubtotal => 'Итого';

  @override
  String get mdfPrintPieces => 'шт';

  @override
  String get mdfChangesTitle => 'Что изменилось';

  @override
  String get mdfReasonClient => 'Клиент изменил';

  @override
  String get mdfReasonMistake => 'Ошибка при приёме';

  @override
  String get mdfReasonAdded => 'Добавили позиции';

  @override
  String get mdfReasonPrice => 'Изменили цену';

  @override
  String get mdfLeaveUnsaved => 'Выйти без сохранения? Изменения пропадут.';

  @override
  String get mdfLeave => 'Выйти';

  @override
  String mdfChangeAdded(int n) {
    return 'Добавлена позиция $n';
  }

  @override
  String mdfChangeRemoved(int n) {
    return 'Убрана позиция $n';
  }

  @override
  String get mdfTagsTitle => 'Метки';

  @override
  String mdfDueInDays(int n) {
    return '+$n дн.';
  }

  @override
  String get mdfDueCalendar => 'Выбрать в календаре…';

  @override
  String get mdfPaymentFix => 'Исправить';

  @override
  String get mdfPaymentDelete => 'Удалить оплату';

  @override
  String get mdfPaymentFixTitle => 'Исправить оплату';

  @override
  String get mdfPaymentReason => 'Причина';

  @override
  String get mdfPayReasonAmount => 'Ошибка в сумме';

  @override
  String get mdfPayReasonMethod => 'Не тот способ';

  @override
  String get mdfPayReasonBank => 'Не тот банк';

  @override
  String get mdfPayReasonTwice => 'Внесли дважды';

  @override
  String get mdfPaymentCancelled => 'отменена';

  @override
  String get mdfHandOverCheck => 'Проверка перед выдачей';

  @override
  String get mdfHandOverStagesDone => 'Все этапы пройдены';

  @override
  String mdfHandOverCounted(int n) {
    return 'Пересчитал детали: $n шт';
  }

  @override
  String get mdfTakenByClient => 'Клиент';

  @override
  String get mdfTakenByOther => 'Другой человек';

  @override
  String get mdfTakenByName => 'Кто забрал';

  @override
  String get mdfTakenByPhone => 'Телефон';

  @override
  String mdfHandedOverOn(String date) {
    return 'Выдан $date';
  }

  @override
  String mdfHandedOverBy(String name) {
    return 'выдал $name';
  }

  @override
  String mdfTakenBy(String who) {
    return 'забрал $who';
  }

  @override
  String mdfHandedWithDebt(String amount) {
    return 'с долгом $amount';
  }

  @override
  String get mdfReturnToWork => 'Вернуть в работу';

  @override
  String get mdfReturnReason => 'Почему возвращаете в работу';

  @override
  String get mdfHandedOverDone => 'Заказ выдан';

  @override
  String get mdfPayOrderTotal => 'Заказ';

  @override
  String get mdfPayPaid => 'Оплачено';

  @override
  String get mdfPayLeft => 'Остаток';

  @override
  String get mdfPayAddPart => 'Ещё способ';

  @override
  String mdfPayAfter(String sum, String debt) {
    return 'Итого $sum · долг после оплаты $debt';
  }

  @override
  String mdfPayOver(String amount) {
    return 'Больше остатка на $amount. Похоже, оплата уже внесена';
  }

  @override
  String get mdfPayOverOk => 'Это переплата / аванс';

  @override
  String get mdfNoteShort => 'Прим.';

  @override
  String get filmCatalogTitle => 'Плёнки ПВХ';

  @override
  String get filmMaker => 'Производитель';

  @override
  String get filmType => 'Поверхность плёнки';

  @override
  String get filmAllTypes => 'Любая поверхность';

  @override
  String filmSearchIn(String maker) {
    return 'Поиск в $maker';
  }

  @override
  String filmHave(String metres) {
    return 'есть · $metres м';
  }

  @override
  String get filmToOrder => 'заказать';

  @override
  String get filmOff => 'в архиве';

  @override
  String get filmUnassigned => 'не указан';

  @override
  String get filmUnassignedHint =>
      'Цвета из старого списка, без производителя. Если такая плёнка нужна — добавьте её у производителя кнопкой «Плёнка», а здесь уберите. Старые заказы останутся как есть.';

  @override
  String get filmCode => 'Код';

  @override
  String get filmRal => 'Близкий RAL';

  @override
  String get filmSupplier => 'Поставщик';

  @override
  String get filmPriceM => 'Закуп, ₸/м';

  @override
  String get filmUrl => 'Ссылка на сайт';

  @override
  String get filmSave => 'Сохранить';

  @override
  String get filmAdd => 'Плёнка';

  @override
  String filmEmpty(String maker) {
    return 'У $maker пока нет плёнок. Нажмите «Плёнка», чтобы добавить первую.';
  }

  @override
  String get filmName => 'Название плёнки';

  @override
  String get filmThickness => 'Толщина, мм';

  @override
  String get filmWidth => 'Ширина рулона, мм';

  @override
  String get filmDeptTitle => 'Отдел плёнки';

  @override
  String get filmCatalogShort => 'Каталог';

  @override
  String get filmTabStock => 'Склад';

  @override
  String get filmTabSales => 'Продажи';

  @override
  String get filmTabCustomers => 'Клиенты';

  @override
  String get filmCorrectTitle => 'Исправить';

  @override
  String get filmCorrectReason => 'Почему исправляете';

  @override
  String get filmCorrectHint =>
      'Старая запись останется зачёркнутой — видно, кто и почему исправил.';

  @override
  String get filmCorrectSave => 'Исправить';

  @override
  String get filmCorrectCancel => 'Отменить запись';

  @override
  String filmCorrected(String date, String who, String reason) {
    return 'исправлено $date · $who · «$reason»';
  }

  @override
  String get filmSaleAddPart => 'ещё способ';

  @override
  String get filmSalePaidFull => 'Оплачено полностью';

  @override
  String filmSaleOverpaid(String amount) {
    return 'Больше суммы на $amount — так нельзя';
  }

  @override
  String get filmThicknessUnknown => 'толщина не указана';

  @override
  String get filmThicknessHint => 'Не знаете — оставьте пустым, впишете позже';

  @override
  String filmNoThickness(String count) {
    return 'Без толщины · $count';
  }

  @override
  String get filmVariants => 'Толщины';

  @override
  String get filmVariantAdd => 'Толщина';

  @override
  String filmVariantDeleteAsk(String thickness) {
    return 'Убрать толщину $thickness мм?';
  }

  @override
  String filmReceiveSetPrice(String price) {
    return 'Записать закуп в карточку: $price ₸';
  }

  @override
  String filmReceiveUpdatePrice(String before, String after) {
    return 'Обновить закуп в карточке: $before → $after ₸';
  }

  @override
  String filmSaleRememberRetail(String price) {
    return 'Запомнить $price ₸ как розничную цену';
  }

  @override
  String filmSaleRememberWholesale(String price) {
    return 'Запомнить $price ₸ как оптовую цену';
  }

  @override
  String filmPriceSince(String date, String via) {
    return 'с $date · $via';
  }

  @override
  String get filmPriceByHand => 'вручную';

  @override
  String filmMargin(String amount, String percent) {
    return 'Наценка: +$amount ₸/м · $percent%';
  }

  @override
  String get filmSaveMore => 'Сохранить и ещё';

  @override
  String filmAddedOne(String name) {
    return 'Добавлена: $name';
  }

  @override
  String get filmArchive => 'В архив';

  @override
  String get filmRestore => 'Вернуть из архива';

  @override
  String filmArchiveChip(String name) {
    return 'Архив · $name';
  }

  @override
  String get filmDelete => 'Удалить';

  @override
  String filmDeleteAsk(String name) {
    return 'Удалить плёнку «$name»?';
  }

  @override
  String get filmDeleteHint =>
      'Удалить можно только плёнку, по которой ничего не было. Если по ней есть приходы, продажи или заказы — отправьте её в архив.';

  @override
  String get filmChanges => 'История изменений';

  @override
  String get filmChangesEmpty => 'Изменений пока нет.';

  @override
  String get filmCollection => 'Коллекция';

  @override
  String get filmCollections => 'Коллекции';

  @override
  String get filmAllCollections => 'Все коллекции';

  @override
  String get filmCollectionAdd => 'Новая коллекция';

  @override
  String get filmCollectionRename => 'Переименовать коллекцию';

  @override
  String get filmCollectionName => 'Название коллекции';

  @override
  String filmCollectionRemoveAsk(String name) {
    return 'Убрать коллекцию «$name»?';
  }

  @override
  String get filmCollectionRemoveHint =>
      'Её плёнки останутся в каталоге, без коллекции.';

  @override
  String filmCollectionsEmpty(String name) {
    return 'У $name пока нет коллекций. Нажмите +, чтобы добавить.';
  }

  @override
  String filmLooseDropAsk(String name) {
    return 'Убрать цвет «$name»?';
  }

  @override
  String get filmLooseDropHint =>
      'Заказы, где он указан, останутся как записаны.';

  @override
  String get filmTabSources => 'Поставщики';

  @override
  String get filmSourceAdd => 'Поставщик';

  @override
  String get filmSourcesEmpty =>
      'Поставщиков пока нет. Добавьте, где берёте плёнку: филиал производителя в городе или оптовика.';

  @override
  String get filmSourceName => 'Название (например, Adilet · Алматы)';

  @override
  String get filmSrcKind => 'Кто это (филиал, оптовик)';

  @override
  String get filmSrcCity => 'Город';

  @override
  String get filmSrcContact => 'Контактное лицо';

  @override
  String get filmSrcPhone => 'Телефон';

  @override
  String get filmSrcPhone2 => 'Второй телефон';

  @override
  String get filmSrcWhatsapp => 'WhatsApp';

  @override
  String get filmSrcAddress => 'Адрес склада';

  @override
  String get filmSrcLead => 'Срок доставки';

  @override
  String get filmSrcMinOrder => 'Минимальная партия';

  @override
  String get filmSrcNote => 'Заметка';

  @override
  String get filmSrcMakers => 'Чьи плёнки продаёт';

  @override
  String get filmSourceRemove => 'Убрать из списка';

  @override
  String filmSourceRemoveAsk(String name) {
    return 'Убрать поставщика «$name»?';
  }

  @override
  String get filmSourceRemoveHint => 'Приходы от него останутся в истории.';

  @override
  String get filmMakerCard => 'Карточка производителя';

  @override
  String get filmMakerSite => 'Сайт';

  @override
  String get filmMakerSources => 'Где берём эту плёнку';

  @override
  String get filmMakerNoSources =>
      'Пока не указано, где брать. Добавьте источник.';

  @override
  String get filmSourceNew => 'Добавить источник';

  @override
  String get filmReceiveFrom => 'Откуда пришла';

  @override
  String get filmSell => 'Продать';

  @override
  String get filmReceive => 'Приход';

  @override
  String get filmToShop => 'В цех';

  @override
  String get filmWriteOff => 'Списать';

  @override
  String get filmEditCard => 'Карточка';

  @override
  String get filmHistory => 'История';

  @override
  String get filmHistoryEmpty => 'Пока ничего не приходило и не уходило.';

  @override
  String get filmMetresLabel => 'Метров';

  @override
  String get filmNotEnough => 'столько нет на складе';

  @override
  String get filmReason => 'Причина';

  @override
  String get filmForOrder => 'Для заказа (необязательно)';

  @override
  String get filmReasonSample => 'Образец клиенту';

  @override
  String get filmReasonDamaged => 'Брак рулона';

  @override
  String get filmReasonTest => 'Тест на прессе';

  @override
  String get filmRetailM => 'Розница, ₸/м';

  @override
  String get filmWholesaleM => 'Опт, ₸/м';

  @override
  String get filmRetail => 'розница';

  @override
  String get filmWholesale => 'опт';

  @override
  String get filmDiscount => 'Скидка, %';

  @override
  String get filmSalePriceM => 'Цена, ₸/м';

  @override
  String get filmSaleAddLine => 'Ещё плёнка';

  @override
  String filmSaleTotal(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String get filmSalePaid => 'Оплачено сейчас, ₸';

  @override
  String filmSaleDebt(String amount) {
    return 'долг $amount';
  }

  @override
  String get filmSalesEmpty => 'Продаж пока нет.';

  @override
  String get filmCustomersEmpty =>
      'Клиентов плёнки пока нет — они появятся после первой продажи.';

  @override
  String get filmStockEmpty => 'Плёнок пока нет. Заведите их в каталоге.';

  @override
  String filmLow(String metres) {
    return '$metres м · мало';
  }

  @override
  String filmLowCount(int n) {
    return 'мало на складе · $n';
  }

  @override
  String filmAsleep(int days) {
    return 'уснул · $days дн.';
  }

  @override
  String filmMonthMetres(String metres) {
    return '$metres м за месяц';
  }

  @override
  String get filmMoveReceipt => 'приход';

  @override
  String get filmMoveSale => 'продажа';

  @override
  String get filmMoveShop => 'в цех';

  @override
  String get filmMoveWriteOff => 'списание';

  @override
  String get filmMoveOther => 'расход';

  @override
  String get filmDeptHint => 'Склад плёнки, продажа на метраж, клиенты';

  @override
  String get filmPayDebt => 'Доплатить, ₸';

  @override
  String get filmCancelMove => 'Отменить продажу';

  @override
  String get filmCancelReason => 'Почему отменяете';

  @override
  String get filmClose => 'Закрыть';

  @override
  String get filmDelivery => 'Доставка';

  @override
  String get filmTransport => 'Как привезли';

  @override
  String get filmCity => 'Откуда (город)';

  @override
  String get filmDeliveryCost => 'За доставку, ₸';

  @override
  String filmDeliveryPerM(String per) {
    return '≈ $per на метр';
  }

  @override
  String get filmReceivedBy => 'Кто принял';

  @override
  String get filmUrgent => 'Срочно';

  @override
  String get filmSeller => 'Продавец';

  @override
  String filmTakenBy(String name) {
    return 'принял $name';
  }

  @override
  String filmSoldBy(String name) {
    return 'продал $name';
  }

  @override
  String get filmTabTeam => 'Команда';

  @override
  String filmTeamTotals(
    String metres,
    String sales,
    String paid,
    String margin,
  ) {
    return '$metres м · продаж $sales · оплачено $paid · маржа $margin';
  }

  @override
  String filmTeamPlan(String done, String plan) {
    return 'План: $done% из $plan м';
  }

  @override
  String get filmTeamNoPlan => 'План на месяц не задан';

  @override
  String filmTeamPot(String pct, String pot) {
    return 'Котёл: $pct% маржи = $pot';
  }

  @override
  String filmTeamShare(String share, String bonus) {
    return 'доля $share% · бонус $bonus';
  }

  @override
  String get filmTeamEmpty => 'В этом месяце продаж нет';

  @override
  String get filmTeamHint =>
      'Бонус считается с маржи — только с оплаченных денег, в месяц оплаты.';

  @override
  String get filmTeamSettings => 'План и бонус';

  @override
  String get filmTeamPlanM => 'План на месяц, м';

  @override
  String get filmTeamPct => 'Котёл при выполнении плана, %';

  @override
  String get filmTeamPctBelow => 'Котёл, если план не выполнен, %';

  @override
  String get filmTeamSave => 'Сохранить';

  @override
  String get filmArrival => 'Когда прибудет';

  @override
  String get filmArrivalHere => 'Уже на складе';

  @override
  String get filmArrivalTomorrow => 'Завтра';

  @override
  String get filmArrivalTwo => 'Через 2 дня';

  @override
  String get filmArrivalThree => '3 дня';

  @override
  String get filmArrivalWeek => 'Неделя';

  @override
  String get filmArrivalPick => 'Дата…';

  @override
  String filmArrivesOn(String day) {
    return 'Прибудет: $day';
  }

  @override
  String get filmArrivalOrder => 'Оформить';

  @override
  String filmComing(String metres, String day) {
    return 'в пути $metres м · прибудет $day';
  }

  @override
  String filmComingLate(String metres, String days) {
    return 'в пути $metres м · опаздывает на $days дн.';
  }

  @override
  String get filmComingArrived => 'Пришла';

  @override
  String get filmComingMove => 'Другая дата';

  @override
  String get filmComingDrop => 'Не придёт';

  @override
  String get filmComingDropReason => 'Почему не придёт';

  @override
  String get filmComingMetres => 'Сколько пришло, м';

  @override
  String get filmOnShelf => 'На складе';

  @override
  String get filmOnWay => 'В пути';

  @override
  String filmOnlyHave(String metres) {
    return 'есть только $metres м';
  }

  @override
  String filmLeft(String metres) {
    return 'останется $metres м';
  }

  @override
  String filmLeftLow(String metres) {
    return 'останется $metres м — мало';
  }

  @override
  String filmTakeAll(String metres) {
    return 'Взять всё $metres м';
  }

  @override
  String filmMoreComing(String metres, String day) {
    return '+$metres м в пути, придёт $day';
  }

  @override
  String get filmDeliveryPayer => 'Кто заплатил';

  @override
  String get filmPayerCash => 'Касса плёнки';

  @override
  String get filmPayerEmployee => 'Сотрудник из своих';

  @override
  String get filmPayerUnpaid => 'Не оплачено';

  @override
  String get filmPaidBy => 'Кто заплатил из своих';

  @override
  String get filmPaidCash => 'из кассы';

  @override
  String filmPaidByBack(String who) {
    return 'заплатил $who, вернули';
  }

  @override
  String filmPaidByOwed(String who) {
    return 'заплатил $who — вернуть';
  }

  @override
  String get filmCarrierPaid => 'перевозчику оплачено';

  @override
  String get filmCarrierOwed => 'не оплачено перевозчику';

  @override
  String get filmPaidSupplier => 'за счёт поставщика';

  @override
  String get filmTabCash => 'Касса';

  @override
  String filmSettleBy(String how) {
    return 'Оплачено: $how';
  }

  @override
  String get filmGaveBack => 'Вернул';

  @override
  String get filmPaidCarrier => 'Оплатил';

  @override
  String get filmCashToday => 'Сегодня';

  @override
  String get filmCashMonth => 'Месяц';

  @override
  String get filmCashIn => 'Пришло';

  @override
  String get filmCashOut => 'Ушло';

  @override
  String get filmCashNothing => '—';

  @override
  String get filmCashTotal => 'Итого';

  @override
  String get filmCashBalance => 'Остаток';

  @override
  String filmCashLogistics(String sum) {
    return 'Логистика за период: $sum — в бонус не входит';
  }

  @override
  String filmCashLogisticsPerM(String sum, String per) {
    return 'Логистика за период: $sum (≈ $per на метр) — в бонус не входит';
  }

  @override
  String get filmOwedEmployees => 'Вернуть сотрудникам';

  @override
  String get filmOwedCarriers => 'Долг перевозчикам';

  @override
  String get filmOwedSuppliers => 'Долг поставщикам';

  @override
  String get filmPaidToSupplier => 'Оплатили';

  @override
  String get filmSupplierPay => 'Оплата поставщику';

  @override
  String get filmSupplierPaidNow => 'Оплачено';

  @override
  String get filmSupplierOnCredit => 'В долг';

  @override
  String get filmSupplierOwedNote => 'в долг поставщику';

  @override
  String filmCashChartA11y(String incoming, String outgoing) {
    return 'Пришло $incoming, ушло $outgoing';
  }

  @override
  String filmCashVersus(String arrow, String pct) {
    return '$arrow $pct% к прошлому периоду';
  }

  @override
  String filmPayFromCash(String how) {
    return 'Из кассы плёнки: $how';
  }

  @override
  String get filmPayElsewhere => 'Не из кассы плёнки';

  @override
  String get filmToday => 'Сегодня';

  @override
  String get filmYesterday => 'Вчера';

  @override
  String get filmHistoryAll => 'Все';

  @override
  String get filmHistoryReceipts => 'Приходы';

  @override
  String get filmHistorySales => 'Продажи';

  @override
  String get filmHistoryShop => 'В цех';

  @override
  String get filmHistoryWriteOffs => 'Списания';

  @override
  String filmAfter(String metres) {
    return 'стало $metres м';
  }

  @override
  String filmReorderBanner(int count) {
    return 'Пора заказать — мало плёнки: $count';
  }

  @override
  String get filmReorderOpen => 'Заказать';

  @override
  String get filmReorderTitle => 'Заказать плёнку';

  @override
  String filmReorderLeft(String metres) {
    return 'осталось $metres м';
  }

  @override
  String filmReorderTotal(String sum, String day) {
    return 'Итого $sum · придёт $day';
  }

  @override
  String filmReorderSave(int count) {
    return 'Оформить ($count)';
  }

  @override
  String filmDebtors(int count, String sum) {
    return 'Должники: $count · $sum';
  }

  @override
  String get filmRemind => 'Напомнить в WhatsApp';

  @override
  String filmRemindText(String name, String sum) {
    return 'Здравствуйте, $name! Напоминаем об оплате за плёнку: остаток $sum. Спасибо!';
  }

  @override
  String filmDebtDays(int days) {
    return 'долг $days дн.';
  }

  @override
  String get filmReportTop => 'Что продали за месяц';

  @override
  String filmReportTotals(String metres, String amount, String margin) {
    return '$metres м · выручка $amount · маржа $margin';
  }

  @override
  String filmReportMarginM(String sum) {
    return 'маржа $sum/м';
  }

  @override
  String filmReportIdle(int days) {
    return 'Лежит без движения больше $days дн.';
  }

  @override
  String filmReportIdleDays(int days) {
    return '$days дн. без движения';
  }

  @override
  String filmReportFrozen(String sum) {
    return 'заморожено $sum';
  }

  @override
  String get filmReceipt => 'Чек';

  @override
  String get filmReceiptDate => 'Дата';

  @override
  String get filmReceiptCustomer => 'Клиент';

  @override
  String get filmReceiptFilm => 'Плёнка';

  @override
  String get filmReceiptMetres => 'Метров';

  @override
  String get filmReceiptPrice => 'Цена за м';

  @override
  String get filmReceiptAmount => 'Сумма';

  @override
  String get filmReceiptTotal => 'Итого';

  @override
  String get filmReceiptPaid => 'Оплачено';

  @override
  String get filmReceiptDebt => 'Долг';

  @override
  String get filmHold => 'Отложить';

  @override
  String get filmHoldRelease => 'Снять';

  @override
  String get filmHoldUntil => 'До какого дня';

  @override
  String filmHeldFor(String metres, String customer, String day) {
    return 'отложено $metres м за $customer до $day';
  }

  @override
  String facadePricesUnsoldMillings(int count) {
    return 'Фрезеровки без цен: $count';
  }

  @override
  String facadePricesShowUnsold(int count) {
    return 'Не продаётся: $count — показать';
  }

  @override
  String get facadePricesHideUnsold => 'Скрыть непродаваемые';

  @override
  String get mdfGroupSales => 'Продажи';

  @override
  String get mdfGroupShop => 'Цех';

  @override
  String get mdfGroupStock => 'Склад и закупки';

  @override
  String get mdfGroupSettings => 'Справочники и цены';

  @override
  String get filmDriver => 'Водитель';

  @override
  String get filmDriverPhone => 'Телефон водителя';

  @override
  String get filmFree => 'Свободно';

  @override
  String get filmHeld => 'Отложено';

  @override
  String get filmReceiptPayment => 'Оплата';

  @override
  String filmReceiptServedBy(String name) {
    return 'Продавец (ответственный): $name';
  }

  @override
  String get filmReceiptThanks => 'Спасибо, что выбрали нас!';

  @override
  String get filmReceiptWish =>
      'Отличный выбор — пусть ваши фасады радуют вас долгие годы. Будем рады видеть вас снова!';

  @override
  String filmReceiptCode(String code) {
    return 'код $code';
  }

  @override
  String filmReceiptThickness(String mm) {
    return '$mm мм';
  }

  @override
  String filmReceiptPhone(String phone) {
    return 'Тел.: $phone';
  }

  @override
  String get filmReceiptSignSold => 'Продал';

  @override
  String get filmReceiptSignGot => 'Получил';

  @override
  String get facadePricesAddVariant => 'Вариант';

  @override
  String get facadePricesVariant => 'Вариант фрезеровки';

  @override
  String get facadePricesVariantHint =>
      'Цена — как у вида. В заказе появится как «вид вариант».';

  @override
  String get filmIssuedBy => 'Выдал со склада';

  @override
  String filmReceiptIssuedBy(String name) {
    return 'Выдал со склада: $name';
  }

  @override
  String get filmReceiptSignIssued => 'Выдал';

  @override
  String filmHeldShort(String metres) {
    return 'отложено $metres м';
  }

  @override
  String filmOnWayShort(String metres) {
    return 'в пути $metres м';
  }

  @override
  String get filmReceivePick => 'Приход — какая плёнка?';

  @override
  String searchSectionFilms(int count) {
    return 'Плёнка ($count)';
  }

  @override
  String searchSectionFilmCustomers(int count) {
    return 'Клиенты плёнки ($count)';
  }

  @override
  String filmDebtLine(String sum) {
    return 'долг $sum ₸';
  }

  @override
  String get filmTeamSold => 'Продано';

  @override
  String get filmTeamPaid => 'Оплачено';

  @override
  String get filmTeamMargin => 'Маржа';

  @override
  String get filmTeamPotLabel => 'Котёл';

  @override
  String filmTeamPotNote(String pct) {
    return '$pct% маржи';
  }

  @override
  String get filmTeamVsLastMonth => 'к прошлому месяцу';

  @override
  String filmTeamMarginShare(String pct) {
    return '$pct% от оплаченного';
  }

  @override
  String get filmTeamSellers => 'Продавцы';

  @override
  String filmTeamSellerLine(String name, String sales, String metres) {
    return '$name · продаж $sales · $metres м';
  }

  @override
  String filmTeamBonus(String sum) {
    return 'бонус $sum';
  }

  @override
  String filmTeamShareLine(String share, String margin, String paid) {
    return 'доля $share% · маржа $margin · оплачено $paid';
  }

  @override
  String get filmReportMarginLegend =>
      'Зелёный — маржа хорошая, жёлтый — меньше 300 ₸ на метр, красный — продали дешевле закупа.';

  @override
  String get filmCashWeek => 'Неделя';

  @override
  String filmCashSales(int count) {
    return 'продаж: $count';
  }

  @override
  String filmCashSpent(int count) {
    return 'расходов: $count';
  }

  @override
  String get filmCashWhere => 'Где деньги';

  @override
  String get filmCashMoves => 'Движения';

  @override
  String filmCustomersAll(int count) {
    return 'Все $count';
  }

  @override
  String filmCustomersRegular(int count) {
    return '⭐ Постоянные $count';
  }

  @override
  String filmCustomersAsleep(int count) {
    return '😴 Пропали $count';
  }

  @override
  String get filmCustomersByMonth => 'За месяц';

  @override
  String get filmCustomersByAll => 'За всё время';

  @override
  String get filmCustomersLegend =>
      'Сверху — кто больше покупает. Полоса: зелёная — всё оплачено, красная — есть долг, серая — давно не покупал.';

  @override
  String get filmRegularBadge => '⭐ постоянный';

  @override
  String get filmNoDebt => 'долгов нет';

  @override
  String get filmCall => 'Позвонить';

  @override
  String get filmWrite => 'Написать в WhatsApp';

  @override
  String filmCustomerLast(String day) {
    return 'последняя покупка $day';
  }

  @override
  String get filmCustomerBought => 'Всего купил';

  @override
  String get filmCustomerSum => 'На сумму';

  @override
  String get filmCustomerDebt => 'Долг';

  @override
  String get filmCustomerMonth => 'За месяц';

  @override
  String get filmCustomerFavourite => 'Чаще берёт';

  @override
  String get filmCustomerTerms => 'Условия: розница / опт, скидка';

  @override
  String get filmCustomerHistory => 'Покупки';

  @override
  String filmCashShould(String sum) {
    return 'Наличных в кассе должно быть: $sum';
  }

  @override
  String filmCashClosed(String sum, String who) {
    return 'День закрыт: насчитали $sum · $who';
  }

  @override
  String filmCashGap(String sum, String why) {
    return 'расхождение $sum: $why';
  }

  @override
  String get filmCashCloseDay => 'Закрыть день';

  @override
  String get filmCashRecount => 'Пересчитать';

  @override
  String get filmCashCounted => 'Сколько наличных насчитали';

  @override
  String filmCashShort(String sum) {
    return 'Не хватает $sum';
  }

  @override
  String filmCashOver(String sum) {
    return 'Лишние $sum';
  }

  @override
  String get filmCashMatches => 'Сходится';

  @override
  String get filmCashWhy => 'Почему не сходится';

  @override
  String get filmSupSoldMonth => 'Продано за месяц';

  @override
  String get filmSupSoldAll => 'Продано за всё время';

  @override
  String get filmSupOnHand => 'Лежит на складе';

  @override
  String get filmSupComing => 'В пути';

  @override
  String get filmSupReorder => 'Пора заказать';

  @override
  String filmSupM(String metres) {
    return '$metres м';
  }

  @override
  String filmSupComingRolls(int count) {
    return 'поставок: $count';
  }

  @override
  String filmSupReorderFilms(int count) {
    return 'плёнок: $count';
  }

  @override
  String filmSupShare(String share) {
    return '$share% продаж';
  }

  @override
  String filmSupRevenue(String sum) {
    return 'выручка $sum';
  }

  @override
  String filmSupShelf(String metres) {
    return 'на складе $metres м';
  }

  @override
  String filmSupLead(int days, int promised) {
    return 'везёт $days дн. (обещал $promised)';
  }

  @override
  String filmSupChipReorder(int count) {
    return 'Пора заказать: $count';
  }

  @override
  String filmSupChipComing(String metres, String day) {
    return 'В пути $metres м · $day';
  }

  @override
  String filmSupChipComingLate(String metres, int days) {
    return 'В пути $metres м · опаздывает на $days дн.';
  }

  @override
  String filmSupChipLate(int days) {
    return 'Опаздывает в среднем на $days дн.';
  }

  @override
  String filmSupChipIdle(int count, String metres) {
    return 'Лежит без движения: $count · $metres м';
  }

  @override
  String get filmSupChipOk => 'Всё в порядке';

  @override
  String get filmSupOrder => 'Заказать в WhatsApp';

  @override
  String filmSupOrderText(String list) {
    return 'Здравствуйте! Нужна плёнка:\n$list\nКогда сможете привезти?';
  }

  @override
  String filmSupOrderLine(String title, String metres) {
    return '— $title — $metres м';
  }

  @override
  String get filmSupLegend =>
      'Сверху — чья плёнка продаётся лучше. Плёнку от двух фирм делим по тому, сколько от кого пришло.';

  @override
  String get filmSrcOrderUntil => 'Принимает заказы до (например, 16:00)';

  @override
  String get filmReceiveAddFilm => 'Ещё плёнка';

  @override
  String filmReceiveAddLow(int count) {
    return 'Добавить всё, что пора заказать ($count)';
  }

  @override
  String get filmReceiveForWhom => 'Для кого';

  @override
  String get filmReceiveForShelf => 'На склад';

  @override
  String filmReceiveForCustomer(String name) {
    return 'Под заказ: $name';
  }

  @override
  String get filmReceiveRemove => 'Убрать';

  @override
  String filmReceiveSum(String sum) {
    return 'сумма $sum';
  }

  @override
  String filmReceiveSumWithDelivery(String sum, String perM) {
    return 'сумма $sum · метр с доставкой $perM';
  }

  @override
  String filmReceiveMany(int count) {
    return 'Приход · плёнок: $count';
  }

  @override
  String filmReceiveTotal(int count, String metres, String sum) {
    return 'Итого: плёнок $count · $metres м · $sum с доставкой';
  }

  @override
  String get filmPickSearch => 'Фирма, цвет или код';

  @override
  String get filmPickNone => 'Ничего не нашлось';

  @override
  String filmPickFree(String metres) {
    return '$metres м';
  }

  @override
  String get filmPickReorder => 'пора заказать';

  @override
  String get filmOrdersTitle => 'К заказу';

  @override
  String filmOrdersSendAll(int count) {
    return 'Отправить всем ($count)';
  }

  @override
  String filmOrdersSummary(int count, String metres, int suppliers) {
    return 'Плёнок: $count · $metres м · поставщиков: $suppliers';
  }

  @override
  String get filmOrdersAdd => 'Добавить плёнку';

  @override
  String get filmOrdersAddSave => 'В заказ';

  @override
  String get filmOrdersEmpty =>
      'Заказывать пока нечего. Добавьте плёнку, когда клиенту нужно больше, чем есть, — плёнки, которые кончаются, появятся здесь сами.';

  @override
  String get filmOrdersLegend =>
      'Красное — кончилась, синее — под клиента, серое — на склад. Нажмите, чтобы поменять метры; × — убрать.';

  @override
  String filmOrderLine(int n, String title, String metres) {
    return '$n. $title — $metres м';
  }

  @override
  String filmOrderText(String date, String lines, int count, String metres) {
    return 'Здравствуйте! Заказ на $date:\n$lines\nВсего: позиций $count, $metres м.\nПодтвердите, пожалуйста, наличие и когда привезёте.';
  }

  @override
  String filmOrderCopied(String name) {
    return 'Текст заказа для «$name» скопирован — вставьте его в сообщение.';
  }

  @override
  String get filmOrdersNoSupplier => 'Поставщик не указан';

  @override
  String filmOrdersGroupTotal(int count, String metres) {
    return 'плёнок $count · $metres м';
  }

  @override
  String filmOrdersUntil(String time) {
    return 'принимает заказы до $time';
  }

  @override
  String get filmOrdersSend => 'Отправить в WhatsApp';

  @override
  String get filmOrdersCopy => 'Скопировать заказ';

  @override
  String filmOrdersSentAt(String time) {
    return 'Отправлено в $time · ждём ответ';
  }

  @override
  String get filmOrdersConfirmed => 'Подтвердили — оформить приход';

  @override
  String filmOrdersForShelf(String metres) {
    return 'на склад $metres м';
  }

  @override
  String filmOrdersForCustomer(String name, String metres) {
    return '$name $metres м';
  }

  @override
  String filmOrdersRanOut(String metres) {
    return 'кончилась · $metres м';
  }

  @override
  String filmOrdersButton(int count) {
    return 'К заказу · $count';
  }

  @override
  String filmOrdersButtonWaiting(int count, int waiting) {
    return 'К заказу · $count · ждём ответ: $waiting';
  }

  @override
  String get mdfSumTitle => 'Итоги МДФ';

  @override
  String get mdfSumWeek => 'Неделя';

  @override
  String get mdfSumShare => 'Скопировать итоги';

  @override
  String get mdfSumCopied => 'Итоги скопированы — вставьте в WhatsApp.';

  @override
  String mdfSumUp(int percent) {
    return '▲ $percent% к прошлому';
  }

  @override
  String mdfSumDown(int percent) {
    return '▼ $percent% к прошлому';
  }

  @override
  String get mdfSumAvg => 'Средний чек';

  @override
  String mdfSumAvgNote(String area, String rate) {
    return '$area м² · $rate/м²';
  }

  @override
  String get mdfSumCustomers => 'Клиентов';

  @override
  String mdfSumNewCustomers(int count) {
    return 'новых: $count';
  }

  @override
  String get mdfSumPlan => 'План месяца и прогноз';

  @override
  String get mdfSumPlanDone => 'Сделано за месяц';

  @override
  String get mdfSumGoal => 'Цель';

  @override
  String mdfSumGoalOf(String goal, int percent) {
    return '$goal м² · $percent%';
  }

  @override
  String get mdfSumGoalNone =>
      'Цель месяца не задана — нажмите ✎, чтобы задать.';

  @override
  String get mdfSumGoalSet => 'Цель месяца';

  @override
  String get mdfSumGoalM2 => 'Сколько м² за месяц';

  @override
  String mdfSumForecast(int days) {
    return 'При таком темпе к концу месяца (осталось $days дн.)';
  }

  @override
  String get mdfSumShop => 'Загрузка цеха';

  @override
  String get mdfSumInWork => 'В работе';

  @override
  String mdfSumInWorkValue(String area, int count) {
    return '$area м² · заказов $count';
  }

  @override
  String get mdfSumPace => 'Цех делает в среднем';

  @override
  String mdfSumPaceValue(String area) {
    return '$area м² в день';
  }

  @override
  String get mdfSumPaceUnknown =>
      'Темп цеха пока не известен: нужно несколько готовых заказов.';

  @override
  String get mdfSumNewReady => 'Новый заказ реально выйдет';

  @override
  String mdfSumNewReadyValue(int days, String day) {
    return 'через $days дн. · $day';
  }

  @override
  String get mdfSumOverdueNow => 'Просрочено сейчас';

  @override
  String get mdfSumTop => 'Кто больше заказывает';

  @override
  String mdfSumTopValue(int count, String area) {
    return 'заказов $count · $area м²';
  }

  @override
  String get mdfSumMaker => 'мебельщик';

  @override
  String get mdfSumNew => 'новый';

  @override
  String get mdfSumNothing => 'За этот период пусто.';

  @override
  String get mdfSumAsleep => 'Уснули — пора напомнить о себе';

  @override
  String get mdfSumAsleepNone => 'Все клиенты заказывают в своём ритме.';

  @override
  String mdfSumAsleepRhythm(int rhythm, int days) {
    return 'обычно раз в $rhythm дн. · не было $days дн.';
  }

  @override
  String mdfSumAsleepOnce(int days) {
    return 'один заказ · не было $days дн.';
  }

  @override
  String get mdfSumGone => 'пропал';

  @override
  String get mdfSumDozing => 'засыпает';

  @override
  String mdfSumWakeText(String name) {
    return 'Здравствуйте, $name! Давно не виделись — как у вас дела с заказами? Можем принять фасады в работу, сроки сейчас хорошие.';
  }

  @override
  String mdfSumMore(int count) {
    return 'и ещё $count';
  }

  @override
  String get mdfSumFilms => 'Что заказывают · хватит ли плёнки';

  @override
  String mdfSumFilmShort(String metres) {
    return 'не хватает $metres м';
  }

  @override
  String get mdfSumFilmEnough => 'хватит';

  @override
  String get mdfSumToOrder => 'В «К заказу»';

  @override
  String mdfSumOrdered(String decor) {
    return '«$decor» добавлена в «К заказу».';
  }

  @override
  String get mdfSumDeadlines => 'Сроки и качество';

  @override
  String mdfSumOnTime(int count) {
    return 'Сдано вовремя (из $count)';
  }

  @override
  String get mdfSumNoHandedOver => 'За период ничего не выдано.';

  @override
  String get mdfSumLateAvg => 'Опоздание в среднем';

  @override
  String mdfSumDays(String days) {
    return '$days дн.';
  }

  @override
  String get mdfSumRework => 'Переделки и гарантия';

  @override
  String mdfSumReworkValue(int count, String area, int percent) {
    return '$count · $area м² · $percent%';
  }

  @override
  String mdfSumReasons(String list) {
    return 'Почему возвращали: $list';
  }

  @override
  String get mdfSumDebts => 'Долги по давности';

  @override
  String get mdfSumDebtWeek => 'до 7 дней';

  @override
  String get mdfSumDebtMonth => '8–30 дней';

  @override
  String get mdfSumDebtOlder => 'больше 30 дней';

  @override
  String mdfSumDebtor(String name, int days) {
    return '$name · $days дн.';
  }

  @override
  String get mdfSumManagers => 'Кто принимал заказы';

  @override
  String mdfSumAlertOverdue(int count) {
    return '$count просрочено';
  }

  @override
  String mdfSumAlertAtRisk(int count) {
    return '$count не успевают к сроку';
  }

  @override
  String mdfSumAlertDebt(String sum) {
    return 'Долг старше месяца: $sum';
  }

  @override
  String mdfSumAlertFilm(int count) {
    return 'Не хватает плёнки: $count';
  }

  @override
  String get mdfSumStages => 'Где сейчас заказы';

  @override
  String get mdfSumIntake => 'Принято по дням';

  @override
  String get mdfSumIntakeMonthly => 'Принято по месяцам';

  @override
  String get mdfSumIntakeHint =>
      'Нажмите на столбик — покажу заказы этого дня.';

  @override
  String mdfSumIntakeDay(String day, int count, String area, String sum) {
    return '$day: заказов $count · $area м² · $sum';
  }

  @override
  String mdfSumManagerValue(int count, String area, String sum) {
    return '$count · $area м² · $sum';
  }

  @override
  String mdfSumTextHead(String since, String until) {
    return 'Итоги МДФ $since — $until';
  }

  @override
  String mdfSumTextOrders(int count, String area, String sum) {
    return 'Заказов: $count · $area м² · $sum';
  }

  @override
  String mdfSumTextMoney(String paid, String debt) {
    return 'Получено: $paid · долг: $debt';
  }

  @override
  String mdfSumTextChange(String percent) {
    return 'Объём к прошлому периоду: $percent%';
  }

  @override
  String mdfSumTextForecast(String area) {
    return 'Прогноз месяца: $area м²';
  }

  @override
  String mdfSumTextAsleep(int count) {
    return 'Уснувших клиентов: $count';
  }

  @override
  String get mdfOrdersSummary => 'Итоги';

  @override
  String get mdfPressOpen => 'Раскладка на прессе';

  @override
  String mdfPressFilm(String metres, int loads) {
    return 'Плёнка $metres м · загрузок $loads';
  }

  @override
  String get mdfPressCorrected => 'поправлено вручную';

  @override
  String mdfPressSaved(String metres) {
    return 'умная раскладка −$metres м';
  }

  @override
  String mdfPressTooBig(int count) {
    return 'не влезает на пресс: $count';
  }

  @override
  String pressSmartSaved(String plain, String saved) {
    return 'Умная раскладка: обычная заняла бы $plain м — экономия $saved м.';
  }

  @override
  String get pressEdit => 'Изменить раскладку';

  @override
  String get pressEditReset => 'Разложить заново';

  @override
  String get pressEditSave => 'Сохранить мою раскладку';

  @override
  String pressEditTotal(String metres, String auto) {
    return 'Итого $metres м · система раскладывала на $auto м';
  }

  @override
  String get pressEditClash =>
      'Красные детали лежат слишком близко друг к другу или за краем стола — подвиньте их.';

  @override
  String get pressEditHint =>
      'Нажмите на деталь и тащите её. Отпустите — она сама встанет ровно.';

  @override
  String pressEditPart(int pos, String size) {
    return 'Позиция $pos · $size';
  }

  @override
  String get pressEditRotate => 'Повернуть';

  @override
  String pressEditMoveTo(int count) {
    return 'В загрузку $count';
  }

  @override
  String get pressEditMoveNew => 'В новую загрузку';

  @override
  String get pressEditSectionAuto => 'Секция: сама';

  @override
  String pressEditSection(String metres) {
    return 'Секция $metres м';
  }

  @override
  String get pressManual => 'Своя раскладка — детали разложены вручную.';

  @override
  String get pressApprove => 'Раскрой проверен — запустить';

  @override
  String pressApproved(String by, String at) {
    return 'Раскрой проверен: $by, $at';
  }

  @override
  String get pressUnapprove => 'Снять отметку';

  @override
  String pressShortAdded(String films) {
    return 'Не хватает плёнки, добавлено в «К заказу»: $films м';
  }

  @override
  String pressPrintApproved(String by, String at) {
    return 'Раскладка утверждена: $by, $at';
  }

  @override
  String get pressPrintSigns => 'Оператор ____________   Мастер ____________';

  @override
  String get mdfPressManual => 'своя раскладка';

  @override
  String get mdfPressApproved => 'раскрой проверен';

  @override
  String filmFilterAll(int n) {
    return 'Все · $n';
  }

  @override
  String filmFilterHave(int n) {
    return 'Есть · $n';
  }

  @override
  String filmFilterOnWay(int n) {
    return 'В пути · $n';
  }

  @override
  String filmFilterNone(int n) {
    return 'Нет на складе · $n';
  }

  @override
  String get filmStockSearch => 'Найти плёнку';

  @override
  String filmComingRolls(int count, String metres, String day) {
    return 'в пути $count рул. · $metres м · прибудет $day';
  }

  @override
  String filmDaysLeft(int days) {
    return 'хватит ≈ на $days дн.';
  }

  @override
  String get filmWantShort => 'Заказать';

  @override
  String get filmM => 'м';

  @override
  String get filmReceiveLineSum => 'Сумма';

  @override
  String filmReceivePerMWithDelivery(String perM) {
    return 'метр с доставкой $perM';
  }

  @override
  String filmPriceUp(String old, String since, String change) {
    return 'Дороже прошлого: было $old/м$since · $change';
  }

  @override
  String filmPriceDown(String old, String since, String change) {
    return 'Дешевле прошлого: было $old/м$since · $change';
  }

  @override
  String get filmReceiveWhere => 'Куда уходит';

  @override
  String filmReceiveIntoProduction(String order, String name, String due) {
    return 'В производство · №$order · $name $due';
  }

  @override
  String filmReceiveToCustomer(String name) {
    return 'Продажа · $name';
  }

  @override
  String get filmReceiveToShelf => 'На склад · свободно для продажи';

  @override
  String filmReceiveShort(String metres) {
    return 'Недовезли $metres м — останутся в «Ждём».';
  }

  @override
  String get filmReceiveShortToList => 'В «К заказу»';

  @override
  String get filmReceiveShortListed => 'добавлено в «К заказу»';

  @override
  String get filmReceiveToProduction => 'В производство';

  @override
  String get filmReceiveToSale => 'Продажа клиенту';

  @override
  String get filmReceiveNoOrders =>
      'Сейчас нет заказов на фасады, которым не хватает этой плёнки.';

  @override
  String filmReceiveOrderLine(
    String order,
    String name,
    String metres,
    String due,
  ) {
    return '№$order · $name · нужно $metres м · сдать $due';
  }

  @override
  String filmReceiveOrdersWait(int count) {
    return 'ждут заказы на фасады: $count';
  }

  @override
  String filmReceiveFilmTotal(int count, String metres) {
    return 'Плёнка · $count рул. · $metres м';
  }

  @override
  String get filmReceiveGrand => 'Итого закуп';

  @override
  String filmReceivePerM(String films) {
    return 'Метр с доставкой: $films';
  }

  @override
  String filmReceiveSumProduction(String metres) {
    return 'в производство $metres м';
  }

  @override
  String filmReceiveSumSale(String metres) {
    return 'продажа $metres м';
  }

  @override
  String filmReceiveSumShelf(String metres) {
    return 'склад $metres м';
  }

  @override
  String pressFill(int percent, String waste) {
    return 'заполнено $percent% · отход $waste м²';
  }

  @override
  String get pressPositionsHint =>
      'Наведите на деталь или нажмите на позицию — она подсветится на всех загрузках.';

  @override
  String pressPositionInfo(int pos, String size, int count, String loads) {
    return 'Позиция $pos · $size · всего $count шт · на загрузках $loads';
  }

  @override
  String pressPositionCount(int count) {
    return '$count шт';
  }

  @override
  String mdfPressCheckedBy(String by) {
    return '✓ раскрой проверил $by';
  }

  @override
  String get mdfPressNotChecked => 'раскрой не проверен';

  @override
  String get pressPanelTitle => 'Пресс';

  @override
  String get pressSectionRemove => 'Убрать секцию';

  @override
  String get pressLevel => 'Уровень расчёта';

  @override
  String get pressLevelFast => 'Быстрый';

  @override
  String get pressLevelSmart => 'Умный';

  @override
  String get pressLevelMax => 'Максимум';

  @override
  String get pressDirection => 'Укладка';

  @override
  String get pressDirectionAny => 'Как выгоднее';

  @override
  String get pressDirectionAlong => 'Вдоль';

  @override
  String get pressDirectionAcross => 'Поперёк';

  @override
  String get pressRotate => 'Вращать детали';

  @override
  String get pressRotateYes => 'Можно';

  @override
  String get pressRotateNo => 'Нельзя';

  @override
  String get pressRotateTextured => 'Текстурная плёнка — всегда «нельзя».';

  @override
  String get pressKeepForOrder => 'Только для этого заказа';

  @override
  String get pressKeepForPress => 'Сохранить для пресса';

  @override
  String get pressKeepForPressHint =>
      '«Для пресса» меняет все новые раскладки.';

  @override
  String get pressTuneReset => 'Вернуть как у пресса';

  @override
  String get pressTuneKept => 'Раскладка сохранена для этого заказа';

  @override
  String get pressTuneSaved => 'Настройки пресса сохранены';

  @override
  String pressWas(String metres) {
    return 'Было $metres м';
  }

  @override
  String pressWillBe(String metres) {
    return 'Станет $metres м';
  }

  @override
  String pressSaves(String metres) {
    return 'экономия $metres м';
  }

  @override
  String pressCostsMore(String metres) {
    return 'больше на $metres м';
  }

  @override
  String get pressSame => 'столько же';

  @override
  String get pressUnitM => 'м';

  @override
  String get pressUnitMm => 'мм';

  @override
  String pressMm(int value) {
    return '$value мм';
  }

  @override
  String get filmSalesToday => 'Сегодня';

  @override
  String get filmSalesWeek => 'Неделя';

  @override
  String get filmSalesMonth => 'Месяц';

  @override
  String get filmSalesPeriod => 'Период';

  @override
  String filmSalesAll(int count) {
    return 'Все · $count';
  }

  @override
  String filmSalesPaid(int count) {
    return 'Оплачено · $count';
  }

  @override
  String filmSalesDebt(int count) {
    return 'Долг · $count';
  }

  @override
  String filmSalesWholesale(int count) {
    return 'Опт · $count';
  }

  @override
  String get filmSalesSearch => 'клиент, плёнка';

  @override
  String get filmSalesSold => 'Продано';

  @override
  String filmSalesCount(int count) {
    return '$count прод.';
  }

  @override
  String get filmSalesMetres => 'Метров';

  @override
  String get filmSalesAmount => 'Выручка';

  @override
  String filmSalesChange(String change) {
    return '$change% к прошлому';
  }

  @override
  String get filmSalesProfit => 'Прибыль';

  @override
  String get filmSalesUnpaid => 'Не оплачено';

  @override
  String filmSalesDebtors(int count) {
    return 'клиентов: $count';
  }

  @override
  String filmSalesTodayOn(String day) {
    return 'Сегодня, $day';
  }

  @override
  String filmSalesYesterdayOn(String day) {
    return 'Вчера, $day';
  }

  @override
  String get filmSalesWholesaleMark => 'опт';

  @override
  String get filmSalesPaidMark => '✓ оплачено';

  @override
  String filmSalesPartly(String sum) {
    return 'частично · долг $sum';
  }

  @override
  String filmSalesPerM(String price) {
    return '$price/м';
  }

  @override
  String filmDebtorsTitle(String sum) {
    return 'Должники · $sum';
  }

  @override
  String get filmDebtorsShowSales => 'Показать их продажи';

  @override
  String filmDebtorLine(String sum, int days) {
    return '$sum · $days дн.';
  }

  @override
  String get filmSaleRepeat => 'Повторить';

  @override
  String filmSaleBelow(String cost, String loss) {
    return 'Ниже закупа: закуп $cost/м — убыток ≈ $loss';
  }

  @override
  String get filmSaleBelowWhy => 'Почему ниже закупа?';

  @override
  String get filmSaleBelowRest => 'остаток рулона';

  @override
  String get filmSaleBelowDefect => 'брак';

  @override
  String get filmSaleBelowAgreed => 'договорились';

  @override
  String get filmSaleToOrders => 'В «К заказу»';

  @override
  String filmSaleUsually(String film) {
    return 'обычно берёт $film';
  }

  @override
  String filmSaleEvery(int days) {
    return 'раз в $days дн.';
  }

  @override
  String get filmSaleNoDebt => 'долга нет';

  @override
  String filmSaleLikeLast(String films) {
    return 'Как в прошлый раз: $films';
  }

  @override
  String get filmDebtLimit => 'Лимит долга, ₸';

  @override
  String get filmDebtLimitDays => 'Долг не дольше, дн.';

  @override
  String filmLimitDays(int days) {
    return 'до $days дн.';
  }

  @override
  String filmSaleOverLimit(String sum, String limit) {
    return 'Долг станет $sum — больше лимита $limit';
  }

  @override
  String filmSaleOverDays(int days, int limit) {
    return 'должен уже $days дн. — дольше $limit дн.';
  }

  @override
  String filmCallTitle(int count) {
    return 'Пора позвонить · $count';
  }

  @override
  String filmCallDebt(String name, String sum, int days) {
    return '$name — долг $sum, $days дн.';
  }

  @override
  String filmCallRhythm(String name, int every, int idle) {
    return '$name — берёт раз в $every дн., не было $idle дн.';
  }

  @override
  String get filmCustomerAverage => 'Средний чек';

  @override
  String get filmCustomerRhythm => 'Покупает';

  @override
  String get filmCustomerLimit => 'Лимит долга';

  @override
  String get filmStatement => 'Акт сверки';

  @override
  String filmStatementCustomer(String name) {
    return 'Клиент: $name';
  }

  @override
  String filmStatementOn(String day) {
    return 'на $day';
  }

  @override
  String get filmStatementDate => 'Дата';

  @override
  String get filmStatementWhat => 'Операция';

  @override
  String get filmStatementSold => 'Отгружено';

  @override
  String get filmStatementPaid => 'Оплачено';

  @override
  String get filmStatementBalance => 'Долг';

  @override
  String filmStatementSale(String films) {
    return 'Плёнка: $films';
  }

  @override
  String get filmStatementPayment => 'Оплата';

  @override
  String filmStatementOwes(String sum) {
    return 'Долг клиента: $sum';
  }

  @override
  String get filmStatementSettled => 'Расчёты закрыты, долга нет.';

  @override
  String get filmStatementSigns =>
      'Продавец ____________     Клиент ____________';

  @override
  String get mdfMarginTitle => 'Маржа';

  @override
  String get mdfMarginRevenue => 'Сумма заказа';

  @override
  String get mdfMarginMaterial => 'Материал';

  @override
  String get mdfMarginWork => 'Работа';

  @override
  String get mdfMarginEstimate =>
      'Оценка по сегодняшним ценам: материал ещё не списан';

  @override
  String mdfMarginMissing(String names) {
    return 'Без цены: $names';
  }

  @override
  String get mdfMarginNotCounted => 'Не учтены: электричество, доставка';

  @override
  String get mdfSumMargin => 'Маржа выданных заказов';

  @override
  String mdfSumMarginOrders(String count) {
    return 'Выдано заказов: $count';
  }

  @override
  String mdfSumMarginEstimated(String count) {
    return 'По оценке, без списания: $count';
  }

  @override
  String get mdfSumMarginLowest => 'Меньше всего заработали';

  @override
  String get mdfPaintTitle => 'Отдел краски';

  @override
  String get mdfPaintHint => 'Что красить по цветам, что сохнет';

  @override
  String get mdfPaintDryHours => 'Сушка, часов';

  @override
  String get mdfPaintEmpty => 'Красить нечего';

  @override
  String mdfPaintSummary(String waiting, String drying, String coming) {
    return 'Красить $waiting · сохнет $drying · едет $coming';
  }

  @override
  String mdfPaintDrying(int hours) {
    return 'Сохнет ($hours ч)';
  }

  @override
  String get mdfPaintDry => 'Высохло';

  @override
  String mdfPaintLeft(String hours, String minutes, String day, String time) {
    return 'Ещё $hours ч $minutes мин · высохнет $day в $time';
  }

  @override
  String get mdfPaintMarkPainted => 'Отметить «краска»';

  @override
  String get mdfPaintUndo => 'Отменить';

  @override
  String get mdfPaintByColour => 'Красить — по цветам';

  @override
  String get mdfPaintByColourHint =>
      'Сначала самый большой цвет: замес один, пистолет моется один раз.';

  @override
  String mdfPaintColourNote(String area, String orders) {
    return '$area · заказов: $orders';
  }

  @override
  String get mdfPaintStartDrying => 'Покрасил — сушить';

  @override
  String get mdfPaintPopular => 'Популярные цвета за 90 дней';

  @override
  String get mdfPaintSave => 'Сохранить';

  @override
  String get mdfTagClientPaint => 'Краска клиента';

  @override
  String get mdfTagClientParts => 'ЛМДФ клиента';

  @override
  String get mdfClientPaintBrought => 'Краска принесена';

  @override
  String get mdfClientPaintWhat => 'Что принёс (например, 2 банки × 3 л)';

  @override
  String get mdfClientPaintHere => 'принесена';

  @override
  String get mdfClientPaintWaiting => 'Ждём краску';

  @override
  String get mdfPaintSettings => 'Настройки покраски';

  @override
  String get mdfPaintDiscount => 'Скидка за свою краску, ₸/м²';

  @override
  String get mdfPaintDiscountHint =>
      'Вычитается из цены м² при «Краска клиента»';

  @override
  String get mdfPaintComing => 'Скоро к вам';

  @override
  String mdfPaintNowAt(String stage) {
    return 'сейчас: $stage';
  }

  @override
  String get mdfPaintTwoSided => '2 стороны';

  @override
  String get mdfTagClientFilm => 'Плёнка клиента';

  @override
  String get mdfClientShort => 'клиента';

  @override
  String get mdfKpiOverdue => 'Просрочено';

  @override
  String get mdfKpiDueSoon => 'Сдать сегодня-завтра';

  @override
  String get mdfKpiReady => 'Готовы к выдаче';

  @override
  String get mdfKpiDebt => 'Долг клиентов';

  @override
  String mdfKpiDebtors(String count) {
    return 'клиентов: $count';
  }

  @override
  String get mdfSectionOverdue => 'Просрочено';

  @override
  String get mdfSectionSoon => 'Сдать скоро';

  @override
  String get mdfSectionShop => 'В цеху';

  @override
  String get mdfSectionReady => 'Готовы — ждут клиента';

  @override
  String get mdfSectionDraft => 'Черновики';

  @override
  String get mdfSectionClosed => 'Выданы';

  @override
  String mdfRowNowAt(String stage) {
    return 'сейчас: $stage';
  }

  @override
  String mdfRowLate(String days) {
    return 'просрочен $days дн.';
  }

  @override
  String mdfRowDaysLeft(String days) {
    return 'через $days дн.';
  }

  @override
  String get mdfRowToday => 'сдать сегодня';

  @override
  String mdfRowReadyFor(String days) {
    return 'готов $days дн.';
  }

  @override
  String get mdfRowPaid => 'оплачен';

  @override
  String get mdfFilterDueSoon => 'Сдать скоро';

  @override
  String get filmCashOpening => 'Наличных на начало';

  @override
  String filmCashOpeningNote(String day) {
    return 'пересчитано $day';
  }

  @override
  String get filmCashQuiet => 'За этот период движений нет.';

  @override
  String get filmFigOnHand => 'На складе';

  @override
  String get filmFigOnWay => 'В пути';

  @override
  String filmFigRolls(int count) {
    return 'поставок: $count';
  }

  @override
  String get filmFigRunsOut => 'Кончается';

  @override
  String filmFigRunsOutNote(int days) {
    return 'хватит меньше $days дн.';
  }

  @override
  String get filmFigToOrder => 'Пора заказать';

  @override
  String filmFigToOrderNote(String metres) {
    return '≈ $metres м';
  }

  @override
  String filmStockBought(String price) {
    return 'закуп $price/м';
  }

  @override
  String filmStockOrder(String metres) {
    return 'заказать $metres м';
  }

  @override
  String get filmSalesAverage => 'Средний чек';

  @override
  String get filmSalesQuietToday => 'Сегодня продаж ещё нет';

  @override
  String filmSalesYesterdayWas(String count, String metres) {
    return 'вчера: $count, $metres м';
  }

  @override
  String get filmSalesByDay => 'Продано по дням, м';

  @override
  String filmSalesChartA11y(String metres) {
    return 'Метры по дням; всего $metres м';
  }

  @override
  String get filmSalesTopFilms => 'Топ плёнок';

  @override
  String get filmSalesTopCustomers => 'Топ клиентов';

  @override
  String get filmSupOwed => 'Мы должны';

  @override
  String filmSupOwedTo(int count) {
    return 'поставщикам: $count';
  }

  @override
  String filmSupChipOwed(String amount) {
    return 'должны $amount';
  }

  @override
  String filmSupChipOnTime(int onTime, int rolls) {
    return 'вовремя $onTime из $rolls';
  }

  @override
  String filmSupChipPrice(String change) {
    return 'цена $change%';
  }

  @override
  String filmTeamPlanNeed(int days, String metres) {
    return 'осталось $days дн. — нужно $metres м в день';
  }

  @override
  String get filmTeamNoPlanHint =>
      'Задайте план месяца: от него зависит доля бонуса.';

  @override
  String get filmTeamSetPlan => 'Задать план';

  @override
  String filmTeamMarginM(String margin) {
    return '$margin/м';
  }

  @override
  String filmTeamOwed(String amount) {
    return 'долги его клиентов $amount';
  }

  @override
  String filmSaleMargin(
    String cost,
    String price,
    String perM,
    String total,
    String pct,
  ) {
    return 'закуп $cost → продажа $price: +$perM/м · $total ($pct%)';
  }

  @override
  String get filmSaleLikeLastShort => 'Как в прошлый раз';

  @override
  String get mdfDictAddGroup => 'Добавить группу';

  @override
  String mdfDictAddVariant(String group) {
    return 'Вариант для «$group»';
  }

  @override
  String get filmSupplierByInvoice => 'По счёту';

  @override
  String get filmInvoiceNo => '№ счёта';

  @override
  String filmInvoiceOn(String day) {
    return 'от $day';
  }

  @override
  String filmInvoiceDue(String day) {
    return 'оплатить до $day';
  }

  @override
  String get filmInvoiceNoDue => 'Без срока';

  @override
  String get filmInvoiceHint =>
      'Висит долгом до «Оплатили»; после срока — просрочен.';

  @override
  String filmByInvoiceNo(String no) {
    return 'по счёту № $no';
  }

  @override
  String get filmFromDeptCash => 'из кассы';

  @override
  String get filmSupplierFromDept => 'Из кассы отдела плёнки';

  @override
  String get filmInvoice => 'Счёт на оплату';

  @override
  String filmInvoiceTitle(String no, String day) {
    return 'Счёт на оплату № $no от $day';
  }

  @override
  String get filmInvoiceBeneficiary => 'Бенефициар';

  @override
  String get filmInvoiceSupplier => 'Поставщик:';

  @override
  String get filmInvoiceBuyer => 'Покупатель:';

  @override
  String get filmInvoiceNumber => '№';

  @override
  String get filmInvoiceItem => 'Наименование';

  @override
  String get filmInvoiceQty => 'Кол-во';

  @override
  String get filmInvoiceUnit => 'Ед.';

  @override
  String get filmInvoiceMetre => 'м';

  @override
  String filmInvoiceSummary(int count, String sum) {
    return 'Всего наименований $count, на сумму $sum';
  }

  @override
  String filmInvoicePayBy(String day) {
    return 'Оплатить до $day';
  }

  @override
  String get filmInvoiceDueHelp => 'Оплатить до';

  @override
  String get filmInvoiceSigned => 'Исполнитель';

  @override
  String get filmInvoiceMake => 'Счёт PDF';

  @override
  String get filmInvoiceNoRequisites =>
      'Для счёта нужны реквизиты вашей компании — заполните их один раз, дальше они будут в каждом счёте.';

  @override
  String get filmReqTitle => 'Реквизиты компании';

  @override
  String get filmReqFill => 'Заполнить реквизиты';

  @override
  String get filmReqEdit => 'Изменить реквизиты';

  @override
  String get filmReqSave => 'Сохранить';

  @override
  String get filmReqName => 'Название (как в документах)';

  @override
  String get filmReqBin => 'БИН/ИИН';

  @override
  String get filmReqAddress => 'Адрес';

  @override
  String get filmReqPhone => 'Телефон';

  @override
  String get filmReqBank => 'Банк';

  @override
  String get filmReqIik => 'ИИК (счёт)';

  @override
  String get filmReqBik => 'БИК';

  @override
  String get filmReqKbe => 'Кбе';

  @override
  String get filmReqDirector => 'Подписывает (директор)';

  @override
  String get mdfPaintSystem => 'Система цвета';

  @override
  String get mdfPaintAddSystem => 'Добавить систему цвета';

  @override
  String mdfPaintAddColour(String group) {
    return 'Добавить цвет в $group';
  }

  @override
  String get mdfPaintNoSystem => 'Без системы';

  @override
  String get mdfPaintSearch => 'Найти цвет: 9016, белый…';

  @override
  String get paintStock => 'Склад краски';

  @override
  String get paintReceive => 'Приход краски';

  @override
  String get paintReceiveSave => 'Оприходовать';

  @override
  String get paintReceiveShort => 'Докупить';

  @override
  String get paintColour => 'Цвет';

  @override
  String get paintBase => 'Что это (эмаль, грунт, лак…)';

  @override
  String get paintBaseEnamelMatt => 'Эмаль ПУ матовая';

  @override
  String get paintBaseEnamelGloss => 'Эмаль ПУ глянцевая';

  @override
  String get paintBasePrimer => 'Грунт';

  @override
  String get paintBaseLacquer => 'Лак';

  @override
  String get paintKg => 'Кг';

  @override
  String paintKgShort(String kg) {
    return '$kg кг';
  }

  @override
  String get paintCans => 'Банками';

  @override
  String get paintCanCount => 'Банок';

  @override
  String get paintCanKg => 'Кг в банке';

  @override
  String get paintPriceKg => 'Цена за кг';

  @override
  String paintPerKg(String price) {
    return '$price/кг';
  }

  @override
  String paintPriceUp(String pct, String was, String who) {
    return 'Дороже прошлого на $pct % (было $was у $who)';
  }

  @override
  String paintPriceDown(String pct, String was, String who) {
    return 'Дешевле прошлого на $pct % (было $was у $who)';
  }

  @override
  String paintPriceSame(String was, String who) {
    return 'Как в прошлый раз: $was у $who';
  }

  @override
  String get paintSupplier => 'Поставщик';

  @override
  String get paintNewSupplier => 'Новый поставщик';

  @override
  String paintToSupplier(String kg) {
    return 'Краска $kg кг';
  }

  @override
  String paintLanded(String price) {
    return 'Кг с доставкой: $price';
  }

  @override
  String paintDeliveryPerKg(String price) {
    return '+$price на кг';
  }

  @override
  String paintKgPerM2(String kg) {
    return 'Расход: $kg кг/м²';
  }

  @override
  String get paintKgPerM2Title => 'Расход краски, кг на м²';

  @override
  String get paintKgPerM2Hint =>
      'Грунт и все слои вместе. По нему считается, хватит ли краски на очередь.';

  @override
  String paintNeed(String m2, String need, String have) {
    return 'очередь $m2 м² · нужно $need кг · есть $have кг';
  }

  @override
  String paintShort(String kg) {
    return 'не хватит $kg кг';
  }

  @override
  String get paintEnough => 'хватает';

  @override
  String paintOnHand(String kg) {
    return '$kg кг';
  }

  @override
  String get paintNone =>
      'Краски на складе пока нет — нажмите «Приход краски».';

  @override
  String get paintOwed => 'Должны за краску';

  @override
  String get paintPaid => 'Оплатили';

  @override
  String paintHistory(String title) {
    return 'Приходы: $title';
  }

  @override
  String paintTakenBy(String who) {
    return 'принял $who';
  }

  @override
  String paintUsage(String days, String m2, String kg) {
    return 'За $days дн.: покрашено $m2 м², ушло $kg кг';
  }

  @override
  String paintUsageFact(String fact, String norm) {
    return 'по факту $fact кг/м² (норма $norm)';
  }

  @override
  String paintRecipe(String kg) {
    return 'Рецепт: $kg кг/м²';
  }

  @override
  String get paintRecipeTitle => 'Рецепт покраски';

  @override
  String get paintRecipeHint =>
      'Каждый слой: граммы на м² за один слой и сколько слоёв (0 — не красим); что добавляется на каждый килограмм. Эмаль — цвета заказа. Цена здесь — только пока материал ещё не покупали.';

  @override
  String get paintLayerName => 'Слой';

  @override
  String get paintLayerColour => 'Цвет заказа';

  @override
  String get paintLayerGM2 => 'г/м² за слой';

  @override
  String get paintLayerCoats => 'Слоёв';

  @override
  String paintLayerKg(String kg) {
    return '$kg кг/м² вместе с добавками';
  }

  @override
  String get paintPartName => 'Добавка';

  @override
  String get paintPartPerKg => 'кг на 1 кг';

  @override
  String get paintPartAdd => 'Отвердитель, разбавитель…';

  @override
  String get paintLayerAdd => 'Добавить слой';

  @override
  String get paintRemove => 'Убрать';

  @override
  String get paintCalc => 'Сколько краски';

  @override
  String get paintCalcM2 => 'м²';

  @override
  String get paintCalcNoColour => 'Любой цвет';

  @override
  String paintCalcTotal(String kg, String cost) {
    return 'Всего $kg кг · $cost';
  }

  @override
  String paintCalcPerM2(String cost) {
    return 'краска на 1 м² — $cost';
  }

  @override
  String get paintCalcUnpriced =>
      'Не у всех материалов есть цена — себестоимость неполная. Впишите цену в рецепт.';

  @override
  String get paintSendWhatsApp => 'Отправить в WhatsApp';

  @override
  String get paintCopy => 'Копировать';

  @override
  String get paintCopied => 'Скопировано';

  @override
  String get paintForQueue => 'На всю очередь';

  @override
  String paintMaterialNeed(String need, String have) {
    return 'нужно $need кг · есть $have кг';
  }

  @override
  String mdfPaintPlan(String colour, String kg) {
    return 'Краска $colour: $kg кг';
  }

  @override
  String get mdfPaintAskSupplier => 'Заявка поставщику';

  @override
  String get mdfPaintAskClient => 'Клиенту: сколько принести';

  @override
  String get paintSupplierCard => 'Поставщик краски';

  @override
  String get paintSupplierEdit => 'Карточка поставщика';

  @override
  String get paintSupplierName => 'Компания или человек';

  @override
  String get paintSupplierCity => 'Город';

  @override
  String get paintSupplierContact => 'Контактное лицо';

  @override
  String get paintSupplierPhone => 'Телефон';

  @override
  String get paintSupplierWhatsApp => 'WhatsApp';

  @override
  String get paintSupplierMinOrder => 'Минимальная партия';

  @override
  String get paintSupplierMinHint => 'например, 3 кг';

  @override
  String get paintSupplierNote => 'Заметка';

  @override
  String paintSupplierMin(String min) {
    return 'минималка $min';
  }

  @override
  String paintBatchLeft(String need, String left) {
    return 'На очередь нужно $need кг — остаток $left кг уйдёт на склад';
  }

  @override
  String get paintPriceM2 => 'Ваша цена за м²';

  @override
  String get paintMarkup => 'Наценка, %';

  @override
  String paintLeftM2(String left) {
    return 'остаётся с 1 м²: $left';
  }

  @override
  String paintLeftOrder(String left, String m2) {
    return 'остаётся с $m2 м²: $left';
  }

  @override
  String paintByMarkup(String price, String total) {
    return 'по наценке: $price за м², всего $total';
  }

  @override
  String get paintRemember => 'Запомнить цену и наценку';

  @override
  String get paintRecipeEdit => 'Рецепт и цены';

  @override
  String get paintSendTo => 'Кому';

  @override
  String get paintSendToAnyone => 'Выбрать в WhatsApp';

  @override
  String get paintPartPct => '% к весу';

  @override
  String mdfPaintNorm(String list) {
    return 'По норме использовать: $list';
  }

  @override
  String mdfPaintBatch(String have, String batch, String use, String left) {
    return 'На складе $have кг (последняя партия $batch кг) — использовать $use кг, остаток $left кг оставить на складе';
  }

  @override
  String get paintCount => 'Пересчитать остаток';

  @override
  String paintCountTitle(String title) {
    return 'Сколько на самом деле: $title?';
  }

  @override
  String get paintCountHint =>
      'Взвесьте остаток. Разница с программой запишется как расход.';

  @override
  String get mdfGloss => 'Блеск';

  @override
  String get mdfGlossNone => '—';

  @override
  String get mdfGlossMatt => 'матовая';

  @override
  String get mdfGlossSemi => 'полуматовая';

  @override
  String get mdfGlossGloss => 'глянец';

  @override
  String get mdfGlossMetallic => 'металлик';

  @override
  String get mdfGlossPearl => 'перламутр';

  @override
  String get paintDeliveryOwed => 'Должны за доставку краски';

  @override
  String get paintDeliveryBack => 'Вернули';

  @override
  String get paintDeliveryPaid => 'Оплатили';

  @override
  String paintDeliveryToEmployee(String name) {
    return 'платил $name';
  }

  @override
  String get paintDeliveryToCarrier => 'перевозчику не оплачено';

  @override
  String get cncAccept => 'Принять в работу';

  @override
  String get cncAddCustom => 'Своя работа';

  @override
  String get cncAddMaterial => 'Наш материал';

  @override
  String get cncAddService => 'Работа из прайса';

  @override
  String cncAhead(String time) {
    return 'до него $time';
  }

  @override
  String get cncAmount => 'Сумма';

  @override
  String get cncByAgreement => 'договорная';

  @override
  String get cncCancel => 'Отменить заказ';

  @override
  String get cncCancelTitle => 'Почему отменяем?';

  @override
  String cncCost(String price) {
    return 'себестоимость $price';
  }

  @override
  String get cncCustomWork => 'Что за работа';

  @override
  String cncDayMinutes(String minutes) {
    return 'станок $minutes мин в день';
  }

  @override
  String get cncDayMinutesLabel => 'Минут работы станка в день';

  @override
  String cncDebtComment(String amount) {
    return 'Долг $amount — почему выдаём?';
  }

  @override
  String get cncDebtLabel => 'Должны';

  @override
  String cncDefects(String text) {
    return 'дефекты: $text';
  }

  @override
  String cncDue(String day) {
    return 'срок $day';
  }

  @override
  String get cncEmpty => 'Заказов ЧПУ пока нет — нажмите «Новый заказ».';

  @override
  String cncEta(String day) {
    return 'готово $day';
  }

  @override
  String get cncHandOver => 'Выдать';

  @override
  String cncHandedOverOn(String day, String who) {
    return 'Выдан $day: $who';
  }

  @override
  String get cncHint => 'Станок на заказ: столешницы, распил, решётки';

  @override
  String get cncHistory => 'История';

  @override
  String get cncHold => 'Ждём…';

  @override
  String get cncHoldTitle => 'Чего ждём?';

  @override
  String cncHolding(String reason) {
    return 'ждём: $reason';
  }

  @override
  String get cncHours => 'ч';

  @override
  String get cncIntake => 'Материал клиента';

  @override
  String get cncIntakeAdd => 'Добавить, что привёз';

  @override
  String get cncIntakeDefects => 'Дефекты (скол, царапина)';

  @override
  String get cncIntakeWhat => 'Что (столешница 3000×600, лист ЛДСП)';

  @override
  String get cncLineNote => 'Примечание';

  @override
  String cncMachineTime(String time) {
    return 'Время станка: $time';
  }

  @override
  String get cncMakerPrices => 'Цены для мебельщика';

  @override
  String cncMinOrder(String amount) {
    return 'минималка $amount';
  }

  @override
  String get cncMinOrderLabel => 'Минимальный заказ, ₸';

  @override
  String get cncMinutesShort => 'мин';

  @override
  String get cncNewOrder => 'Новый заказ';

  @override
  String get cncNoGroup => 'Прочее';

  @override
  String get cncNoMaterials => 'На складе пока нет листов.';

  @override
  String get cncNoPhone => 'У клиента нет телефона в карточке.';

  @override
  String get cncNoPrice => 'нет цены';

  @override
  String get cncNotReady => 'Снять «готово»';

  @override
  String get cncNotes => 'Примечание к заказу';

  @override
  String get cncOk => 'Готово';

  @override
  String cncOwes(String amount) {
    return 'долг $amount';
  }

  @override
  String cncPaid(String amount) {
    return 'оплачено $amount';
  }

  @override
  String get cncPay => 'Оплата';

  @override
  String get cncPayments => 'Оплаты';

  @override
  String cncPerUnitMinutes(String minutes) {
    return '$minutes мин на ед.';
  }

  @override
  String get cncPickCustomer => 'Выберите клиента';

  @override
  String get cncPricesTitle => 'Прайс услуг ЧПУ';

  @override
  String get cncQty => 'Кол-во';

  @override
  String get cncQueueLabel => 'Очередь станка';

  @override
  String cncQueueOrders(int count) {
    return 'заказов: $count';
  }

  @override
  String get cncRate => 'Цена';

  @override
  String get cncReadyAction => 'Готово';

  @override
  String get cncReadyLabel => 'Готово к выдаче';

  @override
  String cncReadyMessage(String name) {
    return 'Здравствуйте! Ваш заказ $name готов, можно забирать.';
  }

  @override
  String cncReadyMessageDebt(String name, String amount) {
    return 'Здравствуйте! Ваш заказ $name готов. К оплате: $amount.';
  }

  @override
  String get cncRemove => 'Убрать';

  @override
  String get cncSaveDraft => 'Сохранить';

  @override
  String get cncSaved => 'Сохранено';

  @override
  String get cncSearchHint => 'Номер или клиент';

  @override
  String get cncServiceAdd => 'Добавить услугу';

  @override
  String get cncServiceEdit => 'Услуга';

  @override
  String get cncServiceGroup => 'Группа (Распил, Столешницы…)';

  @override
  String get cncServiceMinutes => 'Минут станка на единицу';

  @override
  String get cncServiceOff => 'выключена';

  @override
  String get cncServiceOn => 'В прайсе';

  @override
  String get cncServicePrice => 'Цена за единицу, ₸';

  @override
  String get cncServiceTitle => 'Название';

  @override
  String get cncServiceTrade => 'Цена мебельщикам, ₸';

  @override
  String get cncSettingsTitle => 'Срочность, минималка, день станка';

  @override
  String get cncStart => 'На станок';

  @override
  String get cncStatusAll => 'Все';

  @override
  String get cncStatusCancelled => 'Отменён';

  @override
  String get cncStatusDraft => 'Черновик';

  @override
  String get cncStatusHandedOver => 'Выдан';

  @override
  String get cncStatusOnMachine => 'На станке';

  @override
  String get cncStatusQueued => 'В очереди';

  @override
  String get cncStatusReady => 'Готов';

  @override
  String get cncTakenBy => 'Забрал (если не клиент)';

  @override
  String get cncTakenPhone => 'Его телефон';

  @override
  String get cncTell => 'Написать клиенту';

  @override
  String get cncTerms =>
      'Клиент согласен: за скрытые дефекты своего материала отвечает сам';

  @override
  String get cncTermsAgreed =>
      'Клиент согласен: за скрытые дефекты отвечает сам.';

  @override
  String get cncTitle => 'Услуги ЧПУ';

  @override
  String get cncTotal => 'Итого';

  @override
  String cncTradePrice(String price) {
    return 'мебельщикам $price';
  }

  @override
  String get cncUnhold => 'Больше не ждём';

  @override
  String get cncUrgent => 'Срочно';

  @override
  String cncUrgentPct(String pct) {
    return 'срочность +$pct%';
  }

  @override
  String get cncUrgentPctLabel => 'Наценка за срочность, %';

  @override
  String get cncWork => 'Работы';

  @override
  String get mdfGiveStageTo => 'Кому отдать этот этап?';

  @override
  String get mdfStageTakeBack => 'Снять — никому';

  @override
  String get mdfStagePostPeople => 'По должности';

  @override
  String get mdfAllWorkers => 'Все сотрудники';

  @override
  String mdfStageGiven(String stage, String name) {
    return '$stage: $name';
  }

  @override
  String get mdfStageNobody => 'не назначен';

  @override
  String get teamDeptIntake => 'Приём заказов';

  @override
  String get teamDeptCut => 'Раскрой';

  @override
  String get teamDeptCnc => 'ЧПУ';

  @override
  String get teamDeptSand => 'Шлифовка';

  @override
  String get teamDeptPvc => 'ПВХ плёнка';

  @override
  String get teamDeptPaint => 'Покраска';

  @override
  String get teamDeptPack => 'Упаковка и выдача';

  @override
  String get teamDeptFilmSales => 'Продажа плёнки';

  @override
  String get teamDeptWarehouse => 'Склад и доставка';

  @override
  String get teamPostManager => 'Менеджер по приёму';

  @override
  String get teamPostCutter => 'Раскройщик';

  @override
  String get teamPostCncOperator => 'ЧПУшник';

  @override
  String get teamPostSander => 'Шкурщик';

  @override
  String get teamPostSanderPvc => 'Шкурщик ПВХ';

  @override
  String get teamPostSanderPaint => 'Шкурщик покраски';

  @override
  String get teamPostVacuum => 'Вакуумщик';

  @override
  String get teamPostPainter => 'Маляр';

  @override
  String get teamPostPacker => 'Упаковщик';

  @override
  String get teamPostSeller => 'Продажник';

  @override
  String get teamPostLoader => 'Грузчик';

  @override
  String get teamPostStorekeeper => 'Кладовщик';

  @override
  String get teamPostDriver => 'Водитель';

  @override
  String get teamDepartmentsSection => 'Отделы и люди';

  @override
  String get teamDepartmentsHint =>
      'Этап заказа уходит людям своей должности. Значок телефона — отмечает сам, без него — отмечает менеджер.';

  @override
  String get teamAddPerson => 'Сотрудник';

  @override
  String get teamAddPersonShort => 'Ещё';

  @override
  String get teamLeft => 'Ушли из компании';

  @override
  String get teamPersonBack => 'Вернуть в команду';

  @override
  String get teamUnplaced => 'Без должности';

  @override
  String get teamPostEmpty => 'никого';

  @override
  String get teamPostEmptyAdd => 'Добавить';

  @override
  String teamPersonSaved(String name) {
    return '$name — сохранено';
  }

  @override
  String teamPersonLeftTitle(String name) {
    return '$name уволен?';
  }

  @override
  String get teamPersonLeftMessage =>
      'Он пропадёт из списков и с этапов, а сделанная им работа останется за ним.';

  @override
  String get teamPersonLeft => 'Уволен';

  @override
  String get teamPersonName => 'Имя и фамилия';

  @override
  String get teamPersonPhone => 'Телефон';

  @override
  String get teamPersonPosts => 'Должности — можно несколько';

  @override
  String get teamPersonLogin => 'Вход в программу';

  @override
  String get teamPersonLoginHint =>
      'С входом он видит «Мои заказы» на телефоне и отмечает сам. Без входа за него отмечает менеджер.';

  @override
  String get teamPersonNoLogin => 'Без входа';

  @override
  String get teamPersonSave => 'Сохранить';

  @override
  String get teamLoginsSection => 'Вход в программу';

  @override
  String get myWorkTitle => 'Мои заказы';

  @override
  String myWorkDone(String order, String stage) {
    return '$order: «$stage» — сделано';
  }

  @override
  String get myWorkUndo => 'Отменить';

  @override
  String get myWorkNotLinkedTitle => 'Вы ещё не в команде';

  @override
  String get myWorkNotLinked =>
      'Попросите менеджера в «Команде» привязать ваш вход к сотруднику и указать должность.';

  @override
  String get myWorkReady => 'Можно делать';

  @override
  String get myWorkNothingReady => 'Сейчас ничего не ждёт вас.';

  @override
  String get myWorkComing => 'Скоро дойдёт';

  @override
  String get myWorkMonth => 'Мой объём за месяц';

  @override
  String myWorkMonthTotal(String area, int orders) {
    return '$area м² · заказов: $orders';
  }

  @override
  String myWorkDue(String date) {
    return 'срок $date';
  }

  @override
  String myWorkWaiting(String stages) {
    return 'ждёт: $stages';
  }

  @override
  String get myWorkDoneButton => 'Сделал';

  @override
  String myWorkStageM2(String stage, String area) {
    return '$stage $area м²';
  }

  @override
  String get glueTitle => 'Клей для ПВХ';

  @override
  String get glueRowHint => 'Клеи, поставщики, норма на м², фрезеровки';

  @override
  String get glueHint =>
      'Клей — товар: что за клей и сколько уходит на м². Поставщик — где покупаем. При «Вакууме» списывается клей «в работе».';

  @override
  String get glueReceive => 'Приход клея';

  @override
  String get glueAdd => 'Новый клей';

  @override
  String get glueEdit => 'Карточка клея';

  @override
  String get glueName => 'Название';

  @override
  String get glueOrigin => 'Производство';

  @override
  String get glueOriginHint => 'например, Китай';

  @override
  String get glueBucketKg => 'Ведро, кг';

  @override
  String get glueKgPerLitre => 'Кг в литре';

  @override
  String get glueKgPerLitreHint => 'из паспорта клея, обычно около 1';

  @override
  String get glueNorm => 'Норма, г/м²';

  @override
  String get glueReserve => 'Не продавать ниже, кг (себе)';

  @override
  String get glueMarkupBucket => 'Наценка на ведро, %';

  @override
  String get glueMarkupLitre => 'Наценка на литр, %';

  @override
  String get glueInWork => 'В работе';

  @override
  String get glueTakeInWork => 'Взять в работу';

  @override
  String get glueCount => 'Пересчитать';

  @override
  String glueCountTitle(String title) {
    return '$title: сколько кг на самом деле';
  }

  @override
  String glueOnHand(String kg) {
    return 'На складе $kg кг';
  }

  @override
  String glueNormLine(String g) {
    return 'Норма $g г/м²';
  }

  @override
  String glueCostKg(String money) {
    return '$money/кг с доставкой';
  }

  @override
  String glueCostM2(String money) {
    return '$money на 1 м²';
  }

  @override
  String glueSell(String bucket, String litre) {
    return 'Продажа: ведро $bucket · литр $litre';
  }

  @override
  String glueFact(String g) {
    return 'Факт за месяц: $g г/м²';
  }

  @override
  String glueQueue(String orders, String m2, String kg) {
    return 'Очередь вакуума: $orders зак., $m2 м² — нужно $kg кг клея';
  }

  @override
  String glueQueueShort(String kg) {
    return 'Клея в работе не хватает: $kg кг';
  }

  @override
  String get glueNoInWork =>
      'Ни один клей не в работе — выберите открытую бочку';

  @override
  String get glueGlues => 'Клеи';

  @override
  String get glueEmpty => 'Клеев пока нет — добавьте первый';

  @override
  String get glueSuppliers => 'Где покупаем';

  @override
  String get glueSupplierAdd => 'Поставщик клея';

  @override
  String glueBought(
    String title,
    String price,
    String delivery,
    String landed,
  ) {
    return '$title: $price + доставка $delivery = $landed за кг';
  }

  @override
  String get glueCheapest => 'дешевле';

  @override
  String get glueMilling => 'Поправка фрезеровки';

  @override
  String glueMillingHint(String coats) {
    return 'Во сколько раз больше клея, чем на гладкое лицо; 1,00 — так же. Кромки — $coats слоя.';
  }

  @override
  String glueMillingTitle(String name) {
    return '$name: поправка';
  }

  @override
  String get glueOwed => 'Должны за клей';

  @override
  String get glueGlue => 'Клей';

  @override
  String get glueSupplier => 'Поставщик';

  @override
  String get glueQty => 'Сколько';

  @override
  String get gluePrice => 'Цена';

  @override
  String get gluePer => 'за';

  @override
  String get glueUnitKg => 'кг';

  @override
  String get glueUnitLitre => 'литр';

  @override
  String get glueUnitBucket => 'ведро';

  @override
  String glueReceiveSum(String kg, String price) {
    return '$kg кг по $price за кг';
  }

  @override
  String glueLanded(String money) {
    return 'С доставкой: $money за кг';
  }

  @override
  String get glueSave => 'Сохранить';

  @override
  String glueOrderPlan(String kg, String title, String norm) {
    return 'Клей ПВХ: $kg кг · $title · $norm г/м²';
  }

  @override
  String glueLineKg(String kg) {
    return 'клей $kg кг';
  }

  @override
  String get filmSaleAddGlue => 'Клей';

  @override
  String get filmGlueNone => 'Клеев нет — добавьте в «Клей для ПВХ»';

  @override
  String filmGlueBuckets(String n) {
    return '$n вед.';
  }

  @override
  String filmGlueLitres(String n) {
    return '$n л';
  }

  @override
  String filmGlueReserve(String title, String left, String keep) {
    return 'Клея «$title» останется $left кг — цеху нужно $keep кг';
  }

  @override
  String get filmGlueReserveOk => 'Продать из запаса цеха';

  @override
  String filmGlueOver(String have) {
    return 'На складе только $have кг';
  }

  @override
  String filmGlueLeft(String kg, String left) {
    return '≈ $kg кг со склада · останется $left кг';
  }

  @override
  String filmGlueBelow(String cost) {
    return 'Дешевле себестоимости: $cost за кг с доставкой';
  }

  @override
  String get glueMonthTitle => 'Сверка клея за месяц';

  @override
  String get glueMonthHint =>
      'Сколько м² прошло через вакуум, сколько клея на них ушло по норме и что показало взвешивание остатка. Факт виден, только если в месяце взвешивали.';

  @override
  String get glueMonthEmpty => 'В этом месяце клей на заказы не списывали.';

  @override
  String glueMonthLine(String m2, String kg) {
    return '$m2 м² через вакуум · по норме $kg кг';
  }

  @override
  String glueMonthShort(String kg, String money) {
    return 'Недостача $kg кг — $money';
  }

  @override
  String glueMonthOver(String kg, String money) {
    return 'Излишек $kg кг — $money';
  }

  @override
  String get glueMonthEven => 'Взвешивание сошлось с нормой';

  @override
  String get glueMonthNotCounted =>
      'В этом месяце не взвешивали — факта нет. Взвесьте остаток («Пересчитать») в конце месяца.';

  @override
  String glueMonthWeighed(String count, String date) {
    return 'Взвешивали раз: $count, последний — $date';
  }

  @override
  String glueMonthFact(String fact, String norm, String pct) {
    return 'Факт $fact г/м² при норме $norm ($pct%)';
  }

  @override
  String glueMonthCostM2(String norm, String fact) {
    return 'м² по норме $norm, по факту $fact';
  }

  @override
  String glueMonthFixNorm(String g) {
    return 'Поправить норму на $g г/м²';
  }

  @override
  String glueMonthNormSet(String g) {
    return 'Норма теперь $g г/м²';
  }

  @override
  String get filmGlueOpen => 'Клей для ПВХ';

  @override
  String get glueAddFirst => 'Завести первый клей';

  @override
  String get filmReceiveFilm => 'Плёнка';

  @override
  String get filmReceiveGlue => 'Клей для ПВХ';

  @override
  String get filmFigGlue => 'Клей ПВХ';

  @override
  String get filmFigGlueNone => 'не заведён — нажмите';

  @override
  String filmFigGlueKg(String kg) {
    return '$kg кг';
  }

  @override
  String filmFigGlueBuckets(String buckets) {
    return '≈ $buckets ведра';
  }

  @override
  String filmFigGlueDays(String days) {
    return 'хватит на $days дн.';
  }

  @override
  String get cncpTitle => 'Узоры ЧПУ (β)';

  @override
  String get cncpRowHint => 'Проба: узор фасада → программа для станка';

  @override
  String get cncpOffTitle => 'Узоры ЧПУ — проба (β)';

  @override
  String get cncpOffBody =>
      'Библиотека узоров (рамки, арки, пазы) и фрез: под любой размер фасада рисует рез и пишет программу G-код для вашего станка.\n\nПока выключено — никак не участвует в работе. Включённое только читает размеры заказа: не меняет заказы, склад, деньги и этапы и ничего не отправляет на станок само — сохраняет файл, который оператор проверяет на обрезке.';

  @override
  String get cncpEnable => 'Включить на этой базе';

  @override
  String get cncpEnabledDone => 'Узоры ЧПУ включены на этой базе';

  @override
  String get cncpOwnerTurnsOn => 'Включает владелец компании.';

  @override
  String get cncpNotYours =>
      'Модуль включён, но вам его не открыли. Попросите владельца.';

  @override
  String get cncpBetaBanner =>
      'Проба: каждую новую программу сначала режьте на обрезке МДФ. На станок само ничего не уходит.';

  @override
  String get cncpTabPatterns => 'Узоры';

  @override
  String get cncpTabTools => 'Фрезы';

  @override
  String get cncpTabMachine => 'Станок';

  @override
  String get cncpTabAccess => 'Доступ';

  @override
  String get cncpPatternsHint =>
      'Узор рисуется один раз, от краёв фасада, и подходит под любой размер. Свяжите его с фрезеровкой — и позиции заказа получат свои программы.';

  @override
  String get cncpPatternsEmpty => 'Узоров пока нет.';

  @override
  String get cncpPatternNew => 'Новый узор';

  @override
  String get cncpExample => 'пример';

  @override
  String get cncpExampleWarning =>
      'Узор-пример: проверьте размеры и прорежьте на обрезке, прежде чем на фасаде.';

  @override
  String get cncpNoMilling => 'Не связан с фрезеровкой';

  @override
  String cncpForMilling(String milling) {
    return 'Фрезеровка: $milling';
  }

  @override
  String cncpMinSize(String w, String h) {
    return 'От $w×$h мм';
  }

  @override
  String cncpMinSizeFallback(String w, String h, String fallback) {
    return 'От $w×$h мм; меньше — «$fallback»';
  }

  @override
  String cncpLineFrame(String offset) {
    return 'Рамка, отступ $offset мм';
  }

  @override
  String cncpLineFrameRound(String offset, String radius) {
    return 'Рамка, отступ $offset мм, скруглённые углы R$radius';
  }

  @override
  String cncpLineFrameCove(String offset, String radius) {
    return 'Рамка, отступ $offset мм, вогнутые углы R$radius';
  }

  @override
  String cncpLineArch(String offset, String rise) {
    return 'Арка, отступ $offset мм, подъём $rise мм';
  }

  @override
  String cncpLineGroovesV(String step) {
    return 'Вертикальные пазы через $step мм';
  }

  @override
  String cncpLineGroovesH(String step) {
    return 'Горизонтальные пазы через $step мм';
  }

  @override
  String cncpLineTool(String shape, String tool, String depth) {
    return '$shape · $tool · глубина $depth мм';
  }

  @override
  String get cncpPatternName => 'Название узора';

  @override
  String get cncpPatternMilling => 'Фрезеровка';

  @override
  String get cncpPatternMillingHint =>
      'Позиции с этой фрезеровкой режутся этим узором';

  @override
  String get cncpPatternMinW => 'Меньшая сторона от, мм';

  @override
  String get cncpPatternMinH => 'Большая сторона от, мм';

  @override
  String get cncpPatternFallback => 'Для фасадов меньше';

  @override
  String get cncpPatternFallbackHint =>
      'Этот узор режется, когда фасад меньше размеров выше';

  @override
  String get cncpNone => '—';

  @override
  String get cncpElements => 'Элементы';

  @override
  String get cncpElementAdd => 'Добавить элемент';

  @override
  String get cncpKindFrame => 'Рамка';

  @override
  String get cncpKindArch => 'Арка';

  @override
  String get cncpKindGrooves => 'Пазы';

  @override
  String get cncpTool => 'Фреза';

  @override
  String get cncpDepth => 'Глубина, мм';

  @override
  String get cncpOffset => 'Отступ от края, мм';

  @override
  String get cncpOffsetHint => 'До середины реза';

  @override
  String get cncpCornerSquare => 'Прямой';

  @override
  String get cncpCornerRound => 'Скруглённый';

  @override
  String get cncpCornerCove => 'Вогнутый';

  @override
  String get cncpRadius => 'Радиус угла, мм';

  @override
  String get cncpRise => 'Подъём арки, мм';

  @override
  String get cncpVertical => 'Вертикальные';

  @override
  String get cncpHorizontal => 'Горизонтальные';

  @override
  String get cncpStep => 'Шаг, мм';

  @override
  String get cncpSide => 'Отступ по бокам, мм';

  @override
  String get cncpSideHint => '0 — по всей ширине';

  @override
  String get cncpEnds => 'Не доходить до торцов, мм';

  @override
  String get cncpEndsHint => '0 — насквозь, от края до края';

  @override
  String get cncpTryWidth => 'и ширине, мм';

  @override
  String get cncpTryHeight => 'Проверить на высоте, мм';

  @override
  String get cncpPreviewFailed => 'Нет связи — узор не нарисовать.';

  @override
  String cncpPreviewStats(String minutes, String files) {
    return '≈ $minutes мин станка · программ: $files';
  }

  @override
  String cncpFileLine(
    String tool,
    String metres,
    String passes,
    String minutes,
  ) {
    return '$tool: рез $metres м, проходов $passes, ≈ $minutes мин';
  }

  @override
  String get cncpDownload => 'Сохранить G-код';

  @override
  String get cncpCheckOnOffcut =>
      'Сначала прорежьте на обрезке; ноль — левый нижний угол фасада, Z0 — его поверхность.';

  @override
  String get cncpTrialsFolder => 'Пробы';

  @override
  String cncpSavedTo(String dir) {
    return 'Сохранено: $dir';
  }

  @override
  String cncpSavedFiles(String count, String dir) {
    return 'Сохранено программ: $count — $dir';
  }

  @override
  String get cncpOpenFolder => 'Открыть папку';

  @override
  String get cncpSave => 'Сохранить';

  @override
  String get cncpDelete => 'Удалить';

  @override
  String cncpPatternSaved(String name) {
    return 'Узор «$name» сохранён';
  }

  @override
  String cncpPatternDeleteAsk(String name) {
    return 'Удалить узор «$name»?';
  }

  @override
  String get cncpToolsHint =>
      'Фрезы и режимы, на которых они режут МДФ. Узор называет свою фрезу; две фрезы — две программы, одна за другой.';

  @override
  String get cncpToolNew => 'Новая фреза';

  @override
  String get cncpToolName => 'Название';

  @override
  String get cncpToolV => 'V-образная';

  @override
  String get cncpToolBall => 'Радиусная';

  @override
  String get cncpToolFlat => 'Прямая';

  @override
  String cncpToolLine(
    String kind,
    String diameter,
    String feed,
    String rpm,
    String pass,
  ) {
    return '$kind · ⌀$diameter мм · подача $feed мм/мин · $rpm об/мин · $pass мм за проход';
  }

  @override
  String get cncpDiameter => 'Диаметр, мм';

  @override
  String get cncpAngle => 'Угол, °';

  @override
  String get cncpFeed => 'Подача, мм/мин';

  @override
  String get cncpPlunge => 'Подача врезания, мм/мин';

  @override
  String get cncpRpm => 'Шпиндель, об/мин';

  @override
  String get cncpPassDepth => 'Глубина за проход, мм';

  @override
  String get cncpMachineHint =>
      'Как ваш станок читает программу. NcStudio, DSP и Mach3 читают обычный G-код; если стойка не принимает дуги — выключите дуги. Комментарии всегда пишутся латиницей.';

  @override
  String get cncpExt => 'Расширение файла';

  @override
  String get cncpArcs => 'Дуги командами G2/G3 (выкл. — короткими отрезками)';

  @override
  String get cncpComments => 'Комментарии в программе';

  @override
  String get cncpLineNumbers => 'Номера строк N10, N20…';

  @override
  String get cncpSwapXy => 'Высота фасада вдоль оси X';

  @override
  String get cncpSafeZ => 'Безопасная высота, мм';

  @override
  String get cncpClearZ => 'Высота подхода, мм';

  @override
  String get cncpRapid => 'Скорость холостых, мм/мин (для расчёта времени)';

  @override
  String get cncpDwell => 'Пауза на разгон шпинделя, с (0 — нет)';

  @override
  String get cncpOriginNote =>
      'Ноль программы — левый нижний угол фасада; Z0 — его поверхность, рез идёт ниже.';

  @override
  String get cncpMachineSaved => 'Настройки станка сохранены';

  @override
  String get cncpAccessHint =>
      'Кто, кроме вас, видит «Узоры ЧПУ» на этой базе.';

  @override
  String get cncpAccessSaved => 'Доступ сохранён';

  @override
  String get cncpDisable => 'Выключить';

  @override
  String get cncpDisabledDone => 'Выключено. Библиотека сохранена.';

  @override
  String get cncpOrderButton => 'ЧПУ (β)';

  @override
  String get cncpOrderTitle => 'Программы для станка (β)';

  @override
  String cncpOrderMinutes(String minutes) {
    return '≈ $minutes мин станка на весь заказ';
  }

  @override
  String cncpOrderLine(
    String no,
    String height,
    String width,
    String qty,
    String milling,
  ) {
    return '№$no · $height×$width · $qty шт · $milling';
  }

  @override
  String get cncpOrderNoPattern => 'Для этой фрезеровки нет узора';

  @override
  String cncpOrderPattern(String pattern, String minutes) {
    return '$pattern · ≈ $minutes мин за штуку';
  }

  @override
  String cncpOrderSaveAll(String count) {
    return 'Сохранить программы ($count)';
  }

  @override
  String get fdcTitle => 'Каталоги поставщиков';

  @override
  String get fdcPictures =>
      'Картинки по кодам или названиям (несколько файлов)';

  @override
  String get fdcImport => 'Загрузить каталог (zip)';

  @override
  String fdcImported(String added, String updated) {
    return 'Каталог загружен: новых $added, обновлено $updated';
  }

  @override
  String fdcPicturesDone(String count) {
    return 'Картинок привязано к плёнкам: $count';
  }

  @override
  String fdcPicturesMissed(String count, String names) {
    return 'Привязано: $count. Не нашлась плёнка для: $names';
  }

  @override
  String get fdcEmpty =>
      'Каталогов пока нет. Загрузите zip, собранный из каталога поставщика, или пришлите PDF поставщика — его соберут.';

  @override
  String get fdcSearch => 'Название или код';

  @override
  String get fdcHint =>
      'Справочник декоров производителя, не склад. Нажмите на декор — заведёте плёнку; ваши плёнки с тем же названием показывают картинку сами.';

  @override
  String fdcYouHave(String metres) {
    return 'У вас есть · $metres м';
  }

  @override
  String fdcThicknesses(String value) {
    return 'Толщины: $value';
  }

  @override
  String get fdcYourFilms => 'Ваши плёнки этого декора';

  @override
  String fdcFilmLine(String label, String metres) {
    return '$label · $metres м';
  }

  @override
  String get fdcMakeHint =>
      'У вас такой плёнки ещё нет. Название, коллекция, код и цвет возьмутся из каталога поставщика; цены — в карточке плёнки.';

  @override
  String get fdcMake => 'Завести плёнку';

  @override
  String fdcMade(String label) {
    return 'Плёнка заведена: $label';
  }

  @override
  String get fdcPhoto => 'Фото образца';

  @override
  String get fdcPhotoClear => 'Вернуть картинку каталога';

  @override
  String get fdcNoPicture => 'Картинки пока нет';

  @override
  String get gsrFind => 'Найти…';

  @override
  String get gsrHotkey => 'Ctrl+K';

  @override
  String get gsrHint => 'Клиент, телефон, № заказа, плёнка, раздел…';

  @override
  String get gsrTabAll => 'Всё';

  @override
  String get gsrTabCustomers => 'Клиенты';

  @override
  String get gsrTabOrders => 'Заказы';

  @override
  String get gsrTabMoney => 'Деньги';

  @override
  String get gsrTabFilm => 'Плёнка';

  @override
  String get gsrTabStock => 'Склад';

  @override
  String get gsrTabGo => 'Разделы';

  @override
  String get gsrGroupRecent => 'Недавние';

  @override
  String get gsrGroupActions => 'Действия';

  @override
  String get gsrGroupSections => 'Разделы';

  @override
  String get gsrGroupCustomers => 'Клиенты';

  @override
  String get gsrGroupFacadeOrders => 'Заказы фасадов';

  @override
  String get gsrGroupCncOrders => 'Заказы ЧПУ';

  @override
  String get gsrGroupPayments => 'Оплаты';

  @override
  String get gsrGroupFilms => 'Плёнки на складе';

  @override
  String get gsrGroupDecors => 'Каталоги поставщиков';

  @override
  String get gsrGroupOrders => 'Прочие заказы';

  @override
  String get gsrGroupWorkOrders => 'Производство';

  @override
  String get gsrGroupStock => 'Склад';

  @override
  String gsrOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заказа',
      many: '$count заказов',
      few: '$count заказа',
      one: '$count заказ',
    );
    return '$_temp0';
  }

  @override
  String gsrDebt(String amount) {
    return 'долг $amount';
  }

  @override
  String get gsrFilmCustomer => 'покупает плёнку';

  @override
  String get gsrActOrders => 'Заказы';

  @override
  String get gsrActNewOrder => 'Новый заказ';

  @override
  String get gsrActSell => 'Продать';

  @override
  String get gsrActCopyPhone => 'Скопировать телефон';

  @override
  String get gsrPhoneCopied => 'Телефон скопирован';

  @override
  String get gsrDoNewFacadeOrder => 'Новый заказ фасадов';

  @override
  String get gsrDoNewCncOrder => 'Новый заказ ЧПУ';

  @override
  String get gsrDoSellFilm => 'Продать плёнку';

  @override
  String get gsrDoSellGlue => 'Продать клей';

  @override
  String get gsrDoReceiveFilm => 'Приход плёнки';

  @override
  String get gsrDoReceiveGlue => 'Приход клея';

  @override
  String get gsrStart =>
      'Начните печатать — найду клиента, заказ, плёнку или раздел. Раскладку и опечатки прощаю.';

  @override
  String gsrNothing(String query) {
    return 'По «$query» ничего не нашлось';
  }

  @override
  String get gsrByPhone => 'Ищу по телефону';

  @override
  String gsrByNumber(String number) {
    return 'Ищу заказ № $number';
  }

  @override
  String get gsrKeys => '↑↓ выбрать · Enter открыть · Esc закрыть';

  @override
  String gsrPaid(String amount) {
    return 'оплата $amount';
  }

  @override
  String get navToWrite => 'Кому написать';

  @override
  String get clcTitle => 'Карточка клиента';

  @override
  String get clcOrders => 'Заказов';

  @override
  String get clcTotal => 'Сумма заказов';

  @override
  String get clcPaid => 'Оплачено';

  @override
  String get clcDebt => 'Долг';

  @override
  String get clcAverage => 'Средний чек';

  @override
  String get clcLast => 'Последний заказ';

  @override
  String clcSince(String date) {
    return 'клиент с $date';
  }

  @override
  String get clcNewOrder => 'Новый заказ';

  @override
  String get clcSellFilm => 'Продать плёнку';

  @override
  String get clcAllOrders => 'Все заказы';

  @override
  String get clcOrdersSection => 'Заказы';

  @override
  String get clcPaymentsSection => 'Оплаты';

  @override
  String get clcFilmSection => 'Плёнка';

  @override
  String clcFilmLine(String metres, String sum, String debt) {
    return 'куплено $metres м на $sum · долг $debt';
  }

  @override
  String get clcFilmOpen => 'Покупки плёнки';

  @override
  String get clcNoOrders => 'Заказов пока нет';

  @override
  String get clcCnc => 'ЧПУ';

  @override
  String get clcWhatsApp => 'Написать в WhatsApp';

  @override
  String twReady(int count) {
    return 'Готовы — сообщить клиенту ($count)';
  }

  @override
  String twDebts(int count) {
    return 'Напомнить о долге ($count)';
  }

  @override
  String twFilm(int count) {
    return 'Плёнка — долги ($count)';
  }

  @override
  String get twEmpty => 'Сегодня писать некому';

  @override
  String get twEmptyHint =>
      'Здесь появятся готовые заказы, о которых клиент ещё не знает, и долги, о которых пора напомнить.';

  @override
  String twReadyLine(String date) {
    return 'готов $date';
  }

  @override
  String twDebtLine(String sum) {
    return 'к оплате $sum';
  }

  @override
  String twHandedLine(String date) {
    return 'выдан $date';
  }

  @override
  String twRemindedLine(int count, String date) {
    return 'напоминали: $count, последний раз $date';
  }

  @override
  String twFilmDays(int days) {
    return 'долгу $days дн.';
  }

  @override
  String get twSend => 'Написать в WhatsApp';

  @override
  String get twMark => 'Отправил';

  @override
  String get twMarked => 'Отмечено — больше не спрошу';

  @override
  String get twSentQ => 'Отправили сообщение?';

  @override
  String get twNoPhone => 'У клиента нет телефона';

  @override
  String get twTemplates => 'Тексты сообщений';

  @override
  String get twTemplateReady => 'Заказ готов';

  @override
  String get twTemplateDebt => 'Долг по заказу';

  @override
  String get twTemplateFilm => 'Долг за плёнку';

  @override
  String get twTemplateHint => 'Можно вставить:';

  @override
  String get twTemplateReset => 'Вернуть исходный';

  @override
  String get twTemplateSave => 'Сохранить';

  @override
  String get dsmTitle => 'Итоги дня';

  @override
  String dsmSwitch(String hour) {
    return 'Присылать мне каждый день в $hour:00';
  }

  @override
  String get dsmHint =>
      'Придёт в Telegram или WhatsApp, если он подключён в «Настройки → Каналы».';

  @override
  String get dsmCopy => 'Скопировать';

  @override
  String get dsmCopied => 'Итоги скопированы';

  @override
  String get dsmSendMe => 'Отправить себе в WhatsApp';

  @override
  String get dsmHour => 'Час';

  @override
  String get orderTell => 'Сообщить клиенту';

  @override
  String orderTold(String date) {
    return 'Клиенту сообщили $date';
  }

  @override
  String get fdcMatchPhoto => 'Подобрать по фото образца';

  @override
  String get fdcMatchTitle => 'Похожие на образец';

  @override
  String get fdcMatchHint =>
      'Фото при дневном свете, без тени; читается середина снимка. Это подсказка — сверяйте с образцом глазами.';

  @override
  String get fdcAnalogues => 'Аналоги';

  @override
  String fdcAnaloguesTitle(String name) {
    return 'Аналоги: $name';
  }

  @override
  String get fdcLikeClose => 'очень похож';

  @override
  String get fdcLikeNear => 'похож';

  @override
  String get fdcLikeFar => 'отдалённо';

  @override
  String fdcOnShelf(String metres) {
    return 'на складе $metres м';
  }

  @override
  String get fdcNotOnShelf => 'нет на складе';

  @override
  String get fdcNoMatches => 'Ничего похожего не нашлось';

  @override
  String get dsmMorning =>
      'Утренняя сводка в 9:00 — что выдать, что опаздывает, кто должен, чего не хватает';

  @override
  String get dsmMorningTitle => 'Утренняя сводка';

  @override
  String get scanEntryTitle => 'Номер заказа';

  @override
  String get scanEntryHint => '245 или код с наклейки';

  @override
  String get scanEntryOpen => 'Открыть';

  @override
  String scanTitle(String number, String customer) {
    return '№ $number · $customer';
  }

  @override
  String get scanHandedOver => 'Уже отдан клиенту';

  @override
  String get scanOnHold => 'Заказ на паузе';

  @override
  String scanDoneOn(String date) {
    return 'сделано $date';
  }

  @override
  String get scanYours => 'ваш — можно делать';

  @override
  String get scanNotYours => 'не ваш';

  @override
  String get scanOpenOrder => 'Открыть заказ';

  @override
  String get mdfPrintSticker => 'Наклейка';

  @override
  String get navOffcuts => 'Обрезки';

  @override
  String get offcutsTitle => 'Обрезки МДФ';

  @override
  String offcutsSummary(int count, String area) {
    return '$count шт · $area м²';
  }

  @override
  String get offcutsAdd => 'Положить';

  @override
  String get offcutsAll => 'Все';

  @override
  String offcutsMm(int mm) {
    return '$mm мм';
  }

  @override
  String get offcutsEmptyTitle => 'Обрезков нет';

  @override
  String get offcutsEmpty =>
      'Кусок, оставшийся от листа, кладите на полку с размером — мелкие детали новых заказов сначала выкроим из него.';

  @override
  String offcutsCell(String cell) {
    return 'ячейка $cell';
  }

  @override
  String offcutsFrom(String number) {
    return 'от № $number';
  }

  @override
  String offcutsFor(String number) {
    return 'под № $number';
  }

  @override
  String get offcutsUse => 'Взят в работу';

  @override
  String get offcutsScrap => 'В утиль';

  @override
  String get offcutsAddTitle => 'Обрезок на полку';

  @override
  String get offcutsThickness => 'Толщина';

  @override
  String get offcutsLength => 'Длина, мм';

  @override
  String get offcutsWidth => 'Ширина, мм';

  @override
  String get offcutsCellLabel => 'Где лежит';

  @override
  String get offcutsCellHint => 'А-3';

  @override
  String get offcutsNote => 'Заметка';

  @override
  String get offcutsPut => 'Положить';

  @override
  String offcutsSuggestTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count деталей',
      few: '$count детали',
      one: '$count деталь',
    );
    return 'Из обрезков: $_temp0';
  }

  @override
  String offcutsSuggestLine(
    int position,
    String part,
    String offcut,
    String cell,
  ) {
    return 'Поз. $position: $part — из $offcut, $cell';
  }

  @override
  String get offcutsTake => 'Взять';

  @override
  String mdfFilmToBuy(String metres) {
    return 'нет на складе · заказать $metres м';
  }

  @override
  String mdfFilmToBuyFrom(String metres, String from) {
    return 'нет на складе · $metres м у $from';
  }

  @override
  String filmOrdersForOrders(int count, String metres) {
    return 'для заказов ($count) · $metres м';
  }

  @override
  String mdfClientPartsSome(int marked, int total) {
    return 'ЛМДФ клиента: $marked из $total';
  }

  @override
  String get fpkTitle => 'Плёнка ПВХ';

  @override
  String get fpkSearch => 'Название, код или производитель';

  @override
  String get fpkByPhoto => 'По фото образца';

  @override
  String get fpkAll => 'Все';

  @override
  String get fpkOnShelf => 'На складе';

  @override
  String get fpkRecent => 'Недавние у этого клиента';

  @override
  String fpkFound(int count) {
    return 'Найдено $count · сначала то, что на складе';
  }

  @override
  String get fpkCatalogOnly => 'только в каталоге';

  @override
  String get fpkNothing => 'Ничего не нашлось';

  @override
  String get fpkNone => 'Без плёнки';

  @override
  String get cncpArtcam => 'Из ArtCAM';

  @override
  String get cncpArtcamTitle => 'Фрезы из ArtCAM';

  @override
  String cncpArtcamHint(int all, int ready) {
    return 'В файле $all, завести можно $ready. Отмечены фрезы для дерева и МДФ.';
  }

  @override
  String cncpArtcamAdd(int count) {
    return 'Добавить $count';
  }

  @override
  String cncpArtcamAdded(int count) {
    return 'Добавлено фрез: $count';
  }

  @override
  String get cncpToolsSearch => 'Найти фрезу: название, диаметр, угол';

  @override
  String get fpkCard => 'Карточка плёнки';

  @override
  String get fpkSideFilm => 'Плёнка';

  @override
  String get fpkSideEdit => 'Изменить';

  @override
  String get fpkSidePick => 'Выбрать';

  @override
  String get fpkSideNone => 'на складе нет';

  @override
  String fpkSideHeld(String metres) {
    return 'под заказы: $metres м';
  }

  @override
  String fpkSideComing(String metres, String day) {
    return 'едет $metres м · $day';
  }

  @override
  String fpkSideDaily(String metres, String days) {
    return 'уходит ~$metres м в день · хватит на $days дн.';
  }

  @override
  String fpkSideBuy(String price) {
    return 'закуп $price/м';
  }

  @override
  String fpkSideRetail(String price) {
    return 'розница $price/м';
  }

  @override
  String fpkSideWholesale(String price) {
    return 'опт $price/м';
  }

  @override
  String get fwTitle => 'Плёнки нет — где взять';

  @override
  String get fwWhere => 'где взять';

  @override
  String get fwNothingShort => 'Этой плёнки уже хватает.';

  @override
  String fwNeedBy(String day) {
    return 'нужна в цеху к $day';
  }

  @override
  String get fwUrgent => 'срочный';

  @override
  String fwShort(String metres) {
    return 'не хватает $metres м';
  }

  @override
  String fwOrdered(String metres, String supplier) {
    return 'Заказано $metres м · $supplier';
  }

  @override
  String fwNowhere(String day) {
    return 'Нет нигде — обзвонили $day';
  }

  @override
  String fwNoSources(String maker) {
    return 'У «$maker» нет поставщиков — добавьте в «Где брать».';
  }

  @override
  String get fwAdvised => 'советую';

  @override
  String fwPrice(String price, String delivery, String landed) {
    return '$price + доставка $delivery = $landed за м';
  }

  @override
  String fwPriceOnly(String price) {
    return '$price за м';
  }

  @override
  String get fwCardPrice => 'цена из карточки';

  @override
  String fwTimes(String count) {
    return 'брали $count раз';
  }

  @override
  String fwComes(String days, String day) {
    return '$days дн. → придёт $day';
  }

  @override
  String get fwInTime => 'успевает';

  @override
  String get fwLate => 'не успевает';

  @override
  String get fwLeadUnknown => 'срок не указан';

  @override
  String get fwOrderButton => 'Есть — заказать';

  @override
  String get fwAcceptFirst => 'Заказать можно после «Принять».';

  @override
  String get fwNowhereButton => 'Нет нигде';

  @override
  String get fwLookalikes => 'Похожие у других фирм';

  @override
  String fwOnShelf(String metres) {
    return 'у нас $metres м';
  }

  @override
  String get fwOffer => 'Предложить клиенту в WhatsApp';

  @override
  String fwOfferText(String film, String other) {
    return 'Здравствуйте! Плёнки «$film» сейчас нет у поставщиков. Есть очень похожая — «$other». Подойдёт вам?';
  }

  @override
  String get fwReplace => 'Заменить';

  @override
  String fwReplaceTitle(String film, String other) {
    return 'Заменить «$film» на «$other»?';
  }

  @override
  String get fwReplaceReason =>
      'Почему — например, «клиент согласен по WhatsApp»';

  @override
  String fwOrderTitle(String film, String supplier) {
    return '$film — у $supplier';
  }

  @override
  String get fwMetres => 'Сколько метров';

  @override
  String get fwPriceField => 'Цена за метр, которую назвали';

  @override
  String get fwSaidBy => 'Кто подтвердил (менеджер поставщика)';

  @override
  String get fwComesOn => 'Привезут';

  @override
  String get fwOrderConfirm => 'В «К заказу»';

  @override
  String get fwOrderedDone => 'Добавлено в «К заказу».';

  @override
  String get filmReceiveTitle => 'Приход плёнки';

  @override
  String get filmReceiveWaiting => 'Ждём — то, что заказали';

  @override
  String get filmReceiveNothingWaited =>
      'Ничего не ждём — найдите плёнку ниже.';

  @override
  String filmReceiveOrderedFrom(String supplier) {
    return 'Заказано у $supplier';
  }

  @override
  String get filmReceiveAllCame => 'Пришло всё';

  @override
  String filmReceiveMetres(String metres) {
    return '$metres м';
  }

  @override
  String get filmReceiveOther => 'Или другая плёнка — и из каталогов';

  @override
  String get filmReceiveSearch => 'Фирма, цвет или код';

  @override
  String get filmReceiveDone => 'Плёнка на складе.';

  @override
  String filmReceiveRestComing(String metres) {
    return 'Остаток $metres м остаётся в пути.';
  }

  @override
  String get filmCatalogueTools => 'Загрузка каталогов и картинок';

  @override
  String filmOurs(String count) {
    return 'У нас · $count';
  }

  @override
  String filmCatalogueOf(String maker, String count) {
    return 'Каталог $maker · ещё $count';
  }

  @override
  String get filmCatalogueHint =>
      'Нажмите на декор — завести плёнку или посмотреть.';

  @override
  String get filmReceiveCatalogues => 'Каталоги фирм — нажмите, чтобы открыть';

  @override
  String filmReceiveCatalogOf(String maker, int count) {
    return 'Каталог $maker · ещё не заведено: $count';
  }

  @override
  String filmReceiveCatalogFound(int count) {
    return 'Из каталогов · $count';
  }

  @override
  String filmReceiveCatalogMore(int count) {
    return 'Ещё $count — уточните поиск или коллекцию';
  }

  @override
  String get pcTitle => 'Каталог красок';

  @override
  String get pcByPhoto => 'По фото образца';

  @override
  String get pcAdd => 'Краска';

  @override
  String get pcNoSystem => 'Без системы';

  @override
  String get pcSearch => 'Код или название: 7016, графит, слоновая кость';

  @override
  String get pcShowAll => 'Все';

  @override
  String get pcShowPopular => 'Ходовые у нас';

  @override
  String get pcShowTop => 'Топ-20 мебели';

  @override
  String get pcShowTrend => 'Тренды';

  @override
  String get pcShowStock => 'На складе';

  @override
  String get pcShowStarred => 'Избранные';

  @override
  String get pcShowHidden => 'Скрытые';

  @override
  String pcOurs(int days) {
    return 'Ходовые у нас · за $days дней';
  }

  @override
  String get pcTrends => 'Тренды · кухни и шкафы';

  @override
  String pcAllOf(String system, int count) {
    return 'Все $system · $count';
  }

  @override
  String get pcNothing => 'Ничего не нашлось.';

  @override
  String get pcByPhotoTitle => 'Ближе всего к образцу';

  @override
  String pcKg(String kg) {
    return '$kg кг';
  }

  @override
  String get pcNone => 'нет';

  @override
  String pcM2(String m2) {
    return '$m2 м²';
  }

  @override
  String get pcTrend => 'тренд';

  @override
  String get pcLookSame => 'почти не отличить';

  @override
  String get pcLookClose => 'заметно вблизи';

  @override
  String get pcLookOther => 'другой оттенок';

  @override
  String get pcNoneShelf => 'на складе нет';

  @override
  String pcShelfEnough(String kg, String m2) {
    return 'На складе $kg кг — хватит на ≈ $m2 м²';
  }

  @override
  String pcPainted(int orders, String m2, int days) {
    return 'Заказов: $orders · $m2 м² за $days дней';
  }

  @override
  String get pcOnList => 'В работе: есть в списке красок для заказов';

  @override
  String get pcNotOnList =>
      'Ещё не в работе — «В работу», чтобы брать в заказы';

  @override
  String get pcSimilar => 'Похожие';

  @override
  String get pcStar => 'В избранное';

  @override
  String get pcEdit => 'Изменить';

  @override
  String get pcTake => 'В работу';

  @override
  String get pcEditTitle => 'Карточка цвета';

  @override
  String get pcAddTitle => 'Новая краска';

  @override
  String get pcSystem => 'Система цвета';

  @override
  String get pcCode => 'Код';

  @override
  String get pcCodeHint =>
      'RAL 210 50 15, NCS S 2005-Y40R — или пусто для своего цвета';

  @override
  String get pcName => 'Название';

  @override
  String get pcHex => 'Оттенок на экране';

  @override
  String get pcHexHint => '#8A9977 — примерно, для поиска и сравнения';

  @override
  String get pcHide => 'Скрыть из каталога';

  @override
  String get pcSave => 'Сохранить';

  @override
  String get pcAddSave => 'Добавить';

  @override
  String get pswWhich => 'Какой цвет заменить?';

  @override
  String get pswStart => 'Нет у поставщиков — замена цвета';

  @override
  String get pswWayTint => 'колеровка';

  @override
  String get pswWayWait => 'ждём родной';

  @override
  String pswWaitUntil(String day) {
    return 'ждём родной до $day';
  }

  @override
  String get pswAsked => 'ждём согласия клиента';

  @override
  String get pswViaWhatsApp => 'в WhatsApp';

  @override
  String get pswViaInPerson => 'лично';

  @override
  String get pswViaPhone => 'по телефону';

  @override
  String pswAgreed(String who, String day, String via) {
    return 'согласовал $who $day $via';
  }

  @override
  String pswTitle(String order) {
    return 'Замена цвета · заказ №$order';
  }

  @override
  String pswAskedLine(String target) {
    return 'Предложили: $target — ждём ответа клиента';
  }

  @override
  String get pswHow => 'Что делаем';

  @override
  String get pswReplace => 'Заменить';

  @override
  String get pswTint => 'Заколеровать';

  @override
  String get pswWait => 'Ждать родной';

  @override
  String get pswNearest => 'Похожие, которые есть · ближе — выше';

  @override
  String get pswTintHint =>
      'Сделаем точно в цвет из базы и пигментов — у поставщика с колеровкой или сами.';

  @override
  String get pswWaitPick => 'Когда ждём?';

  @override
  String get pswRule =>
      'Пока клиент не согласен, заказ не уходит в покраску. В заказе останутся оба цвета и кто согласовал.';

  @override
  String get pswCancel => 'Не спрашивать';

  @override
  String get pswAgreeWhatsApp => 'Согласен в WhatsApp';

  @override
  String get pswAgreePhone => 'Клиент согласен по телефону';

  @override
  String get pswAsk => 'Спросить клиента';

  @override
  String get pswChosen => 'Выбрал клиент';

  @override
  String get pswOffered => 'Предлагаем';

  @override
  String get filmMakerAddButton => 'Фирма';

  @override
  String get filmMakerAddTitle => 'Новая фирма';

  @override
  String get filmMakerAddName => 'Название фирмы';

  @override
  String get filmMakerAddNameHint => 'Как на рулоне: Kira Group, Adilet…';

  @override
  String get filmMakerAddWhere => 'Где берём';

  @override
  String get filmMakerAddNewSource => 'Новый поставщик';

  @override
  String get filmMakerAddSourceName => 'Поставщик (например, Kira · Костанай)';

  @override
  String get filmMakerAddCatalogueHint =>
      'Каталог с фото можно загрузить потом — значок 📎 вверху.';

  @override
  String get filmMakerAddSave => 'Добавить';

  @override
  String get mdfAddWorker => 'Добавить человека';

  @override
  String get mdfAddWorkerHint =>
      'В «Команду», на этот участок — потом выберите его здесь';

  @override
  String get mdfNoWorkers => 'В «Команде» пока никого нет';

  @override
  String mdfMarginUnsure(int count) {
    return 'неточно: без цены — $count';
  }

  @override
  String mdfMarginShares(String material, String work, String margin) {
    return 'материал $material · работа $work · маржа $margin';
  }

  @override
  String get mdfMarginMaterials => 'Материалы';

  @override
  String get mdfMarginQty => 'сколько';

  @override
  String get mdfMarginPrice => 'цена';

  @override
  String get mdfMarginSum => 'сумма';

  @override
  String get mdfMarginNoPrice => 'нет';

  @override
  String get mdfMarginSetPrice => 'Указать';

  @override
  String get mdfMarginRates => 'Тарифы';

  @override
  String get mdfMarginNoWork =>
      'Работа не начислена: этапы не отмечены или нет тарифов';

  @override
  String get mdfMarginCost => 'Себестоимость';

  @override
  String get mdfMarginEstimateShort =>
      'по сегодняшним ценам, материал ещё не списан';

  @override
  String get mdfMarginNotCountedShort => 'без электричества и доставки';

  @override
  String mdfMarginPriceTitle(String title) {
    return 'Цена: $title';
  }

  @override
  String get mdfMarginPriceLabel => 'Цена за единицу, ₸';

  @override
  String get mdfMarginPriceHint =>
      'Плёнка — за метр. Запишется в карточку материала.';

  @override
  String get ppOwn => 'Свой цвет';

  @override
  String get ppTheirs => 'Этот клиент красил раньше';

  @override
  String ppEnough(String enough, String need) {
    return 'хватит на ≈ $enough м² · в заказе $need м²';
  }

  @override
  String ppShort(String enough, String need) {
    return 'не хватит: на складе на ≈ $enough м², в заказе $need м² — закажите краску или «Замена цвета»';
  }

  @override
  String get ppPickHint => 'Нажмите на цвет — он сразу выбран';

  @override
  String get ppChoose => 'Выбрать';

  @override
  String get cncpTryThickness => 'толщина, мм';

  @override
  String get cncpViewTop => 'Сверху';

  @override
  String get cncpView3d => '3D';

  @override
  String get cncp3dFront => 'Спереди';

  @override
  String get cncp3dSide => 'Сбоку';

  @override
  String get cncp3dTilt => 'Наклон';

  @override
  String get cncp3dHint => 'Крутите мышью или пальцем';

  @override
  String get cncpSection => 'Разрез от края к середине · 1:1';

  @override
  String cncpSectionStats(String from, String to, String deepest, String left) {
    return 'узор $from–$to мм от края · глубже всего $deepest мм · остаётся $left мм';
  }

  @override
  String get cncpSectionNone => 'На середине высоты фреза не проходит';

  @override
  String cncpThrough(String deepest, String thickness) {
    return 'Насквозь: фреза уходит на $deepest мм при толщине $thickness мм';
  }

  @override
  String cncpThin(String left) {
    return 'Остаётся мало материала: $left мм';
  }

  @override
  String get cncpTryOn => 'Примерить плёнку или краску';

  @override
  String get ctoTitle => 'Примерка';

  @override
  String get ctoFilms => 'Плёнки ПВХ';

  @override
  String get ctoPaints => 'Краски';

  @override
  String get ctoSearch => 'Поиск: дуб, софт, 9010';

  @override
  String get ctoAllMakers => 'Все';

  @override
  String get ctoAcross => 'Рисунок поперёк';

  @override
  String get ctoCompare => 'В сравнение';

  @override
  String get ctoCompareClear => 'Убрать сравнение';

  @override
  String get ctoCompareFull => 'Сравнить можно до 4 вариантов';

  @override
  String get ctoSave => 'Картинка клиенту';

  @override
  String ctoSavedTo(String dir) {
    return 'Картинка сохранена: $dir — перетащите её в WhatsApp';
  }

  @override
  String get ctoFolder => 'Для клиента';

  @override
  String get ctoNote => 'Цвет на экране может немного отличаться от образца';

  @override
  String get ctoBare => 'МДФ без покрытия';

  @override
  String ctoMore(int count) {
    return 'и ещё $count — уточните поиск';
  }

  @override
  String get ctoNoCatalogue => 'Каталог не загрузился';

  @override
  String get pcOpenCard => 'Карточка краски — посмотреть и изменить';

  @override
  String get cncpKindPocket => 'Выборка';

  @override
  String cncpLinePocket(String offset) {
    return 'Выборка, отступ $offset мм';
  }

  @override
  String get cncpPocketHint =>
      'Всё внутри режется на одну глубину — прямой или радиусной фрезой';

  @override
  String cncpRidge(String height, String at) {
    return 'Гребень $height мм на $at мм от края — проходы не сходятся: сдвиньте один или возьмите фрезу шире';
  }

  @override
  String cncpWall(String width, String at) {
    return 'Тонкая стенка $width мм на $at мм от края — может отколоться';
  }

  @override
  String get cncpSimulate => 'Симуляция: ход фрезы';

  @override
  String get mdfAddCoating => 'Добавить покрытие:';

  @override
  String get mdfQuickColours => 'или сразу цвет:';

  @override
  String get mdfGroupCopy => 'Копия в другом цвете';

  @override
  String mdfGroupCopyTo(String coating) {
    return 'Копия → $coating';
  }

  @override
  String get paintStepWhat => 'Что пришло';

  @override
  String get paintStepColour => 'Цвет и вид';

  @override
  String get paintStepWhich => 'Какой';

  @override
  String get paintStepAmount => 'Сколько и почём';

  @override
  String get paintStepSupplier => 'Поставщик и оплата';

  @override
  String get paintStepDelivery => 'Доставка';

  @override
  String get paintKindPaint => 'Краска / эмаль';

  @override
  String get paintColourPick => 'Выберите цвет — нажмите здесь';

  @override
  String get paintColourChange => 'сменить';

  @override
  String paintColourNeed(String need, String have) {
    return 'ждут заказы $need кг · есть $have кг';
  }

  @override
  String get paintPinnedQueue => 'Ждут заказы — докупить';

  @override
  String get paintPinnedShelf => 'На складе';

  @override
  String get paintBaseName => 'Название';

  @override
  String paintVariantOnHand(String kg) {
    return 'есть $kg кг';
  }

  @override
  String paintVariantNew(String material) {
    return 'Новый: $material';
  }

  @override
  String paintPriceHistory(String list) {
    return 'раньше: $list';
  }

  @override
  String get paintLineMore => '+ ещё позиция в этот приход';

  @override
  String get paintPhoto => 'Фото накладной';

  @override
  String get mdfCustomerSearchWide =>
      'Имя, телефон, организация, адрес объекта или № заказа';

  @override
  String get mdfCustomerShowRecent => 'Недавние';

  @override
  String get mdfCustomerShowVip => 'VIP';

  @override
  String get mdfCustomerShowDebt => 'С долгом';

  @override
  String get mdfCustomerShowWork => 'Заказ в работе';

  @override
  String get mdfCustomerShowIdle => 'Давно не заказывал';

  @override
  String mdfCustomerLast(String day, String what, int count) {
    return 'последний $day · $what · заказов: $count';
  }

  @override
  String mdfCustomerDebt(String sum) {
    return 'долг $sum';
  }

  @override
  String mdfCustomerInWork(int count) {
    return 'в работе: $count';
  }

  @override
  String get mdfCustomerRepeat => 'Повторить прошлый';

  @override
  String get mdfCustomerWhatsApp => 'Написать в WhatsApp';

  @override
  String get mdfCustomerCard => 'Карточка клиента';

  @override
  String mdfCustomerAddTyped(String name, String phone) {
    return 'Добавить клиента «$name» $phone';
  }

  @override
  String mdfCustomerSamePhone(String name) {
    return 'Этот телефон уже у клиента «$name». Выбрать его?';
  }

  @override
  String get mdfCustomerTakeHim => 'Выбрать его';

  @override
  String get mdfCustomerTerms => 'Условия клиента';

  @override
  String get mdfCustomerDiscount => 'Скидка, %';

  @override
  String get mdfCustomerPricePvc => 'Своя цена ПВХ, ₸/м²';

  @override
  String get mdfCustomerPricePaint => 'Своя цена краска, ₸/м²';

  @override
  String get mdfCustomerDebtLimit => 'Лимит долга, ₸';

  @override
  String get mdfCustomerDebtLimitHint => 'Пусто — общий лимит';

  @override
  String get mdfCustomerSource => 'Откуда пришёл:';

  @override
  String get mdfCustomerSourceWord => 'Сарафан';

  @override
  String get mdfCustomerSource2gis => '2ГИС';

  @override
  String get mdfCustomerSourceRepeat => 'Повторный';

  @override
  String get mdfCustomerSourceOther => 'Другое';

  @override
  String get mdfDebtLimitDefault => 'Лимит долга по умолчанию';

  @override
  String get mdfDebtLimitDefaultHint => '₸; 0 или пусто — без лимита';

  @override
  String mdfCustomerDiscountBadge(String pct) {
    return 'скидка $pct%';
  }

  @override
  String get mdfCustomerOwnPrice => 'своя цена';

  @override
  String mdfDebtOverLimit(String after, String limit) {
    return 'Долг клиента станет $after — больше лимита $limit';
  }

  @override
  String get mdfDebtOverLimitWho => 'Кто разрешил и почему';

  @override
  String invoiceVatIn(String rate, String sum) {
    return 'В том числе НДС $rate%: $sum';
  }

  @override
  String get invoiceNoVat => 'Без НДС';

  @override
  String invoiceBasis(String what) {
    return 'Основание: $what';
  }

  @override
  String mdfInvoiceBasis(String no) {
    return 'заказ № $no';
  }

  @override
  String get mdfInvoiceButton => 'Счёт на оплату';

  @override
  String get mdfInvoiceSum => 'Сумма';

  @override
  String get mdfInvoiceWhole => 'Весь остаток';

  @override
  String get mdfInvoiceHalf => 'Предоплата 50%';

  @override
  String get mdfInvoiceOwn => 'Своя сумма';

  @override
  String get mdfInvoicePayer => 'Плательщик (ТОО, ИП или сам клиент)';

  @override
  String get mdfInvoiceBin => 'БИН/ИИН плательщика';

  @override
  String get mdfInvoiceBinBad => 'БИН/ИИН — 12 цифр';

  @override
  String get mdfInvoicePayerHint => 'Запомнится в карточке клиента';

  @override
  String mdfInvoiceVat(String rate) {
    return 'С НДС $rate%';
  }

  @override
  String get mdfInvoiceMake => 'Выставить и отправить';

  @override
  String mdfInvoiceRow(String no, String day, String sum) {
    return 'Счёт № $no от $day · $sum';
  }

  @override
  String mdfInvoiceWaiting(String day) {
    return 'ждём оплату до $day';
  }

  @override
  String mdfInvoiceOverdue(String day) {
    return 'срок оплаты прошёл $day';
  }

  @override
  String mdfInvoicePart(String paid, String sum) {
    return 'оплачено $paid из $sum';
  }

  @override
  String get mdfInvoicePaid => 'оплачен';

  @override
  String get mdfInvoiceCancelled => 'отменён';

  @override
  String get mdfInvoiceAgain => 'Напечатать / отправить';

  @override
  String get mdfInvoiceCancel => 'Отменить счёт';

  @override
  String get mdfInvoiceCancelWhy => 'Почему счёт отменяется';

  @override
  String mdfPayByInvoice(String no, String sum) {
    return 'По счёту № $no · $sum';
  }

  @override
  String get filmReceiveCataloguesHead => 'Каталоги фирм';

  @override
  String clcRepeat(String no) {
    return 'Повторить № $no';
  }

  @override
  String get clcHistory => 'История';

  @override
  String get clcShowAll => 'Все';

  @override
  String get clcShowReady => 'Готовы';

  @override
  String get clcShowWork => 'В работе';

  @override
  String get clcShowDebt => 'С долгом';

  @override
  String get clcGroupReady => 'Готовы к выдаче';

  @override
  String get clcGroupWork => 'В работе';

  @override
  String get clcGroupDraft => 'Черновики';

  @override
  String get clcGroupHanded => 'Выданы';

  @override
  String clcDueBy(String date) {
    return 'к $date';
  }

  @override
  String clcDebtDays(int days) {
    return '$days дн.';
  }

  @override
  String clcOldDebt(int days, String sum) {
    return 'дольше $days дн.: $sum';
  }

  @override
  String clcPaidSplit(int count) {
    return 'Оплата разнесена по заказам: $count';
  }

  @override
  String get clcRemind => 'Напомнить';

  @override
  String get clcPayAll => 'Оплата';

  @override
  String clcLimitOver(String limit, String over) {
    return 'лимит $limit · превышен на $over';
  }

  @override
  String clcLimit(String limit) {
    return 'лимит долга $limit';
  }

  @override
  String get clcTerms => 'Условия';

  @override
  String clcTermDiscount(String pct) {
    return 'скидка $pct%';
  }

  @override
  String clcTermPvc(String sum) {
    return 'своя цена ПВХ $sum/м²';
  }

  @override
  String clcTermPaint(String sum) {
    return 'своя цена краска $sum/м²';
  }

  @override
  String get clcTermList => 'по прайсу';

  @override
  String get clcColours => 'Его цвета';

  @override
  String clcPayOwes(String sum) {
    return 'должен $sum';
  }

  @override
  String clcPayOver(String sum) {
    return 'больше долга ($sum) — переплату вносят в заказ';
  }

  @override
  String get clcPaySplit => 'Разнесётся по заказам — сначала самые старые:';

  @override
  String clcPayPart(String sum) {
    return '(из $sum)';
  }

  @override
  String get clcPaySave => 'Внести';

  @override
  String get clcNoteHint => 'Заметка о клиенте: звонить после 14:00…';

  @override
  String get clcNoteSave => 'Записать';

  @override
  String get clcHistOrders => 'Заказы';

  @override
  String get clcHistMoney => 'Деньги';

  @override
  String get clcHistMessages => 'Сообщения';

  @override
  String get clcHistNotes => 'Заметки';

  @override
  String get clcHistEmpty => 'Пока ничего';

  @override
  String get clcToday => 'Сегодня';

  @override
  String get actTitle => 'Акт сверки';

  @override
  String actPeriod(String since, String until) {
    return 'за период с $since по $until';
  }

  @override
  String actBetween(String ours, String theirs) {
    return 'между $ours и $theirs';
  }

  @override
  String get actDate => 'Дата';

  @override
  String get actDocument => 'Документ';

  @override
  String get actDebit => 'Дебет';

  @override
  String get actCredit => 'Кредит';

  @override
  String get actOpening => 'Сальдо на начало';

  @override
  String get actTurnover => 'Обороты за период';

  @override
  String get actClosing => 'Сальдо на конец';

  @override
  String actNoDebt(String company, String date) {
    return 'По данным $company на $date задолженность отсутствует.';
  }

  @override
  String actTheyOwe(String company, String date, String payer, String sum) {
    return 'По данным $company на $date задолженность $payer перед $company составляет $sum.';
  }

  @override
  String actWeOwe(String company, String date, String payer, String sum) {
    return 'По данным $company на $date задолженность $company перед $payer составляет $sum.';
  }

  @override
  String get actStamp => 'подпись, М.П.';

  @override
  String get actAllTime => 'Всё время';

  @override
  String get actThisMonth => 'Этот месяц';

  @override
  String get actLastMonth => 'Прошлый месяц';

  @override
  String get actThisYear => 'Этот год';

  @override
  String get actMake => 'Сделать и отправить';

  @override
  String get dinvButton => 'Счёт на весь долг';

  @override
  String get dinvSection => 'Счета на долг';

  @override
  String get dinvWhole => 'Весь долг';

  @override
  String get dinvOrders => 'В счёт войдут заказы — сначала самые старые:';

  @override
  String get clcPayNoInvoice => 'Без счёта';

  @override
  String clcPayByInvoice(String no, String sum) {
    return 'По счёту № $no · осталось $sum';
  }

  @override
  String get rateTitle => 'Рейтинг клиентов';

  @override
  String get rateP3 => '3 месяца';

  @override
  String get rateP12 => '12 месяцев';

  @override
  String get rateByMoney => 'По деньгам';

  @override
  String get rateByDebt => 'По долгу';

  @override
  String get rateBySlow => 'Кто тянет';

  @override
  String get rateFast => 'платит быстро';

  @override
  String get rateUsual => 'платит обычно';

  @override
  String get rateSlow => 'тянет';

  @override
  String ratePayDays(String days) {
    return 'платит в среднем за $days дн.';
  }

  @override
  String get rateNoPaid => 'оплаченных заказов ещё нет';

  @override
  String rateOrders(int count, String share) {
    return '$count зак. · $share% денег';
  }

  @override
  String rateOwes(String sum, int days) {
    return 'долг $sum · $days дн.';
  }

  @override
  String rateTotal(String sum) {
    return 'Все заказы: $sum';
  }

  @override
  String get rateClassHint =>
      'A — те немногие, кто вместе приносит 80% денег; B — следующие 15%; C — остальные.';

  @override
  String get rateEmpty => 'За этот период заказов нет';

  @override
  String mdfDueByShop(String day, int days) {
    return 'По загрузке цеха — $day ($days раб. дн.)';
  }

  @override
  String get mdfDueRough => '— примерно: цех ещё мало сдал, темп неизвестен';

  @override
  String mdfDueTooSoon(String day) {
    return 'Цех успеет только к $day';
  }

  @override
  String get cstTitle => 'Расходы цеха';

  @override
  String get cstTabMoney => 'Куда идут деньги';

  @override
  String get cstTabBills => 'Счета за месяц';

  @override
  String get cstTabConsumables => 'Расходники';

  @override
  String get cstTabItems => 'Статьи затрат';

  @override
  String get cstPrevMonth => 'Прошлый месяц';

  @override
  String get cstNextMonth => 'Следующий месяц';

  @override
  String get cstRevenue => 'Выручка';

  @override
  String get cstCosts => 'Расходы';

  @override
  String get cstProfit => 'Прибыль';

  @override
  String cstMade(int orders, String m2) {
    return '$orders зак. готово · $m2 м²';
  }

  @override
  String get cstCostPerM2 => '1 м² стоит цеху';

  @override
  String cstOverheadPerM2(String sum) {
    return 'накладные $sum на м²';
  }

  @override
  String get cstBreakEven => 'В ноль выходим с';

  @override
  String cstBreakEvenValue(String m2) {
    return '$m2 м² в месяц';
  }

  @override
  String cstBreakEvenSpare(String m2, int pct) {
    return 'сделали $m2 — запас $pct%';
  }

  @override
  String cstBreakEvenShort(String m2, int pct) {
    return 'сделали $m2 — не хватает $pct%';
  }

  @override
  String get cstBreakEvenUnknown => 'нет готовых заказов за месяц';

  @override
  String cstOfRevenue(String pct) {
    return '$pct% выручки';
  }

  @override
  String get cstWhere => 'Куда ушли деньги';

  @override
  String get cstItems => 'По статьям';

  @override
  String get cstAreas => 'По участкам';

  @override
  String get cstAlerts => 'Обратить внимание';

  @override
  String cstAlertLimit(String title, String sum, String limit, int pct) {
    return '$title: $sum — выше лимита $limit на $pct%';
  }

  @override
  String cstAlertJump(String title, String sum, String times) {
    return '$title: $sum — в $times раза больше обычного';
  }

  @override
  String cstAlertUnfilled(String title) {
    return '$title: счёт за месяц не внесён';
  }

  @override
  String cstUsual(String sum) {
    return 'обычно $sum';
  }

  @override
  String cstLimitOf(String sum) {
    return 'лимит $sum';
  }

  @override
  String get cstFixed => 'постоянная';

  @override
  String get cstVariable => 'переменная';

  @override
  String get cstEmptyMonth => 'За этот месяц пока ничего не посчитано';

  @override
  String cstBillsTotal(int filled, int count, String sum) {
    return 'Внесено $filled из $count · $sum';
  }

  @override
  String get cstBillNotEntered => 'не внесено';

  @override
  String cstBillLast(String sum) {
    return 'в прошлом месяце $sum';
  }

  @override
  String get cstBillAmount => 'Сумма за месяц';

  @override
  String cstMeterUsed(String used, String unit) {
    return 'Расход: $used $unit';
  }

  @override
  String get cstNote => 'Заметка';

  @override
  String get cstSave => 'Сохранить';

  @override
  String get cstSaved => 'Сохранено';

  @override
  String cstOnHand(String qty, String unit) {
    return 'на складе $qty $unit';
  }

  @override
  String cstMinimum(String qty) {
    return 'минимум $qty';
  }

  @override
  String cstTaken30(String qty) {
    return 'за месяц взяли $qty';
  }

  @override
  String get cstLow => 'мало';

  @override
  String get cstNew => 'новая';

  @override
  String get cstTake => 'Взял';

  @override
  String get cstTakeHow => 'Сколько';

  @override
  String get cstReceive => 'Купили';

  @override
  String get cstPrice => 'Цена за единицу';

  @override
  String get cstSupplier => 'Где купили (необязательно)';

  @override
  String get cstSetMinimum => 'Минимум';

  @override
  String get cstQuickAdd => 'Нет в списке';

  @override
  String get cstQuickAddTitle => 'Что взяли';

  @override
  String get cstUnit => 'Единица';

  @override
  String get cstAddItem => 'Добавить статью';

  @override
  String get cstEditItem => 'Статья затрат';

  @override
  String get cstItemTitle => 'Название';

  @override
  String get cstGroup => 'Группа';

  @override
  String get cstArea => 'Участок';

  @override
  String get cstMode => 'Как учитывать';

  @override
  String get cstModeBill => 'Счёт за месяц';

  @override
  String get cstModeStock => 'Склад';

  @override
  String get cstModeOther => 'По факту';

  @override
  String get cstFixedSwitch => 'Постоянная — не зависит от объёма';

  @override
  String get cstLimit => 'Лимит в месяц';

  @override
  String get cstSearch => 'Найти: нож, стрейч, свет…';

  @override
  String get cstShowArchived => 'Архив';

  @override
  String get cstArchive => 'В архив';

  @override
  String get cstRestore => 'Вернуть из архива';

  @override
  String get cstMerge => 'Слить с…';

  @override
  String cstMergeHint(String title) {
    return 'История «$title» перейдёт в выбранную статью';
  }

  @override
  String get cstMeter => 'Счётчик';

  @override
  String get cstMeterStart => 'на начало';

  @override
  String get cstMeterEnd => 'на конец';

  @override
  String get pplTitle => 'Сотрудники';

  @override
  String get pplSubtitle => 'Кто что сделал, сколько заработал и получил';

  @override
  String get pplDay => 'День';

  @override
  String get pplWeek => 'Неделя';

  @override
  String get pplMonth => 'Месяц';

  @override
  String get pplPrev => 'Раньше';

  @override
  String get pplNext => 'Позже';

  @override
  String get pplM2 => 'Сделано';

  @override
  String get pplStages => 'Этапов';

  @override
  String get pplEarned => 'Заработал';

  @override
  String get pplAdvance => 'Аванс';

  @override
  String get pplLeft => 'Осталось отдать';

  @override
  String get pplDays => 'Дней с работой';

  @override
  String get pplOrders => 'Заказов';

  @override
  String get pplEmpty => 'В «Команде» пока никого нет.';

  @override
  String get pplMoney => 'Деньги';

  @override
  String get pplPiece => 'Сдельная';

  @override
  String get pplPending => 'Ждёт подтверждения';

  @override
  String get pplBonus => 'Премии';

  @override
  String get pplFine => 'Штрафы';

  @override
  String get pplFineOne => 'Штраф';

  @override
  String get pplBonusOne => 'Премия';

  @override
  String get pplPaid => 'Отдано';

  @override
  String get pplByDay => 'По дням';

  @override
  String get pplDayHint => 'Нажмите на столбик — покажет день';

  @override
  String get pplByStage => 'По этапам';

  @override
  String get pplWorks => 'Работы';

  @override
  String get pplEntries => 'Сдельные записи';

  @override
  String get pplAdjustments => 'Авансы, штрафы, премии';

  @override
  String get pplPayouts => 'Выплаты';

  @override
  String get pplMine => 'Мой заработок';

  @override
  String get pplNothing => 'За этот период ничего не отмечено.';

  @override
  String get pplNotApproved => 'не подтверждено';

  @override
  String get pplOpenCard => 'Карточка';

  @override
  String get tmViewDepartments => 'По отделам';

  @override
  String get tmViewPeople => 'Люди';

  @override
  String get tmSearch => 'Найти по имени';

  @override
  String get tmFilterAll => 'Все';

  @override
  String get tmFilterNoLogin => 'Без входа';

  @override
  String get tmFilterLeft => 'Ушли';

  @override
  String get tmAddPost => 'должность';

  @override
  String tmGiven(String name, String post) {
    return '$name: дали «$post»';
  }

  @override
  String tmTaken(String name, String post) {
    return '$name: сняли «$post»';
  }

  @override
  String tmOpenTitle(int count) {
    return 'На нём незакрытых этапов: $count';
  }

  @override
  String get tmHandTo => 'Кому передать';

  @override
  String get tmNobody => 'Никому — раздам потом';

  @override
  String get tmKeep => 'Оставить на нём';

  @override
  String get tmHandOver => 'Передать';

  @override
  String tmMoved(int count) {
    return 'Передано этапов: $count';
  }

  @override
  String tmLeftToPay(String sum) {
    return 'Ему осталось выплатить $sum';
  }

  @override
  String tmAdvanceOver(String sum) {
    return 'Аванс больше заработка на $sum';
  }

  @override
  String tmPending(String sum) {
    return 'Ещё ждёт подтверждения: $sum';
  }

  @override
  String tmPickTitle(String post) {
    return 'Кого поставить: $post';
  }

  @override
  String get tmNewPerson => 'Новый человек';

  @override
  String get tmNoOne => 'Никого не нашлось';

  @override
  String get tmDupTitle => 'Такой человек уже есть';

  @override
  String get tmDupHint =>
      'Если это он — не создавайте второго, просто дайте ему должность.';

  @override
  String get tmItsHim => 'Это он';

  @override
  String get tmItsOther => 'Нет, другой человек';

  @override
  String get tmLeftMark => 'ушёл';

  @override
  String get tmHistory => 'История';

  @override
  String get tmEvAdded => 'Принят в команду';

  @override
  String tmEvPostOn(String post) {
    return 'Дали «$post»';
  }

  @override
  String tmEvPostOff(String post) {
    return 'Сняли «$post»';
  }

  @override
  String get tmEvLeft => 'Уволен';

  @override
  String get tmEvBack => 'Вернули в команду';

  @override
  String get tmPosts => 'Должности';

  @override
  String get tmMenu => 'Ещё';

  @override
  String get tmEdit => 'Изменить';

  @override
  String get pplWorkTab => 'Работа';

  @override
  String get pplMoneyTab => 'Деньги';

  @override
  String get pplEarnedAll => 'Заработали';

  @override
  String get pplAdvanceAll => 'Взяли авансом';

  @override
  String get pplLeftAll => 'Осталось отдать';

  @override
  String get pplColWho => 'Кто';

  @override
  String get pplColEarned => 'Заработал';

  @override
  String get pplColAdvance => 'Аванс';

  @override
  String get pplColFine => 'Штраф';

  @override
  String get pplColGive => 'Отдать';

  @override
  String get pplGive => 'Отдать';

  @override
  String get pplGiven => 'Отдано';

  @override
  String get pplOwes => 'должен';

  @override
  String pplGiveConfirm(String name, String sum) {
    return 'Отдать $name $sum? Месяц у него закроется.';
  }

  @override
  String get pplGiveDone => 'Отмечено: отдано';

  @override
  String get pplPayLater =>
      'Отдать можно, когда месяц закончится. Сейчас — только авансом.';

  @override
  String get pplAddMoney => 'Аванс, штраф, премия';

  @override
  String get pplWaiting => 'Ждёт вашего «Да»';

  @override
  String pplWaitingBy(String who) {
    return 'внёс $who';
  }

  @override
  String get pplYes => 'Да';

  @override
  String get pplNo => 'Нет';

  @override
  String get pplWhyNo => 'Почему нет? Работник увидит.';

  @override
  String get pplExcel => 'Скопировать для Excel';

  @override
  String get pplCopied => 'Скопировано — вставьте в Excel';

  @override
  String get pplMoneyTitle => 'Аванс, штраф или премия';

  @override
  String get pplWho => 'Кому';

  @override
  String get pplHowMuch => 'Сколько, ₸';

  @override
  String get pplWhy => 'За что';

  @override
  String get pplRecord => 'Записать';

  @override
  String get pplFillAll => 'Заполните: кому, сколько и за что.';

  @override
  String get pplRecorded => 'Записано';

  @override
  String get pplRecordedWaiting => 'Записано — ждёт «Да» руководителя';

  @override
  String pplIntake(int count, String m2) {
    return 'Принял заказов: $count · $m2';
  }

  @override
  String pplSold(String metres, int count) {
    return 'Продал: $metres м · $count продаж';
  }

  @override
  String pplReceived(int count) {
    return 'Принял поставок: $count';
  }

  @override
  String get pplSalesBonus => 'Бонус продаж';

  @override
  String get pplCancelEntry => 'Отменить';

  @override
  String get pplCancelWhy => 'Почему отменяете? Работник увидит.';

  @override
  String get pplPeopleMoney => 'Деньги сотрудников';

  @override
  String get pplDepartmentsTab => 'Отделы';

  @override
  String get pplMoneyHidden => 'Деньги видят руководители и бухгалтерия.';

  @override
  String get shopTitle => 'Цех';

  @override
  String shopMonthLine(String month, String plan, String done) {
    return '$month: план $plan м² · сделано $done м²';
  }

  @override
  String get shopPlanDue => 'План — заказы со сроком в этом месяце';

  @override
  String get shopPlanTarget => 'План — ваша цель цеха на месяц';

  @override
  String get shopSetPlan => 'Изменить план';

  @override
  String get shopPlanDialog => 'План цеха на месяц, м²';

  @override
  String get shopPlanHint => 'Пусто — заказы со сроком в этом месяце';

  @override
  String get shopSave => 'Сохранить';

  @override
  String get shopClear => 'Без цели';

  @override
  String shopExpected(String m2) {
    return 'к сегодня должно быть $m2 м²';
  }

  @override
  String shopBehind(String m2) {
    return 'отстаём на $m2 м²';
  }

  @override
  String shopAhead(String m2) {
    return 'опережаем на $m2 м²';
  }

  @override
  String get shopForecast => 'Прогноз к концу месяца';

  @override
  String shopShort(String m2) {
    return 'не успеваем $m2 м²';
  }

  @override
  String get shopEnough => 'успеваем';

  @override
  String get shopInShop => 'В цехе сейчас';

  @override
  String shopOrders(int count) {
    return '$count заказов';
  }

  @override
  String get shopTaken => 'Принято за месяц';

  @override
  String shopOfSales(String m2) {
    return 'цель продаж $m2 м²';
  }

  @override
  String get shopWaiting => 'ждёт';

  @override
  String get shopToGive => 'к выдаче';

  @override
  String get shopToday => 'сегодня';

  @override
  String get shopMonthM2 => 'за месяц';

  @override
  String shopDays(String days) {
    return '≈ $days дн. работы';
  }

  @override
  String get shopJam => 'затор';

  @override
  String get shopNobody => 'никого';

  @override
  String shopInWork(int count) {
    return '$count в работе';
  }

  @override
  String get shopLate => 'Опаздывают';

  @override
  String get shopNoLate => 'Опаздывающих нет';

  @override
  String shopLateLine(String m2, String stage) {
    return '$m2 м² · стоит на шаге «$stage»';
  }

  @override
  String get shopOverdue => 'просрочен';

  @override
  String shopDue(String date) {
    return 'срок $date';
  }

  @override
  String get shopSide => 'Отдельно — не по ходу заказа';

  @override
  String shopSales(int count, String metres) {
    return 'сегодня $count продаж · $metres м';
  }

  @override
  String shopSalesMonth(String metres) {
    return 'за месяц $metres м';
  }

  @override
  String shopReceived(int count) {
    return 'поставок принято сегодня: $count';
  }

  @override
  String get shopTapStage => 'Нажмите на шаг — покажет его заказы';

  @override
  String get teamPostNobody => 'никого — этап заказов здесь встанет';

  @override
  String teamInWork(int count) {
    return '$count в работе';
  }

  @override
  String get teamNoLogin => 'без входа';
}
