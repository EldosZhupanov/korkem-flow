import 'package:flutter/foundation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One component of a prompt's token footprint.
@immutable
class TokenBreakdownItem {
  const TokenBreakdownItem({
    required this.id,
    required this.label,
    required this.tokens,
  });

  factory TokenBreakdownItem.fromJson(Map<String, dynamic> json) {
    return TokenBreakdownItem(
      id: '${json['id'] ?? json['key'] ?? json['name'] ?? ''}',
      label: '${json['label'] ?? json['title'] ?? ''}',
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String label;
  final int tokens;

  String displayLabel(AppLocalizations l10n) {
    if (label.isNotEmpty) return label;
    return switch (id.toLowerCase()) {
      'instruction' || 'system_instruction' => l10n.tokenCategoryInstruction,
      'tools' || 'tool_schemas' => l10n.tokenCategoryTools,
      'company_memory' => l10n.tokenCategoryCompanyMemory,
      'user_memory' => l10n.tokenCategoryUserMemory,
      'conversation' || 'history' => l10n.tokenCategoryConversation,
      'order_data' || 'entity_context' => l10n.tokenCategoryOrderData,
      _ => id.isNotEmpty ? id : l10n.tokenCategoryOther,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'tokens': tokens,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenBreakdownItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          tokens == other.tokens;

  @override
  int get hashCode => Object.hash(id, label, tokens);
}

/// Token footprint of the most recent prompt dispatched to the model.
@immutable
class LastPromptBreakdown {
  const LastPromptBreakdown({
    required this.totalTokens,
    required this.items,
    this.timestamp,
  });

  factory LastPromptBreakdown.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map<Object?, Object?>>()
        .map((e) => TokenBreakdownItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    return LastPromptBreakdown(
      totalTokens:
          (json['total_tokens'] as num?)?.toInt() ??
          items.fold<int>(0, (sum, item) => sum + item.tokens),
      items: items,
      timestamp: DateTime.tryParse('${json['timestamp']}'),
    );
  }

  final int totalTokens;
  final List<TokenBreakdownItem> items;
  final DateTime? timestamp;

  /// Returns the ID of the heaviest item if and only if it strictly exceeds
  /// all other items. When two or more items tie for the maximum, returns null.
  String? get heaviestItemId {
    if (items.isEmpty) return null;
    var maxTokens = 0;
    TokenBreakdownItem? maxItem;
    var maxCount = 0;

    for (final item in items) {
      if (item.tokens > maxTokens) {
        maxTokens = item.tokens;
        maxItem = item;
        maxCount = 1;
      } else if (item.tokens == maxTokens && maxTokens > 0) {
        maxCount++;
      }
    }

    if (maxCount == 1) return maxItem?.id;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'total_tokens': totalTokens,
    'items': items.map((e) => e.toJson()).toList(),
    if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
  };
}

/// Aggregated usage statistics over the past 7 days.
@immutable
class WeeklyUsageSummary {
  const WeeklyUsageSummary({
    this.totalTurns = 0,
    this.primaryModelTurns = 0,
    this.reserveTurns = 0,
    this.averageDurationSeconds = 0.0,
  });

  factory WeeklyUsageSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyUsageSummary(
      totalTurns: (json['total_turns'] as num?)?.toInt() ?? 0,
      primaryModelTurns: (json['primary_model_turns'] as num?)?.toInt() ?? 0,
      reserveTurns: (json['reserve_turns'] as num?)?.toInt() ?? 0,
      averageDurationSeconds:
          (json['avg_duration_seconds'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final int totalTurns;
  final int primaryModelTurns;
  final int reserveTurns;
  final double averageDurationSeconds;

  int get primaryRatePercent {
    if (totalTurns <= 0) return 0;
    return ((primaryModelTurns / totalTurns) * 100).round();
  }

  int get reserveRatePercent {
    if (totalTurns <= 0) return 0;
    return ((reserveTurns / totalTurns) * 100).round();
  }

  Map<String, dynamic> toJson() => {
    'total_turns': totalTurns,
    'primary_model_turns': primaryModelTurns,
    'reserve_turns': reserveTurns,
    'avg_duration_seconds': averageDurationSeconds,
  };
}

/// Complete report containing the last prompt's breakdown and weekly stats.
@immutable
class PromptBreakdownReport {
  const PromptBreakdownReport({
    this.lastPrompt,
    this.weeklySummary,
  });

  const PromptBreakdownReport.empty() : lastPrompt = null, weeklySummary = null;

  factory PromptBreakdownReport.fromJson(Map<String, dynamic> json) {
    final rawPrompt = json['last_prompt'] as Map<Object?, Object?>?;
    final rawWeekly = json['weekly_summary'] as Map<Object?, Object?>?;

    return PromptBreakdownReport(
      lastPrompt: rawPrompt != null
          ? LastPromptBreakdown.fromJson(Map<String, dynamic>.from(rawPrompt))
          : null,
      weeklySummary: rawWeekly != null
          ? WeeklyUsageSummary.fromJson(Map<String, dynamic>.from(rawWeekly))
          : null,
    );
  }

  final LastPromptBreakdown? lastPrompt;
  final WeeklyUsageSummary? weeklySummary;

  bool get isEmpty =>
      (lastPrompt == null || lastPrompt!.items.isEmpty) &&
      (weeklySummary == null || weeklySummary!.totalTurns == 0);

  bool get isNotEmpty => !isEmpty;
}
