import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/glue_stock.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The server's words for how money moved (the cash book's own).
const filmTransfer = 'Перевод';
const filmCash = 'Наличные';
const filmCard = 'Карта';

double? filmNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.').replaceAll(' ', ''));

/// How a bought thing came and how it was paid for — a roll of film or a
/// can of paint alike (owner, 15.11.2026: «как в разделе ПВХ плёнок»):
/// the supplier paid now, on credit or by his invoice; how it was brought,
/// from where, what that cost and who paid; who took it in.
///
/// A draft the receipt's dialog keeps and the two fields below edit.
class FilmReceiptTerms {
  // The thing itself (owner, 14.11.2026): paid now — how, and from whose
  // money; on credit; or by the supplier's invoice, with its day to pay.
  String supplierMode = FilmSupplierPay.modePaid;
  String supplierHow = filmCash;

  /// Through which bank, when by transfer or card (owner, 15.11.2026).
  String? supplierBank;
  bool supplierFromDept = true;
  final invoiceNo = TextEditingController();
  DateTime invoiceOn = DateTime.now();
  DateTime? invoiceDue = DateTime.now().add(const Duration(days: 7));

  // How it came (owner, 11.11.2026): by default as this supplier's last
  // delivery came, from the city on its card; nothing paid; taken in by me.
  String? transport;
  String? city;
  String? taker;
  bool urgent = false;
  final cost = TextEditingController();

  // Who brought it and how to reach him — optional (owner, 12.11.2026).
  final driver = TextEditingController();
  final phone = TextEditingController();

  // Who paid for the bringing (owner, 11.11.2026): the cash, in cash,
  // unless said.
  String payer = FilmPayer.cash;
  String? paidBy;
  String payMethod = filmCash;
  String? payBank;

  void dispose() {
    invoiceNo.dispose();
    cost.dispose();
    driver.dispose();
    phone.dispose();
  }

  double get costAmount => filmNumber(cost.text) ?? 0;

  bool get supplierPaid => supplierMode == FilmSupplierPay.modePaid;

  /// An invoice with no number cannot be saved.
  bool get incomplete =>
      supplierMode == FilmSupplierPay.modeInvoice &&
      invoiceNo.text.trim().isEmpty;

  FilmSupplierPay get supplierPay => switch (supplierMode) {
    FilmSupplierPay.modeCredit => const FilmSupplierPay.credit(),
    FilmSupplierPay.modeInvoice => FilmSupplierPay.invoice(
      invoiceNo: invoiceNo.text.trim(),
      invoiceOn: mdfIso(invoiceOn),
      dueOn: invoiceDue == null ? null : mdfIso(invoiceDue!),
    ),
    _ => FilmSupplierPay.paid(
      method: supplierHow,
      fromDept: supplierFromDept,
      bank: supplierHow == filmCash ? null : supplierBank,
    ),
  };

  String? transportOf(FilmDeliveryOptions? o, String? supplier) =>
      transport ?? o?.last[supplier]?.transport ?? o?.transports.firstOrNull;

  String? cityOf(FilmDeliveryOptions? o, String? supplier) =>
      city ?? o?.last[supplier]?.city ?? o?.supplierCities[supplier];

  String? takerOf(FilmDeliveryOptions? o) => o == null ? null : taker ?? o.me;

  /// What the server is sent as `delivery`; nothing before the options
  /// have come.
  Map<String, Object?>? delivery(FilmDeliveryOptions? o, String? supplier) {
    if (o == null) return null;
    final amount = costAmount;
    return {
      'transport': transportOf(o, supplier),
      'city': cityOf(o, supplier) ?? '',
      'amount': amount,
      'urgent': urgent,
      if (driver.text.trim().isNotEmpty) 'driver': driver.text.trim(),
      if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
      if (amount > 0) ...{
        'payer': payer,
        if (payer == FilmPayer.employee) 'paid_by': paidBy ?? o.me,
        if (payer != FilmPayer.unpaid) 'method': payMethod,
        if (payer != FilmPayer.unpaid && payMethod != filmCash)
          'bank': ?payBank,
      },
    };
  }

  /// «Наличные, из кассы отдела», «В долг», «По счёту № 123».
  String supplierLabel(AppLocalizations l10n, {bool deptCash = true}) =>
      switch (supplierMode) {
        FilmSupplierPay.modeCredit => l10n.filmSupplierOnCredit,
        FilmSupplierPay.modeInvoice => l10n.filmByInvoiceNo(
          invoiceNo.text.trim(),
        ),
        _ => [
          filmMethodLabel(l10n, supplierHow),
          if (supplierHow != filmCash) ?supplierBank,
          if (deptCash && supplierFromDept) l10n.filmFromDeptCash,
        ].join(', '),
      };

  String driverLabel(AppLocalizations l10n, {bool deptCash = true}) =>
      switch (payer) {
        FilmPayer.employee => l10n.filmPayerEmployee,
        FilmPayer.unpaid => l10n.filmPayerUnpaid,
        _ => [
          filmMethodLabel(l10n, payMethod),
          if (payMethod != filmCash) ?payBank,
          if (deptCash) l10n.filmFromDeptCash,
        ].join(', '),
      };
}

String filmMethodLabel(AppLocalizations l10n, String m) => switch (m) {
  filmTransfer => l10n.mdfPayTransfer,
  filmCard => l10n.mdfPayCard,
  _ => l10n.mdfPayCash,
};

/// Through which bank a transfer or a card went — Kaspi, Halyk, Forte …
/// (owner, 15.11.2026: «Перевод — Каспи, Форте, Халык и т.д., и ещё должен
/// регулироваться»): the MDF bank list, with its own ✎.
class FilmBankChips extends ConsumerWidget {
  const FilmBankChips({
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String keyPrefix;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final banks =
        (ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty)
            .values(MdfDictKind.bank);
    return filmWithList(
      context,
      key: '$keyPrefix:edit',
      onEdit: () async {
        final picked = await showMdfDictionary(
          context,
          MdfDictKind.bank,
          title: l10n.mdfPayBank,
          current: value,
        );
        ref.invalidate(mdfDictionariesProvider);
        if (picked != null) onChanged(picked);
      },
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.mdfPayBank),
          for (final b in banks)
            ChoiceChip(
              key: ValueKey('$keyPrefix:$b'),
              label: Text(b),
              selected: value == b,
              onSelected: (on) => onChanged(on ? b : null),
            ),
        ],
      ),
    );
  }
}

/// After «Перевод» or «Карта» picked from a menu: through which bank.
/// `''` for none (cash, an empty list, «—»); null when the person closed
/// the question — nothing is paid then.
Future<String?> filmAskBank(
  BuildContext context,
  WidgetRef ref,
  String method,
) async {
  if (method == filmCash) return '';
  // Kept alive while it loads: the list is auto-disposed.
  final keep = ref.listenManual(mdfDictionariesProvider, (_, _) {});
  var banks = const <String>[];
  try {
    banks = (await ref.read(
      mdfDictionariesProvider.future,
    )).values(MdfDictKind.bank);
  } on Object {
    // No list to hand: paid without a bank rather than not at all.
  } finally {
    keep.close();
  }
  if (!context.mounted) return null;
  if (banks.isEmpty) return '';
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SimpleDialog(
        title: Text(l10n.mdfPayBank),
        children: [
          for (final b in banks)
            SimpleDialogOption(
              key: ValueKey('filmAskBank:$b'),
              onPressed: () => Navigator.pop(context, b),
              child: Text(b),
            ),
          SimpleDialogOption(
            key: const ValueKey('filmAskBank:none'),
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.mdfNone),
          ),
        ],
      );
    },
  );
}

/// A field with its list's own ✎: the list opens to be added to, renamed,
/// cleaned (owner, 11.11.2026: «чтобы редактировался и мог бы удалить»).
Widget filmWithList(
  BuildContext context, {
  required String key,
  required Widget child,
  required VoidCallback onEdit,
}) => Row(
  children: [
    Expanded(child: child),
    IconButton(
      key: ValueKey(key),
      tooltip: AppLocalizations.of(context).mdfDictOpen,
      onPressed: onEdit,
      icon: const Icon(AppIcons.edit),
    ),
  ],
);

/// Who works here, to pick who took a delivery in or who sold — the one
/// signed in first.
Widget filmPersonField({
  required String key,
  required String label,
  required FilmDeliveryOptions? opts,
  required String? value,
  required ValueChanged<String?> onChanged,
}) {
  final staff = opts?.staff ?? const [];
  final chosen = value ?? opts?.me;
  return DropdownButtonFormField<String>(
    key: ValueKey('$key:${staff.length}'),
    initialValue: staff.any((p) => p.user == chosen) ? chosen : null,
    isExpanded: true,
    items: [
      for (final p in staff)
        DropdownMenuItem(value: p.user, child: Text(p.name)),
    ],
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
  );
}

/// «Оплачено», «В долг», «По счёту» — and what each asks. [deptCash]:
/// whether the department has a cash of its own to pay from (the film
/// department does, the paint shop does not).
class FilmSupplierPayField extends StatelessWidget {
  const FilmSupplierPayField({
    required this.terms,
    required this.update,
    this.deptCash = true,
    super.key,
  });

  final FilmReceiptTerms terms;

  /// The dialog's own setState.
  final void Function(VoidCallback) update;
  final bool deptCash;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String day(DateTime d) => mdfDay(mdfIso(d));
    Future<DateTime?> pick(DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    final t = terms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.filmSupplierPay, style: theme.textTheme.titleSmall),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (mode, label) in [
              (FilmSupplierPay.modePaid, l10n.filmSupplierPaidNow),
              (FilmSupplierPay.modeCredit, l10n.filmSupplierOnCredit),
              (FilmSupplierPay.modeInvoice, l10n.filmSupplierByInvoice),
            ])
              ChoiceChip(
                key: ValueKey('filmSupplierPay:$mode'),
                label: Text(label),
                selected: t.supplierMode == mode,
                onSelected: (_) => update(() => t.supplierMode = mode),
              ),
          ],
        ),
        if (t.supplierMode == FilmSupplierPay.modePaid) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (m, label) in [
                (filmCash, l10n.mdfPayCash),
                (filmTransfer, l10n.mdfPayTransfer),
                (filmCard, l10n.mdfPayCard),
              ])
                ChoiceChip(
                  key: ValueKey('filmSupplierHow:$m'),
                  label: Text(label),
                  selected: t.supplierHow == m,
                  onSelected: (_) => update(() => t.supplierHow = m),
                ),
            ],
          ),
          if (t.supplierHow != filmCash)
            FilmBankChips(
              keyPrefix: 'filmSupplierBank',
              value: t.supplierBank,
              onChanged: (b) => update(() => t.supplierBank = b),
            ),
          if (deptCash)
            CheckboxListTile(
              key: const ValueKey('filmSupplierFromDept'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: t.supplierFromDept,
              onChanged: (v) => update(() => t.supplierFromDept = v ?? true),
              title: Text(l10n.filmSupplierFromDept),
            ),
        ],
        if (t.supplierMode == FilmSupplierPay.modeInvoice) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: AppSpacing.xxxl * 3,
                child: TextField(
                  key: const ValueKey('filmSupplierInvoiceNo'),
                  controller: t.invoiceNo,
                  decoration: InputDecoration(
                    labelText: l10n.filmInvoiceNo,
                    isDense: true,
                  ),
                  onChanged: (_) => update(() {}),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('filmSupplierInvoiceOn'),
                onPressed: () async {
                  final d = await pick(t.invoiceOn);
                  if (d != null) update(() => t.invoiceOn = d);
                },
                child: Text(l10n.filmInvoiceOn(day(t.invoiceOn))),
              ),
              OutlinedButton(
                key: const ValueKey('filmSupplierInvoiceDue'),
                onPressed: () async {
                  final d = await pick(t.invoiceDue ?? t.invoiceOn);
                  if (d != null) update(() => t.invoiceDue = d);
                },
                child: Text(
                  t.invoiceDue == null
                      ? l10n.filmInvoiceNoDue
                      : l10n.filmInvoiceDue(day(t.invoiceDue!)),
                ),
              ),
            ],
          ),
          Text(l10n.filmInvoiceHint, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// «Доставка»: how it came — by taxi, a Gazelle, the supplier's own car —
/// from which city, what it cost and who paid; who brought it; who took it
/// in. [costHelper] says what the bringing adds to each unit.
class FilmDeliveryField extends ConsumerWidget {
  const FilmDeliveryField({
    required this.terms,
    required this.opts,
    required this.supplier,
    required this.update,
    this.costHelper,
    super.key,
  });

  final FilmReceiptTerms terms;
  final FilmDeliveryOptions opts;
  final String? supplier;
  final void Function(VoidCallback) update;
  final String? costHelper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = terms;
    final transport = t.transportOf(opts, supplier);
    final city = t.cityOf(opts, supplier);
    final cities = {...opts.cities, ?city}.toList();
    final cost = t.costAmount;
    Future<void> editList(MdfDictKind kind, String title, String? now) async {
      final picked = await showMdfDictionary(
        context,
        kind,
        title: title,
        current: now,
      );
      ref.invalidate(filmDeliveryOptionsProvider);
      if (picked != null) {
        update(() {
          if (kind == MdfDictKind.transport) {
            t.transport = picked;
          } else {
            t.city = picked;
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.filmDelivery, style: Theme.of(context).textTheme.titleSmall),
        filmWithList(
          context,
          key: 'filmDelivery:transport:edit',
          onEdit: () =>
              editList(MdfDictKind.transport, l10n.filmTransport, transport),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final tr in opts.transports)
                ChoiceChip(
                  key: ValueKey('filmDelivery:transport:$tr'),
                  label: Text(tr),
                  selected: tr == transport,
                  onSelected: (_) => update(() => t.transport = tr),
                ),
            ],
          ),
        ),
        filmWithList(
          context,
          key: 'filmDelivery:city:edit',
          onEdit: () => editList(MdfDictKind.city, l10n.filmCity, city),
          child: DropdownButtonFormField<String?>(
            key: ValueKey('filmDelivery:city:$city:${cities.length}'),
            initialValue: city,
            isExpanded: true,
            items: [
              DropdownMenuItem(child: Text(l10n.mdfNone)),
              for (final c in cities)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => update(() => t.city = v),
            decoration: InputDecoration(labelText: l10n.filmCity),
          ),
        ),
        TextField(
          key: const ValueKey('filmDelivery:cost'),
          controller: t.cost,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => update(() {}),
          decoration: InputDecoration(
            labelText: l10n.filmDeliveryCost,
            helperText: cost > 0 ? costHelper : null,
          ),
        ),
        if (cost > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.filmDeliveryPayer),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (p, label) in [
                (FilmPayer.cash, l10n.filmPayerCash),
                (FilmPayer.employee, l10n.filmPayerEmployee),
                (FilmPayer.unpaid, l10n.filmPayerUnpaid),
              ])
                ChoiceChip(
                  key: ValueKey('filmDelivery:payer:$p'),
                  label: Text(label),
                  selected: t.payer == p,
                  onSelected: (_) => update(() => t.payer = p),
                ),
            ],
          ),
          if (t.payer == FilmPayer.employee)
            filmPersonField(
              key: 'filmDelivery:paidBy',
              label: l10n.filmPaidBy,
              opts: opts,
              value: t.paidBy,
              onChanged: (v) => update(() => t.paidBy = v),
            ),
          if (t.payer != FilmPayer.unpaid)
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final (m, label) in [
                  (filmCash, l10n.mdfPayCash),
                  (filmTransfer, l10n.mdfPayTransfer),
                  (filmCard, l10n.mdfPayCard),
                ])
                  ChoiceChip(
                    key: ValueKey('filmDelivery:method:$m'),
                    label: Text(label),
                    selected: t.payMethod == m,
                    onSelected: (_) => update(() => t.payMethod = m),
                  ),
              ],
            ),
          if (t.payer != FilmPayer.unpaid && t.payMethod != filmCash)
            FilmBankChips(
              keyPrefix: 'filmDelivery:bank',
              value: t.payBank,
              onChanged: (b) => update(() => t.payBank = b),
            ),
        ],
        // Drivers who brought something before: a tap fills both.
        if (opts.drivers.isNotEmpty)
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final d in opts.drivers.take(6))
                ActionChip(
                  key: ValueKey('filmDelivery:driver:${d.driver}'),
                  label: Text([d.driver, ?d.phone].join(' · ')),
                  onPressed: () => update(() {
                    t.driver.text = d.driver;
                    t.phone.text = d.phone ?? '';
                  }),
                ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('filmDelivery:driver'),
                controller: t.driver,
                decoration: InputDecoration(labelText: l10n.filmDriver),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                key: const ValueKey('filmDelivery:phone'),
                controller: t.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [PhoneMaskFormatter()],
                decoration: InputDecoration(labelText: l10n.filmDriverPhone),
              ),
            ),
          ],
        ),
        filmPersonField(
          key: 'filmDelivery:taker',
          label: l10n.filmReceivedBy,
          opts: opts,
          value: t.taker,
          onChanged: (v) => update(() => t.taker = v),
        ),
        CheckboxListTile(
          key: const ValueKey('filmDelivery:urgent'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: t.urgent,
          onChanged: (v) => update(() => t.urgent = v ?? false),
          title: Text(l10n.filmUrgent),
        ),
      ],
    );
  }
}

/// A sale line's quantity as said: «12 м» for film, glue's «2 ведра» or «5 л»
/// (owner, 17.11.2026).
String filmLineQty(AppLocalizations l10n, FilmSaleLine l) => l.unit == null
    ? '${filmMetres(l.metres)} м'
    : l.unit == GlueUnit.litre.wire
    ? l10n.filmGlueLitres(filmMetres(l.qty))
    : l10n.filmGlueBuckets(filmMetres(l.qty));
