import '../../domain/models/models.dart';

class NormalizedIngredient {
  const NormalizedIngredient({
    required this.displayName,
    required this.canonicalName,
    this.brandText,
    this.aliases = const [],
    this.quantity,
  });

  final String displayName;
  final String canonicalName;
  final String? brandText;
  final List<String> aliases;
  final QuantityInfo? quantity;
}

class PantryIntelligenceService {
  const PantryIntelligenceService();

  NormalizedIngredient normalizeRaw(String rawText) {
    final trimmed = rawText.trim();
    final quantity = _parseQuantity(trimmed);
    var identity = trimmed.toLowerCase();

    final matchedBrand = _knownBrands.firstWhere(
      (brand) => identity.startsWith('$brand ') || identity.contains('$brand,'),
      orElse: () => '',
    );
    final brandText = matchedBrand.isEmpty ? null : matchedBrand;
    if (brandText != null) {
      identity = identity.replaceFirst(RegExp('^${RegExp.escape(brandText)}\\s+'), '');
    }

    identity = identity.replaceAll(RegExp(r'\\b(organic|fresh|large|small|frozen|low sodium|unsalted)\\b'), ' ');
    identity = identity.replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ');
    identity = identity.replaceAll(RegExp(r'\\s+'), ' ').trim();

    final aliasMapped = _aliasMap[identity] ?? identity;
    final canonical = _toSingular(aliasMapped);

    return NormalizedIngredient(
      displayName: _titleCase(canonical),
      canonicalName: canonical,
      brandText: brandText == null ? null : _titleCase(brandText),
      aliases: _aliasesFor(canonical),
      quantity: quantity,
    );
  }

  List<ParsedIngredient> mergeDuplicateDetections(List<ParsedIngredient> items) {
    final merged = <String, ParsedIngredient>{};
    for (final item in items) {
      final normalized = normalizeRaw(item.suggestedName);
      final key = normalized.canonicalName;
      final existing = merged[key];
      if (existing == null) {
        merged[key] = item.copyWith(suggestedName: normalized.displayName);
        continue;
      }

      merged[key] = existing.copyWith(
        suggestedName: normalized.displayName,
        confidenceScore: existing.confidenceScore >= item.confidenceScore ? existing.confidenceScore : item.confidenceScore,
        parseConfidence: _higherConfidence(existing.parseConfidence, item.parseConfidence),
        inferredQuantity: _mergeAmount(existing.inferredQuantity, item.inferredQuantity),
        inferredUnit: existing.inferredUnit ?? item.inferredUnit,
        approved: existing.approved || item.approved,
      );
    }

    return merged.values.toList(growable: false);
  }

  PantryItem mergePantryItems({
    required PantryItem existing,
    required PantryItem incoming,
  }) {
    final mergedQuantity = _mergeQuantity(existing.quantityInfo, incoming.quantityInfo);
    final mergedProvenance = [...existing.provenance, ...incoming.provenance]
        .fold<Map<String, PantryItemProvenance>>(<String, PantryItemProvenance>{}, (map, entry) {
      final key = '${entry.type.name}:${entry.sourceId ?? ''}:${entry.recordedAt?.toIso8601String() ?? ''}';
      map[key] = entry;
      return map;
    }).values.toList(growable: false);

    return existing.copyWith(
      quantityInfo: mergedQuantity,
      confidence: existing.confidence >= incoming.confidence ? existing.confidence : incoming.confidence,
      freshnessState: _moreUrgent(existing.estimatedFreshnessState, incoming.estimatedFreshnessState),
      updatedAt: incoming.updatedAt ?? DateTime.now(),
      provenance: mergedProvenance,
      purchasedAt: _latest(existing.purchasedAt, incoming.purchasedAt),
      storedAt: _latest(existing.storedAt, incoming.storedAt),
      useSoonBy: _earliest(existing.useSoonBy, incoming.useSoonBy),
    );
  }

  bool isAliasCompatible(String left, String right) {
    final leftCanonical = normalizeRaw(left).canonicalName;
    final rightCanonical = normalizeRaw(right).canonicalName;
    if (leftCanonical == rightCanonical) return true;
    return _aliasesFor(leftCanonical).contains(rightCanonical) || _aliasesFor(rightCanonical).contains(leftCanonical);
  }

  QuantityInfo? parseQuantity(String rawText) => _parseQuantity(rawText);

  QuantityInfo _mergeQuantity(QuantityInfo existing, QuantityInfo incoming) {
    if (existing.amount == null) return incoming;
    if (incoming.amount == null) return existing;
    if ((existing.unit ?? '') == (incoming.unit ?? '')) {
      return QuantityInfo(amount: existing.amount! + incoming.amount!, unit: existing.unit);
    }
    return existing;
  }

  ParseConfidence _higherConfidence(ParseConfidence a, ParseConfidence b) {
    const rank = {
      ParseConfidence.unclear: 0,
      ParseConfidence.possible: 1,
      ParseConfidence.likely: 2,
    };
    return rank[a]! >= rank[b]! ? a : b;
  }

  double? _mergeAmount(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a + b;
  }

  DateTime? _earliest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  FreshnessState _moreUrgent(FreshnessState a, FreshnessState b) {
    const urgency = {
      FreshnessState.fresh: 0,
      FreshnessState.unknown: 1,
      FreshnessState.useSoon: 2,
      FreshnessState.expiring: 3,
      FreshnessState.expired: 4,
    };
    return urgency[a]! >= urgency[b]! ? a : b;
  }

  QuantityInfo? _parseQuantity(String rawText) {
    final text = rawText.toLowerCase();
    final patterns = [
      (RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(oz|ounce|ounces)\\b'), 'oz'),
      (RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(lb|lbs|pound|pounds)\\b'), 'lb'),
      (RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(cup|cups)\\b'), 'cup'),
      (RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(tbsp|tablespoon|tablespoons)\\b'), 'tbsp'),
      (RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(tsp|teaspoon|teaspoons)\\b'), 'tsp'),
      (RegExp(r'(\\d+(?:\\.\\d+)?)\\s*(can|cans|box|boxes|jar|jars|bag|bags)\\b'), null),
      (RegExp(r'(\\d+)\\s*(x|count|ct)\\b'), 'count'),
    ];

    for (final (regex, normalizedUnit) in patterns) {
      final match = regex.firstMatch(text);
      if (match == null) continue;
      final amount = double.tryParse(match.group(1)!);
      if (amount == null) continue;
      final rawUnit = match.group(2)?.toLowerCase();
      final unit = normalizedUnit ?? _toSingular(rawUnit ?? 'count');
      return QuantityInfo(amount: amount, unit: unit);
    }

    return null;
  }

  String _toSingular(String value) {
    if (value.endsWith('ies')) return '${value.substring(0, value.length - 3)}y';
    if (value.endsWith('es') && value.length > 4) return value.substring(0, value.length - 2);
    if (value.endsWith('s') && !value.endsWith('ss') && value.length > 3) return value.substring(0, value.length - 1);
    return value;
  }

  List<String> _aliasesFor(String canonical) {
    final aliases = <String>{};
    _aliasMap.forEach((alias, target) {
      if (target == canonical) aliases.add(alias);
    });
    aliases.add(canonical);
    return aliases.toList(growable: false);
  }

  String _titleCase(String text) => text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');

  static const Map<String, String> _aliasMap = {
    'tomatoes': 'tomato',
    'chopped tomatoes': 'tomato',
    'diced tomatoes': 'tomato',
    'garbanzo beans': 'chickpea',
    'chick peas': 'chickpea',
    'scallions': 'green onion',
    'spring onions': 'green onion',
    'confectioners sugar': 'powdered sugar',
    'caster sugar': 'sugar',
    'bell peppers': 'bell pepper',
    'red peppers': 'bell pepper',
  };

  static const Set<String> _knownBrands = {
    'kirkland',
    'great value',
    'trader joe\'s',
    '365',
    'goya',
    'heinz',
  };
}
