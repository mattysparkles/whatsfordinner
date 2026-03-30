import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/features/shopping_list/infrastructure/adapters/backend/backend_instacart_link_adapter.dart';
import 'package:pantry_pilot/src/infrastructure/gateway/pantry_gateway_client.dart';

void main() {
  test('maps checkout url from backend', () async {
    final adapter = BackendInstacartLinkAdapter(
      client: _FakeGatewayClient(payload: {'checkoutUrl': 'https://www.instacart.com/store/s?k=lemon', 'message': 'ok'}),
    );

    final result = await adapter.buildLink(_list());

    expect(result.checkoutUri.toString(), contains('instacart.com'));
    expect(result.message, 'ok');
  });

  test('returns failure when backend rejects request', () async {
    final adapter = BackendInstacartLinkAdapter(client: _FakeGatewayClient(error: const PantryGatewayException('Temporarily unavailable.')));

    expect(() => adapter.buildLink(_list()), throwsStateError);
  });
}

ShoppingList _list() => ShoppingList(
      id: 'list-1',
      title: 'Demo list',
      createdAt: DateTime(2026, 3, 30),
      recipeTitle: 'Lemon Chicken',
      items: const [
        ShoppingListItem(
          id: '1',
          ingredientName: 'Chicken breast',
          groupLabel: 'Protein',
          quantity: 2,
          unit: 'lb',
          note: 'boneless',
        ),
      ],
    );

class _FakeGatewayClient extends PantryGatewayClient {
  _FakeGatewayClient({this.payload, this.error}) : super(baseUrl: 'https://example.com');

  final Map<String, dynamic>? payload;
  final PantryGatewayException? error;

  @override
  Future<Map<String, dynamic>> postJson({required String path, required Map<String, dynamic> payload}) async {
    if (error != null) throw error!;
    return this.payload ?? const {};
  }
}
