/// theme_builder_screen.dart — конструктор тем (View, § 10.2).
///
/// За что отвечает файл:
///   Премиум-инструмент создания своей темы: выбор базового пресета, имени и
///   палитры (фон/градиент/панель/текст/цвета игроков/акцент) с ЖИВЫМ превью
///   (мини-доска + карточка + кнопка перерисовываются на лету). Сохранение
///   кладёт тему в [CustomThemesController] и сразу надевает её. Доступ — после
///   разблокировки за кристаллы (гейт на экране настроек/переключателе тем).
///   Чистый View: правки идут в черновик-модель, команды — в ViewModel.
///
/// Соответствие ROADMAP: § 10.2 (конструктор тем; маркетплейс/синк — 🔒).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_tokens.dart';
import '../theme/custom_theme.dart';
import '../theme/custom_themes_controller.dart';
import '../widgets/screen_scaffold.dart';

/// Палитра свотчей для выбора цвета поля.
const List<Color> _swatches = [
  Color(0xFF0E1116), Color(0xFF070A12), Color(0xFF1A1030), Color(0xFF112022),
  Color(0xFF161B22), Color(0xFF0E1422), Color(0xFFFFEAF6), Color(0xFFF4E6FF),
  Color(0xFFE7EDF3), Color(0xFFEAF0FF), Color(0xFF4A235A), Color(0xFFFFFFFF),
  Color(0xFFFF9D42), Color(0xFFFFD23F), Color(0xFFFF4D97), Color(0xFFEF5350),
  Color(0xFF36D6E7), Color(0xFF3AA6FF), Color(0xFF42A5F5), Color(0xFF2BBDB8),
  Color(0xFF37D67A), Color(0xFF66BB6A), Color(0xFFAB47BC), Color(0xFFFFCA28),
];

/// Редактируемые поля палитры.
enum _Field { bg, bg2, panel, ink, p0, p1, good }

/// Экран конструктора тем.
class ThemeBuilderScreen extends ConsumerStatefulWidget {
  /// Создаёт экран.
  const ThemeBuilderScreen({super.key});

  @override
  ConsumerState<ThemeBuilderScreen> createState() => _ThemeBuilderScreenState();
}

class _ThemeBuilderScreenState extends ConsumerState<ThemeBuilderScreen> {
  late CustomTheme _draft;
  late bool _isNew;
  _Field _selected = _Field.p0;

  @override
  void initState() {
    super.initState();
    final equipped = ref.read(customThemesControllerProvider).equipped;
    if (equipped != null) {
      _draft = equipped;
      _isNew = false;
    } else {
      final id = ref.read(customThemesControllerProvider.notifier).nextId();
      _draft = CustomTheme.fromBase(id, 'Моя тема', ThemeId.neutral);
      _isNew = true;
    }
  }

  int _fieldValue(_Field f) => switch (f) {
    _Field.bg => _draft.bg,
    _Field.bg2 => _draft.bg2,
    _Field.panel => _draft.panel,
    _Field.ink => _draft.ink,
    _Field.p0 => _draft.p0,
    _Field.p1 => _draft.p1,
    _Field.good => _draft.good,
  };

  void _setField(_Field f, int argb) {
    setState(() {
      _draft = switch (f) {
        _Field.bg => _draft.copyWith(bg: argb),
        _Field.bg2 => _draft.copyWith(bg2: argb),
        _Field.panel => _draft.copyWith(panel: argb),
        _Field.ink => _draft.copyWith(ink: argb),
        _Field.p0 => _draft.copyWith(p0: argb),
        _Field.p1 => _draft.copyWith(p1: argb),
        _Field.good => _draft.copyWith(good: argb),
      };
    });
  }

  static const Map<_Field, String> _labels = {
    _Field.bg: 'Фон',
    _Field.bg2: 'Градиент',
    _Field.panel: 'Панель',
    _Field.ink: 'Текст',
    _Field.p0: 'Игрок 1',
    _Field.p1: 'Игрок 2',
    _Field.good: 'Акцент',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final preview = _draft.toTokens();

    return ScreenScaffold(
      title: 'Конструктор тем',
      theme: theme,
      onBack: () => context.go('/settings'),
      children: [
        // Живое превью.
        _Preview(tokens: preview),
        const SizedBox(height: 16),
        // Имя.
        TextFormField(
          initialValue: _draft.label,
          onChanged: (v) => setState(
            () => _draft = _draft.copyWith(label: v.isEmpty ? 'Моя тема' : v),
          ),
          style: TextStyle(color: theme.ink),
          decoration: InputDecoration(
            labelText: 'Название темы',
            labelStyle: TextStyle(color: theme.muted),
            filled: true,
            fillColor: theme.panel,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              borderSide: BorderSide(color: theme.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.btnRadius),
              borderSide: BorderSide(color: theme.p0, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Базовый пресет (шрифты/радиусы).
        Text('Основа (шрифт и форма)',
            style: TextStyle(color: theme.muted, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final id in themeOrder)
              ChoiceChip(
                label: Text(blockDuelThemes[id]!.label),
                selected: _draft.base == id,
                onSelected: (_) =>
                    setState(() => _draft = _draft.copyWith(base: id)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // Выбор редактируемого поля.
        Text('Цвета', style: TextStyle(color: theme.muted, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _Field.values)
              _FieldChip(
                theme: theme,
                label: _labels[f]!,
                color: Color(_fieldValue(f)),
                selected: _selected == f,
                onTap: () => setState(() => _selected = f),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Палитра свотчей для выбранного поля.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _swatches)
              _Swatch(
                color: c,
                selected: _fieldValue(_selected) == c.toARGB32(),
                line: theme.line,
                onTap: () => _setField(_selected, c.toARGB32()),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            ref.read(customThemesControllerProvider.notifier).save(_draft);
            context.go('/settings');
          },
          icon: const Icon(Icons.check),
          label: const Text('Сохранить и надеть'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.p0,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (!_isNew) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(customThemesControllerProvider.notifier).delete(_draft.id);
              context.go('/settings');
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить тему'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.bad,
              side: BorderSide(color: theme.line),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }
}

/// Живое превью темы: фон-градиент, панель-карточка, мини-доска, кнопка.
class _Preview extends StatelessWidget {
  final BlockDuelTheme tokens;

  const _Preview({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.bg, tokens.bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          // Мини-доска 3×3.
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.bg2,
              borderRadius: BorderRadius.circular(tokens.boardRadius * 0.5),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in const [
                  [1, 0, 2],
                  [0, 3, 0],
                  [2, 0, 1],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final v in row)
                        Container(
                          margin: const EdgeInsets.all(2),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: switch (v) {
                              1 => tokens.p0,
                              2 => tokens.p1,
                              3 => tokens.good,
                              _ => tokens.cell,
                            },
                            borderRadius:
                                BorderRadius.circular(tokens.cellRadius),
                            border: v == 0
                                ? Border.all(color: tokens.cellLine)
                                : null,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tokens.label,
                  style: TextStyle(
                    color: tokens.ink,
                    fontWeight: FontWeight.w800,
                    fontFamily: tokens.fontDisplay,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text('превью темы',
                    style: TextStyle(color: tokens.muted, fontSize: 12)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.p0,
                    borderRadius: BorderRadius.circular(tokens.btnRadius),
                  ),
                  child: const Text('Кнопка',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Чип выбора редактируемого поля (имя + текущий цвет).
class _FieldChip extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FieldChip({
    required this.theme,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: Border.all(
            color: selected ? theme.p0 : theme.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.line),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: theme.ink, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Свотч палитры.
class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final Color line;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.line,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white : line,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
