import 'package:meta/meta.dart';

/// A workstation with active work waiting in the queue.
@immutable
class WorkstationItem {
  const WorkstationItem({
    required this.name,
    this.waiting = 0,
  });

  factory WorkstationItem.fromJson(Map<String, dynamic> json) {
    return WorkstationItem(
      name: json['name'] as String? ?? '',
      waiting: switch (json['waiting']) {
        final int n => n,
        final num n => n.toInt(),
        final String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
    );
  }

  final String name;
  final int waiting;

  @override
  bool operator ==(Object other) =>
      other is WorkstationItem && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
