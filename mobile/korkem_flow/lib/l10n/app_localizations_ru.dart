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
}
