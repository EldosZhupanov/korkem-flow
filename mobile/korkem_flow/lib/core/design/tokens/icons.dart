import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Semantic icon vocabulary.
///
/// Screens name *what a thing is*, never which glyph draws it — so changing an
/// icon is one edit here rather than a grep across the codebase.
///
/// Material Symbols **Rounded** throughout: it is Material 3's native icon set,
/// its rounded terminals match the 12dp corner language, and its variable
/// `fill` axis gives filled-when-selected from a single family. One icon set
/// only — mixing families is the most visible way an interface reads as
/// assembled rather than designed.
abstract final class AppIcons {
  // ── Domain entities ──────────────────────────────────────────────────────
  static const IconData deal = Symbols.handshake_rounded;
  static const IconData lead = Symbols.person_search_rounded;
  static const IconData customer = Symbols.apartment_rounded;
  static const IconData quote = Symbols.request_quote_rounded;
  static const IconData workOrder = Symbols.precision_manufacturing_rounded;
  static const IconData task = Symbols.checklist_rounded;
  static const IconData warehouse = Symbols.warehouse_rounded;
  static const IconData item = Symbols.inventory_2_rounded;
  static const IconData approval = Symbols.approval_rounded;
  static const IconData conversation = Symbols.forum_rounded;
  static const IconData dashboard = Symbols.dashboard_rounded;
  static const IconData notification = Symbols.notifications_rounded;
  static const IconData profile = Symbols.account_circle_rounded;
  static const IconData settings = Symbols.settings_rounded;

  // ── Actions ──────────────────────────────────────────────────────────────
  static const IconData search = Symbols.search_rounded;
  static const IconData filter = Symbols.filter_list_rounded;
  static const IconData sort = Symbols.sort_rounded;
  static const IconData add = Symbols.add_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData delete = Symbols.delete_rounded;
  static const IconData share = Symbols.share_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData forward = Symbols.chevron_right_rounded;
  static const IconData more = Symbols.more_vert_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData call = Symbols.call_rounded;
  static const IconData email = Symbols.mail_rounded;
  static const IconData whatsApp = Symbols.chat_rounded;
  static const IconData schedule = Symbols.schedule_rounded;
  static const IconData visible = Symbols.visibility_rounded;
  static const IconData hidden = Symbols.visibility_off_rounded;
  static const IconData logout = Symbols.logout_rounded;

  // ── States ───────────────────────────────────────────────────────────────
  static const IconData success = Symbols.check_circle_rounded;
  static const IconData warning = Symbols.schedule_rounded;
  static const IconData danger = Symbols.error_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData neutral = Symbols.inventory_2_rounded;
  static const IconData offline = Symbols.wifi_off_rounded;
  static const IconData empty = Symbols.inbox_rounded;
  static const IconData noAccess = Symbols.lock_rounded;
  static const IconData notFound = Symbols.search_off_rounded;

  /// Weight for the variable `fill` axis: filled marks the active destination.
  static const double fillActive = 1;
  static const double fillInactive = 0;
}

/// An icon that expresses selection through the variable `fill` axis rather
/// than by swapping to a different glyph, so the transition can animate.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.size,
    this.color,
    this.filled = false,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      fill: filled ? AppIcons.fillActive : AppIcons.fillInactive,
      semanticLabel: semanticLabel,
    );
  }
}
