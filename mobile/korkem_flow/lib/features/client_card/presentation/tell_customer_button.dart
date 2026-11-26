import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Сообщить клиенту» on a ready order (owner, 18.11.2026): WhatsApp opens
/// with the owner's words — the order's number and what is still owed — and
/// once sent, the order remembers the day. Told already, it says when.
class TellCustomerButton extends ConsumerWidget {
  const TellCustomerButton({required this.order, this.toldOn, super.key});

  final String order;
  final String? toldOn;

  Future<void> _tell(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(clientCardRepositoryProvider);
    final ToWriteRow row;
    try {
      row = await repo.textFor(order);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      return;
    }
    if (row.phone == null) {
      messenger.showFailureMessage(l10n.twNoPhone);
      return;
    }
    final opened = await ContactActions.whatsAppMessage(row.phone, row.text);
    if (!opened) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.twSentQ),
        // A bar with a button stays until pressed unless told
        // otherwise (Flutter 3.32+): it is told — it goes.
        persist: false,
        action: SnackBarAction(
          label: l10n.twMark,
          onPressed: () async {
            try {
              await repo.mark(ToWriteKind.ready, order: order);
              ref
                ..invalidate(mdfOrderProvider(order))
                ..invalidate(toWriteProvider);
            } on Object catch (e) {
              messenger.showFailure(e, l10n);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final told = DateTime.tryParse(toldOn ?? '');
    return TextButton.icon(
      key: const ValueKey('mdfTellCustomer'),
      onPressed: () => unawaited(_tell(context, ref)),
      icon: const Icon(AppIcons.whatsApp),
      label: Text(
        told == null
            ? l10n.orderTell
            : l10n.orderTold(DateFormat('dd.MM').format(told)),
      ),
    );
  }
}
