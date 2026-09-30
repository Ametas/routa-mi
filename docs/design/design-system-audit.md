# Дизайн-система RoutaMi: аудит и план

Дата: 2026-09-28, база — `main` (`6d0df24`, SlClash v2.2.3). Цифры получены
grep/AST-подсчётом по `lib/` без `generated/` и `l10n/`, округлённо.
«Экраны» = `lib/views` + `lib/pages` + `lib/features` (65 файлов),
«виджеты» = `lib/widgets` (67 файлов).

## 1. Итог в одном абзаце

Дизайн-система **уже есть, но собрана наполовину**. SlClash в июле–сентябре
провёл «Surge»-ребрендинг: появились токены (`lib/widgets/surge/surge_tokens.dart`),
`ThemeExtension` `SurgeTheme`, набор Surge/SoftOS-компонентов, а типографика
доведена до конца и защищена AST-тестом. Остальные категории — отступы,
прозрачности, тени, размеры иконок, Material-темы компонентов — не
доведены: токенов либо нет, либо ими не пользуются, и ничто не мешает
добавлять новый хардкод. Параллельно живут компоненты FlClash (часть уже
перекрашена изнутри в Surge) и ~3 000 строк мёртвых виджетов. Собрать всё в
единую систему **можно**, и основную часть — без переписывания экранов.

## 2. Что уже хорошо

| Категория | Состояние | Чем обеспечено |
|---|---|---|
| Типографика | ✅ полностью: 0 `TextStyle(`/`fontSize:`/`fontWeight:` в экранах и виджетах | `SlclashTypeScale` → `buildSlclashTextTheme` → `SurgeTypography` (`context.typography`); AST-контракт `test/theme/typography/typography_source_contract_test.dart` |
| Цвета-роли | ✅ в основном: экраны берут `surge.*` / `colorScheme` | `SurgeColors` (19 ролей), 4 статических пресета `lib/theme/static_theme.dart` с тестом контраста WCAG (`test/theme/static_theme_test.dart`) |
| Радиусы | ✅ 45 токенов против 7 литералов в экранах | `SurgeRadii` (10 значений) |
| Анимации | ✅ 21 `SurgeMotion.*` против 5 литералов в экранах | `lib/widgets/surge/surge_motion.dart` |
| Иконки | ✅ только через `lib/common/icons.dart` | `test/widgets/surge_design_system_test.dart`, `test/common/surge_icons_test.dart` |
| Прямой Material в экранах | ✅ 0 `Card(`, `ListTile(`, `AlertDialog(`, `showDialog(`, `TabBar(` | обёртки в `lib/widgets` |

## 3. Где разбросано

### 3.1 Токены: чего нет или чем не пользуются

| Категория | Проблема | Масштаб |
|---|---|---|
| **Отступы** | `SurgeSpacing` — всего 5 значений (16/20/16/12/0.5); шкалы 4/8/12/16/24 нет | ≈420 литеральных `EdgeInsets`/`SizedBox` в экранах против 7 токенных; самые частые: 16 (103), 12 (54+42), 8 (41+44), 14 (43) |
| **Прозрачности** | `SurgeOpacity` (17 значений) в экранах не используется ни разу | 103 `withValues(alpha: 0.xx)` в экранах, 70 в виджетах; + устаревшие `.opacityNN` из FlClash (23), `withOpacity` (10) |
| **Тени** | `SurgeShadows` определён и **не используется нигде**; тени размазаны по `SurgeColors.shadow`, `SurgeControlSizes.actionShadow*`, `SurgeOpacity.actionShadow*` | 18 ручных `BoxShadow(` в 13 файлах |
| **Размеры иконок** | `SurgeControlSizes` в экранах использован 1 раз | 36 `Icon(size: N)`: 15/17/18/20/22/15.5… |
| **Material-темы компонентов** | в `ThemeData` (`lib/application.dart:169-212`) заданы только appBar/navigationBar/switch/radio/checkbox; card, listTile, dialog, bottomSheet, input, кнопки, chip, divider, popupMenu, snackBar, tooltip — по умолчанию Material и патчатся локально | `lib/widgets/theme.dart`, `media_check.dart:1218`, `profiles.dart:1217`, `features/overwrite/rule.dart:267` |
| **Семантические цвета** | `SurgeSemanticColors` — фиксированный hex, одинаковый для светлой/тёмной темы и всех пресетов; `SurgeColors.fromColorScheme` подмешивает свои hex | `surge_tokens.dart:39-56, 356-371` |

### 3.2 Конкурирующие источники

- Два потока построения темы в **противоположных направлениях**: в
  динамическом режиме `ColorScheme → SurgeColors`, в статическом
  `SurgeColors → ColorScheme` (`application.dart:46-76`).
- Хелперы FlClash рядом с Surge: `context.colorScheme` (58 обращений в
  19 файлах мимо Surge), `.opacityNN` в `lib/common/color.dart` — с
  ошибками именования: `opacity10` на деле 6 % (alpha 15), `opacity3` — 30 %.
- Дубли констант: `constant.dart` (`baseInfoEdgeInsets`, `listHeaderPadding`,
  4 длительности) против `SurgeSpacing`/`SurgeMotion`;
  `minimumTapExtent` = 44 в двух местах; enum пресетов продублирован в
  `lib/views/theme.dart:325`, логика выбора пресета — в трёх местах.
- `CommonTheme` (`lib/common/theme.dart`) создаётся, но не читается.

### 3.3 Компоненты: параллельные семейства

Старые виджеты FlClash в основном уже рисуются через Surge изнутри
(`ListItem` → `_SurgeListItemRow`, `SettingsBlock` → `SurgeCard`), так что
дубли — прежде всего в **API**, а не во внешнем виде.

| Задача | Живут параллельно | Кандидат в эталон |
|---|---|---|
| Карточка | ~~`CommonCard`~~ (удалён, PR #11) · `SurgeCard` (12) · `SurgeActionCard` (10) · `SurgeListSurface` · локальные `SurgeDashboardCard` и приватные карточки в profiles/dashboard | `SurgeCard` / `SurgeActionCard` |
| Строка | `ListItem` + делегаты (15 экранов, 88 вызовов) · `SurgeListTile` · `SurgeSettingOption` · `SurgeSelectableRow` · `DecorationListItem` — с PR #13 все рисуются через `SurgeRow` | `SurgeRow` / `SurgeListTile` + `SurgeSelectableRow` |
| Секция | ~~`generateSection`/`V2`~~, ~~`SurgeSettingSection`~~ (PR #12) · `generateSectionV3` · `SurgeSection` + `SurgeSectionList` · 3 локальные `_…Section` | `SurgeSection` |
| Переключатель вкладок | `CommonTabBar` (мёртв) · `SurgeSegmentedControl` · `SurgeSlidingSegmentedControl` · `SurgeDualSelectBar` · `SoftOsSelectPill` | `SurgeSegmentedControl` |
| Нажатие | `SurgePressable` · `EffectGestureDetector` (1) · `InkWell` (9) / `Material` (11) в экранах | `SurgePressable` |
| Диалоги | `CommonDialog` (с PR #20 — слот `actions` из `SurgeDialogActionButton`) · ~~`CommonModal`~~ · `_SoftOsBackupDialog` (обёртка над `CommonDialog`) · `SurgeDialogActionRow` внутри содержимого | `CommonDialog(actions:)` + `SurgeDialogActionButton` |
| Кнопки app bar | `SlAppBar*Button` · `SoftOsActionButton/Dock` · `SoftOsIconButton` · ~~`SoftOsControlDock`~~ (с PR #14 — `SoftOsActionDock(style: inset)`) | модель `SlAppBarAction` + один док |
| Плашки/бейджи | `SoftOsStatusPill` · `SurgeMetricBadge` · `SurgeDelayPill` · ~~`CommonChip`~~ · ~~5+ локальных `_…Pill`~~ (PR #18–#19) | `SurgeTag` (метки) / `SoftOsStatusPill` (кнопки-капсулы) |
| Экран | `CommonScaffold` (25) · `AdaptiveSheetScaffold` (14) · голый `Scaffold` в `pages/error.dart`, `scan.dart`, `editor.dart` | `CommonScaffold` / `AdaptiveSheetScaffold` |

Коллизия имён: `lib/views/proxies/list.dart:494` объявляет свой `ListHeader`,
затеняя `lib/widgets/list.dart:644`.

### 3.4 Мёртвый код (проверено: 0 использований вне своего файла)

`CommonTabBar` (`tab.dart`, 1114 строк), `SuperGrid` + `Grid` (`super_grid.dart`
698 + `grid.dart` 407), весь `button.dart`, `FloatLayout`, `CommonSafeArea`,
`TooltipTextV2`, `SettingsBlock`/`SettingInfoCard`/`SettingTextCard`,
`CommonModal`, `SurgeFeatureCard`, `SurgeDataListItem`, `generateInfoSection`,
`SoftOsActionDivider`, `SoftOsPopupActionButton`, `FadeScaleBox`,
`CommonPopupRoute`, `SurgeShadows` и др. — ≈3 000 строк. В экране темы
выбор основного цвета (`_PrimaryColorItem`, `ColorSchemeBox`, `Palette`,
`lib/views/theme.dart:464-930`) написан, но не выводится.

### 3.5 Горячие точки экранов

| Файл | Хардкод (цвет+отступы+тени) | Локальные компоненты |
|---|---|---|
| `views/profiles/profiles.dart` (2395 строк) | 95 | ~12 приватных карточек/плашек/кнопок |
| `views/dashboard/widgets/surge_dashboard_hero.dart` | 68 (+32 масштабируемых литерала) | `_HeroModeCard`, `_StatusPill`, `_NodeCard`, свой `showModalBottomSheet` |
| `views/profiles/media_check.dart` | 59 | локальная тема кнопок |
| `views/theme.dart` | 38 | `ItemCard`, `EffectGestureDetector`, 3 `FilledButton` |
| `views/resources.dart`, `views/backup_and_restore.dart` | 35 / 33 | локальные диалоги |
| `pages/error.dart`, `pages/scan.dart`, `pages/editor.dart` | 15 каждый | голый `Scaffold`/`AppBar`, `Colors.black12`, `Colors.orange` |

Хорошие образцы: `lib/pages/home.dart`, `lib/views/tools.dart`,
`lib/views/dashboard/widgets/network_detection.dart`.

## 4. Перенос из апстрима: интерфейс не переносим

Решение владельца (2026-09-28): из SlClash переносятся только
функциональные изменения; интерфейсные коммиты пропускаются, у RoutaMi
свой вектор дизайна. Поэтому экраны и виджеты меняем свободно, без оглядки
на конфликты `cherry-pick`. Ограничение «минимум правок в крупных файлах
апстрима» (`CLAUDE.md`, правило 1) остаётся для функциональной логики:
провайдеры, `state.dart`, модели, ядро.

Для справки: SlClash после ребрендинга и так затихает — коммитов,
затрагивающих UI: 150 в июле, 34 в августе, 12 в сентябре; с 12 сентября
новых коммитов нет.

## 5. План

**Этап 0 — уборка без изменения внешнего вида.**
- Удалить мёртвые виджеты (§3.4), `CommonTheme`, неиспользуемый выбор
  основного цвета (или вернуть его в UI — решить отдельно).
- Убрать дубль enum пресетов и тройную логику выбора пресета.

**Этап 1 — дополнить токены.**
- Шкала отступов `space4/8/12/16/20/24/32` (покроет ≈75 % литералов).
- Именованные уровни прозрачности (`subtle/muted/…` вместо 0.08/0.72/0.78…).
- Размеры иконок `iconS/M/L` (15/17/18/20 → 2–3 значения — потребует
  решения по визуалу).
- Подключить `SurgeShadows` как единственный источник теней.

**Этап 2 — Material-темы от Surge** (новый `lib/theme/component_themes.dart`,
одна строка в `application.dart`): card, listTile, dialog, bottomSheet,
inputDecoration, кнопки, chip, divider, popupMenu, snackBar, tooltip.
Оставшиеся голые Material-виджеты станут выглядеть единообразно без правки
экранов.

**Этап 3 — «храповик» вместо большой переделки.** Контракт-тест по образцу
типографического для цветов (`Color(0x`, `Colors.*`, литеральный `alpha:`),
отступов, радиусов, теней, длительностей и размеров иконок. Текущее
количество нарушений фиксируется по файлам как базовая линия: новое
нарушение — тест красный, уменьшение — базовая линия обновляется. Хардкод
перестаёт расти, а экраны не нужно переписывать разом.

**Этап 4 — эталонный набор компонентов.**
- `ListItem` оставить как тонкий адаптер над `SurgeListTile` (API
  экранов не меняется), затем постепенно вытеснить.
- Объединить два дока кнопок app bar; локальные плашки → `SoftOsStatusPill`;
  локальные диалоги → `CommonDialog` + `SurgeDialogActionRow`.
- Тесты на эталонные компоненты, которые сейчас без тестов (`ListItem`,
  `SurgeSection`, `SurgeListTile`, `SurgeActionCard`, `SurgeSegmentedControl`,
  `SoftOsActionDock`, поля ввода).
- Витрина компонентов: debug-экран или golden-тесты со всеми эталонными
  компонентами в светлой/тёмной теме и при 100/130/200 % шрифта — это и
  есть «шаблон», по которому собираются новые экраны.

**Этап 5 — экраны.** Переводить на токены и эталонные компоненты по
одному экрану за PR; тяжёлые (`profiles`, `dashboard_hero`, `media_check`)
— отдельными PR.

## 6. Решения владельца (2026-09-28)

1. **Выбор акцентного цвета** — вернуть в интерфейс, оставить возможность
   выбора и значение по умолчанию. Собственный дизайн RoutaMi — после
   перевода на дизайн-систему.
2. **Масштабирование** — свести к единому механизму вместо нескольких
   разрозненных, если это не вредит интерфейсу.
3. **Спорные размеры отступов и иконок** — сводить к шкале.
4. **`opacity10`** — исправить значение.

Шкала прозрачности: `0 · .04 · .08 · .12 · .16 · .24 · .38 · .48 · .62 ·
.72 · .82 · .92 · 1` (шаги Material 3 для состояний и «disabled» плюс
частые значения экранов). Уровни теней: `ambient` (плотность темы),
`hairline`, `raised`, `knob`, `card`, `bar`, `floating`, `action`, цветные `glow`
и `halo`. `withValues(alpha:)` задаёт плотность абсолютно, поэтому у
уровней она фиксирована, а от темы берётся оттенок.

Длительности: шкала — шаги Material 3 (`SurgeDuration`, 50…1000 мс, как
Flutter `Durations`). Роли `SurgeMotion` (`press`, `state`, `reveal`,
`container`, `fade`, `contentSwap`, `menu`, `chart`, страницы и шторки)
указывают на шаги; прежние 110/160/180/220/280/210/112 мс сведены к
100/150/200/200/300/200/100. Циклы (`heroFill`, `heroSheen`,
`latencyFlow`, `loadingSpin`, `loadingDots`) — периоды, вне шкалы.
Храповик считает только длительности в позициях анимации
(`duration:`, `transitionDuration` …); таймеры, таймауты и дебаунс логики
токенами не являются.

Порядок: сначала уборка (этап 0) вместе с решениями 1 и 4, затем токены и
шкала (этапы 1–3, решения 2 и 3), затем компоненты и экраны.

## 7. Статус

| Этап | Состояние |
|---|---|
| 0. Уборка | ✅ PR #3: мёртвые виджеты удалены, `AppColorSource`, выбор акцента, `opacity10` |
| 1. Токены | ✅ PR #4: `SurgeSpace`, `SurgeIconSize` (+`snap`), единый `UiScale`; PR #6: шкала прозрачности `SurgeAlpha` (+`snap`), уровни теней `SurgeShadows` (`lib/widgets/surge/surge_shadows.dart`); PR #7: шкала длительностей `SurgeDuration` (шаги Material 3, +`snap`), роли `SurgeMotion` сведены к ней |
| 2. Material-темы от Surge | ✅ PR #8: `lib/theme/surge_theme_data.dart` (`buildSurgeThemeData`, `SurgeComponentThemes`) — app bar, навигация, переключатели, radio, checkbox, разделители, диалоги, шторки, прогресс, снекбары, выделение текста; `application.dart` и скриншоты строят тему через него. Поля ввода намеренно не темизируются (голые `TextField` — плоские поля app bar и редактора), оформленные идут через `surgeInputDecoration` |
| 3. «Храповик» | ✅ PR #4: `test/design/design_token_ratchet_test.dart` |
| 4. Эталонные компоненты | ◐ PR #10: каталог `test/support/component_catalog.dart` (21 эталон в типичных состояниях) и контракт `test/design/component_catalog_test.dart` — каждый без переполнения на 320 dp в светлой/тёмной теме при шрифте 100/130/200 %; витрина PNG `test/tools/component_catalog_shots_test.dart`; тесты `SurgeListTile`, `SoftOsStatusPill`, `SurgeActionCard`, `SurgeSection`, `SurgeSegmentedControl`; исправлено: `SurgeListTile` центрирует содержимое по вертикали, `SoftOsStatusPill` не растягивается на всю ширину; локальный `ListHeader` прокси → `ProxyGroupHeader`. PR #11: `CommonCard` удалён — плашка клавиши хоткея и переключатели параметров правила на `SurgeActionCard`. PR #12: `generateSection`/`generateSectionV2`/`SurgeSettingSection` удалены — «Сеть», DNS, быстрые настройки, разработчик и шторка доступа на `SurgeSection`, страницы из секций — `SurgeSectionList` (заголовок над карточкой, без двойных разделителей); `generateSectionV3` остаётся — строки с оформлением по позиции (`ItemPositionProvider`) в редакторах групп и правил. PR #13: одна разметка строки `SurgeRow` (бывший приватный `_SurgeListItemRow`) — `ListItem`, `DecorationListItem` и `SurgeListTile` стали обёртками над ней со своими метриками; подзаголовки `SurgeListTile` теперь во вторичном цвете, как у остальных строк. Новые строки — `SurgeListTile` (строковый API) или `SurgeRow`; делегаты `ListItem` остаются адаптером для 88 вызовов. PR #14: один док — `SoftOsActionDock` со стилем `raised` (шапка) или `inset` (внутри карточек); `SoftOsControlDock` и `SoftOsDockButton` удалены, кнопки внутренних доков нажимаются через `SurgePressable` вместо ряби `InkWell`. PR #15: профили — новый эталон `SurgeIconTile` (иконка на тонированной плитке; заменил `_SoftOsIconSurface` и плитку редактора скрипта), шторка управления профилями на `SurgeSection` (+ `subtitle`) и `SurgeListTile`, удалены `_ProfileSettingSection`/`_ProfileSettingOption`/`_ProfileSortOption`. PR #16: меню действий профиля — общий `CommonPopupMenu` вместо `_ProfileActionMenu`/`_ProfileActionMenuItem`, а стиль старого меню профиля перенесён в `CommonPopupMenu` для всех меню (иконки на круглых `SurgeIconTile`, компактные строки без разделителей, опасный пункт — красная плитка и текст, карточка `SurgeCard`); прозрачности плашки типа профиля на шкале. PR #17: строки «Медиа-проверка» и «Показать узлы профиля» на `SurgeRow` (попиксельно без изменений), удалён неиспользуемый `ReorderableProfilesSheet`; скрипт скриншотов снимает экран профилей с активным профилем. PR #18: эталон метки `SurgeTag` (нейтральная или акцентная капсула; размеры `regular` — высота статус-пилюли, `compact` — по тексту) и её палитра `SurgeTagColors` — на них плашка типа профиля, счётчик групп в редакторе переопределений, «Выбрано N» в доступе, цепочки соединения (список и подробности; `CommonChip` там больше не нужен) и цвета `SurgeDelayPill`; удалены `_ProfilePill`, `OverwriteCountPill`, `_SelectedPill`, `_TrackerChainPill`. Акцент единый в обеих темах (фон `a12`, обводка `a24`): задержки стали чуть заметнее, «Выбрано N» в тёмной теме чуть тише. Текст в метке фиксированной высоты и в плашке задержки растёт вместе с капсулой (`UiScale.moderatedText`) — при 200 % «Timeout» больше не обрезается. PR #19: `SurgeTag(onRemove:)` — метка с крестиком для ключевых слов поиска в `CommonScaffold` (нажатие по метке удаляет слово); последний Material-чип `CommonChip` и `ChipType` удалены. PR #20: диалоги, часть 1 — у `CommonDialog` слот `actions` (кнопки `SurgeDialogActionButton` одной строкой под содержимым, вне прокрутки; Material-панель действий больше не используется); одна кнопка диалога `SurgeDialogActionButton` (+ `destructive`) вместо неё и `_SoftOsDialogAction` бэкапа; на слот переведены сообщение `showMessage`, список обновлений, согласие с условиями, запись хоткея, диалоги бэкапа и журнал изменений; текст сообщения — `typography.body`; скрипт скриншотов снимает диалоги. Осталось: строки `SurgeDialogActionRow` внутри содержимого (11 диалогов) → `actions`, переключатели вкладок, кнопки app bar, нажатия/экраны без `CommonScaffold` → эталоны |
| 5. Экраны | ◐ PR #5: отступы, промежутки и размеры иконок во всех экранах и виджетах сведены к шкале; PR #6: литеральные прозрачности (включая тернарии и `withOpacity`) сведены к `SurgeAlpha`, хелперы `.opacityNN` из FlClash удалены, все `BoxShadow` — через `SurgeShadows`; PR #7: длительности анимаций, переходов и снекбаров — через `SurgeMotion`/`SurgeDuration`; PR #9: цвета — статусы на `surge.green/orange/red` (`surge.latencyColor`), акцент по умолчанию — `defaultAccentColor(Dark)`, цвета вне темы — роли `SurgePalette` (`onFill`, `scrim`, `highlight`, `routeEdgeShadow`, `shade`, `contentOn`); литералы остались только в математике цвета (`lib/common/color.dart`, `palette.dart`, маска `scrolling_label`); остаются масштабируемые значения дашборда (`layout.geometry`) |

Витрина эталонов (PNG на тему и масштаб шрифта):
`SHOT_DIR=/tmp/catalog flutter test test/tools/component_catalog_shots_test.dart`.
Новый эталонный компонент добавляйте в `componentCatalog` — контракт
проверит его автоматически.

Снимки экранов для сравнения «до/после»:
`SHOT_DIR=/tmp/shots flutter test test/tools/screenshots_test.dart`.

