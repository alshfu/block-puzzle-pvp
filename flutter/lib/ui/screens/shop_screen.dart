/// shop_screen.dart — магазин: power-ups и скины (View).
///
/// За что отвечает файл:
///   `/shop`. Две вкладки: power-ups (за 💎 кристаллы) и скины клеток (за 🪙
///   монеты). Показывает кошелёк, цены, владение; покупка/надевание — команды в
///   [InventoryController]/[SkinsController]. Чистый View по MVVM.
///
/// Соответствие TS: `screens/ShopScreen.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/profile_controller.dart';
import '../../shop/inventory_controller.dart';
import '../../shop/powerups.dart';
import '../../shop/skins.dart';
import '../../shop/skins_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Экран магазина.
class ShopScreen extends ConsumerStatefulWidget {
  /// Создаёт экран магазина.
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _powerupsTab = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BlockDuelTheme>()!;
    final profile = ref.watch(profileControllerProvider);

    return ScreenScaffold(
      title: 'Магазин',
      theme: t,
      onBack: () => context.go('/'),
      children: [
        // Кошелёк.
        Row(
          children: [
            _Wallet(theme: t, label: '🪙 ${profile.coins}'),
            const SizedBox(width: 8),
            _Wallet(theme: t, label: '💎 ${profile.crystals}'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '1 кристалл за каждые 150 очков в партии',
          style: TextStyle(color: t.muted, fontSize: 11),
        ),
        const SizedBox(height: 14),
        // Табы.
        Row(
          children: [
            _Tab(
              theme: t,
              label: '💎 Power-ups',
              active: _powerupsTab,
              onTap: () => setState(() => _powerupsTab = true),
            ),
            const SizedBox(width: 8),
            _Tab(
              theme: t,
              label: '🪙 Скины',
              active: !_powerupsTab,
              onTap: () => setState(() => _powerupsTab = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_powerupsTab) ..._powerupsList(t) else ..._skinsList(t),
      ],
    );
  }

  List<Widget> _powerupsList(BlockDuelTheme t) {
    final inv = ref.watch(inventoryControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    return [
      for (final p in powerupDefs)
        _ShopCard(
          theme: t,
          icon: p.icon,
          ownedLabel: (inv[p.id] ?? 0) > 0 ? '×${inv[p.id]}' : null,
          title: p.name,
          description: '${p.description}\n${p.hint}',
          action: _BuyButton(
            theme: t,
            label: '💎 ${p.price}',
            enabled: profile.crystals >= p.price,
            onTap: () =>
                ref.read(inventoryControllerProvider.notifier).buy(p.id),
          ),
        ),
    ];
  }

  List<Widget> _skinsList(BlockDuelTheme t) {
    final skins = ref.watch(skinsControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final notifier = ref.read(skinsControllerProvider.notifier);
    return [
      for (final s in skinDefs)
        _ShopCard(
          theme: t,
          icon: s.icon,
          ownedLabel: s.id == skins.equipped ? 'надет' : null,
          title: s.name,
          description: s.description,
          action: _skinAction(t, s, skins, profile.coins, notifier),
        ),
    ];
  }

  Widget _skinAction(
    BlockDuelTheme t,
    SkinDef s,
    PlayerSkins skins,
    int coins,
    SkinsController notifier,
  ) {
    if (s.id == skins.equipped) {
      return Text(
        'в использовании',
        style: TextStyle(color: t.good, fontSize: 12),
      );
    }
    if (skins.unlocked.contains(s.id)) {
      return _BuyButton(
        theme: t,
        label: 'Применить',
        enabled: true,
        onTap: () => notifier.equip(s.id),
      );
    }
    return _BuyButton(
      theme: t,
      label: '🪙 ${s.price}',
      enabled: coins >= s.price,
      onTap: () => notifier.buy(s.id),
    );
  }
}

/// Чип кошелька.
class _Wallet extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  const _Wallet({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: theme.panel,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      border: Border.all(color: theme.line),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: theme.ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: theme.fontMono,
      ),
    ),
  );
}

/// Таб магазина.
class _Tab extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.theme,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: active ? theme.p0 : theme.panel,
      borderRadius: BorderRadius.circular(theme.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.btnRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.btnRadius),
            border: active ? null : Border.all(color: theme.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? theme.bg : theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Карточка товара магазина.
class _ShopCard extends StatelessWidget {
  final BlockDuelTheme theme;
  final String icon;
  final String? ownedLabel;
  final String title;
  final String description;
  final Widget action;

  const _ShopCard({
    required this.theme,
    required this.icon,
    required this.ownedLabel,
    required this.title,
    required this.description,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              if (ownedLabel != null)
                Text(
                  ownedLabel!,
                  style: TextStyle(
                    color: theme.p0,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(color: theme.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}

/// Кнопка покупки/действия.
class _BuyButton extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _BuyButton({
    required this.theme,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: enabled ? theme.p0 : theme.panel2,
    borderRadius: BorderRadius.circular(theme.btnRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? theme.bg : theme.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
