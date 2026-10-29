import 'package:flutter/material.dart';

/// Asks for a short reason — for a rejection the other person will read.
///
/// Returns the trimmed text, or `null` when cancelled or left empty. The
/// dialog owns its controller: disposing one from the caller after `await`
/// races the closing animation, which still reads it.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  required String cancel,
  Key? fieldKey,
}) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      label: label,
      confirm: confirm,
      cancel: cancel,
      fieldKey: fieldKey,
    ),
  );
  return (reason == null || reason.isEmpty) ? null : reason;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.confirm,
    required this.cancel,
    this.fieldKey,
  });

  final String title;
  final String label;
  final String confirm;
  final String cancel;
  final Key? fieldKey;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
