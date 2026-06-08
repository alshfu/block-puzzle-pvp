/// setup_screen.dart — настройка матча перед стартом (View).
///
/// За что отвечает файл:
///   `/setup/:mode`. Перед партией даёт выбрать уровень бота (для режимов с
///   ботом), правила (повороты/отражения/размер руки) и блиц-таймер
///   (хардкор/норма/казуал). По кнопке «Начать» уходит в `/game/:mode`, кодируя
///   выбор в query-параметры (как resume/seed). Чистый View: локальное
///   состояние выбора держит сам, игровой логики нет.
///
/// Кодирование/декодирование конфига сосредоточено здесь ([gameRoute],
/// [botLevelFromParams], [ruleConfigFromParams]) — роутер декодирует тем же
/// кодом.
///
/// Соответствие TS: `screens/SetupScreen.tsx`.
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../settings/settings_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Пресеты блица: (turnTimeStart, turnTimeMin) в секундах.
const Map<String, (double, double)> _blitzPresets = {
  'hardcore': (8, 2),
  'normal': (12, 3),
  'casual': (20, 6),
};

/// Строит путь `/game/:mode` с закодированным конфигом матча.
String gameRoute({
  required String mode,
  required BotLevel bot,
  required bool rotation,
  required bool flip,
  required int handSize,
  required bool blitz,
  required String blitzPreset,
}) =>
    '/game/$mode?bot=${bot.name}&rot=${rotation ? 1 : 0}'
    '&flip=${flip ? 1 : 0}&hand=$handSize&blitz=${blitz ? 1 : 0}'
    '&bp=$blitzPreset';

/// Уровень бота из query-параметров (дефолт — medium).
BotLevel botLevelFromParams(Map<String, String> q) =>
    BotLevel.values.where((l) => l.name == q['bot']).firstOrNull ??
    BotLevel.medium;

/// Правила из query-параметров поверх [defaultConfig] (null, если их нет —
/// тогда зовущий берёт дефолт).
RuleConfig? ruleConfigFromParams(Map<String, String> q) {
  if (!q.containsKey('rot') && !q.containsKey('blitz')) return null;
  final preset = _blitzPresets[q['bp']] ?? _blitzPresets['normal']!;
  final blitz = q['blitz'] != '0';
  return defaultConfig.copyWith(
    rotationEnabled: q['rot'] != '0',
    flipEnabled: q['flip'] != '0',
    handSize: int.tryParse(q['hand'] ?? '') ?? defaultConfig.handSize,
    turnTimerEnabled: blitz,
    turnTimeStart: preset.$1,
    turnTimeMin: preset.$2,
  );
}

/// Экран настройки матча.
class SetupScreen extends ConsumerStatefulWidget {
  /// Код режима из маршрута (`bot`/`hotseat`/`botvbot`).
  final String modeRaw;

  /// Создаёт экран настройки.
  const SetupScreen({super.key, required this.modeRaw});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late BotLevel _bot;
  late bool _rotation;
  late bool _flip;
  late int _handSize;
  late bool _blitz;
  late String _blitzPreset;

  @override
  void initState() {
    super.initState();
    // Стартовые значения — из настроек «Матч по умолчанию».
    final s = ref.read(settingsControllerProvider);
    _bot =
        BotLevel.values.where((l) => l.name == s.defaultBotLevel).firstOrNull ??
        BotLevel.medium;
    _rotation = s.defaultRotation;
    _flip = s.defaultFlip;
    _handSize = s.defaultHandSize;
    _blitz = s.defaultBlitz;
    _blitzPreset = s.defaultBlitzPreset;
  }

  bool get _hasBot => widget.modeRaw == 'bot' || widget.modeRaw == 'botvbot';

  void _start() {
    context.go(
      gameRoute(
        mode: widget.modeRaw,
        bot: _bot,
        rotation: _rotation,
        flip: _flip,
        handSize: _handSize,
        blitz: _blitz,
        blitzPreset: _blitzPreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BlockDuelTheme>()!;
    return ScreenScaffold(
      title: 'Настройка матча',
      theme: t,
      onBack: () => context.go('/'),
      children: [
        if (_hasBot) ...[
          _Label(t, 'Сложность бота'),
          _Segment<BotLevel>(
            tokens: t,
            value: _bot,
            options: const {
              BotLevel.easy: 'Тупой',
              BotLevel.medium: 'Умный',
              BotLevel.hard: 'Сложный',
            },
            onChanged: (v) => setState(() => _bot = v),
          ),
          const SizedBox(height: 18),
        ],
        _Label(t, 'Правила'),
        _Toggle(
          tokens: t,
          label: 'Повороты',
          value: _rotation,
          onChanged: (v) => setState(() => _rotation = v),
        ),
        _Toggle(
          tokens: t,
          label: 'Отражения',
          value: _flip,
          onChanged: (v) => setState(() => _flip = v),
        ),
        const SizedBox(height: 10),
        _Segment<int>(
          tokens: t,
          value: _handSize,
          options: const {1: 'Рука 1', 2: 'Рука 2', 3: 'Рука 3'},
          onChanged: (v) => setState(() => _handSize = v),
        ),
        const SizedBox(height: 18),
        _Label(t, 'Таймер'),
        _Toggle(
          tokens: t,
          label: _blitz ? 'Блиц включён' : 'Без таймера',
          value: _blitz,
          onChanged: (v) => setState(() => _blitz = v),
        ),
        if (_blitz) ...[
          const SizedBox(height: 10),
          _Segment<String>(
            tokens: t,
            value: _blitzPreset,
            options: const {
              'hardcore': 'Хардкор',
              'normal': 'Норма',
              'casual': 'Казуал',
            },
            onChanged: (v) => setState(() => _blitzPreset = v),
          ),
        ],
        const SizedBox(height: 28),
        _StartButton(tokens: t, onTap: _start),
      ],
    );
  }
}

/// Заголовок секции.
class _Label extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String text;
  const _Label(this.tokens, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: tokens.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Строка-тумблер.
class _Toggle extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.tokens,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: tokens.ink, fontSize: 14)),
        ),
        Switch(value: value, onChanged: onChanged, activeTrackColor: tokens.p0),
      ],
    ),
  );
}

/// Сегментированный переключатель из вариантов [options].
class _Segment<T> extends StatelessWidget {
  final BlockDuelTheme tokens;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _Segment({
    required this.tokens,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == value
                          ? tokens.p0
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(tokens.btnRadius - 3),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: entry.key == value ? tokens.bg : tokens.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Кнопка «Начать».
class _StartButton extends StatelessWidget {
  final BlockDuelTheme tokens;
  final VoidCallback onTap;

  const _StartButton({required this.tokens, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: tokens.p0,
      borderRadius: BorderRadius.circular(tokens.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            'Начать →',
            style: TextStyle(
              color: tokens.bg,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}
