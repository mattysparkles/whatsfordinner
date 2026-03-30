import '../../../../core/models/app_models.dart';

String normalizedItemKey(ShoppingListItem item) => item.ingredientName.trim().toLowerCase();

String formatItemForProvider(ShoppingListItem item) {
  final quantity = item.quantity == null ? '' : _formatQuantity(item.quantity!);
  final unit = item.unit?.trim() ?? '';
  final note = item.note?.trim() ?? '';
  final base = [
    if (quantity.isNotEmpty) quantity,
    if (unit.isNotEmpty) unit,
    item.ingredientName.trim(),
  ].join(' ');
  if (note.isEmpty) return base;
  return '$base ($note)';
}

String stableListFingerprint(ShoppingList list) {
  final mapped = list.items
      .map((item) => '${normalizedItemKey(item)}|${item.quantity ?? ''}|${item.unit ?? ''}|${item.note ?? ''}')
      .toList(growable: false)
    ..sort();
  return '${list.id}:${mapped.join(';')}';
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
