/// CustomizationStore
///
/// Holds the user's customization selections in memory across pages.
/// Structure: { product_id -> { customization_id -> selected_option_map } }
///
/// Example:
///   CustomizationStore.select(3, 1, {'id': 4, 'option_name': 'Red', 'additional_price': '500.00'});
///   CustomizationStore.getAdditionalCost(3); // → 500.0
///   CustomizationStore.getOptionIds(3);       // → [4]
class CustomizationStore {
  CustomizationStore._();

  // product_id → { customization_id → selected option }
  static final Map<int, Map<int, Map<String, dynamic>>> _data = {};

  // ── Select / deselect ──────────────────────────────────────────────────────

  static void select(int productId, int customizationId, Map<String, dynamic> option) {
    _data[productId] ??= {};
    _data[productId]![customizationId] = Map<String, dynamic>.from(option);
  }

  static void deselect(int productId, int customizationId) {
    _data[productId]?.remove(customizationId);
  }

  static void clearProduct(int productId) => _data.remove(productId);
  static void clearAll() => _data.clear();

  

  /// All selected options for a product: { customization_id → option }
  static Map<int, Map<String, dynamic>> getSelections(int productId) =>
      Map<int, Map<String, dynamic>>.from(_data[productId] ?? {});

  /// Selected option for a single customization group
  static Map<String, dynamic>? getSelection(int productId, int customizationId) =>
      _data[productId]?[customizationId];

  /// Flat list of selected option IDs (passed to the order API)
  static List<int> getOptionIds(int productId) =>
      (_data[productId]?.values ?? [])
          .map((o) => o['id'] as int? ?? 0)
          .where((id) => id > 0)
          .toList();

  /// Sum of all additional_price values for a product
  static double getAdditionalCost(int productId) =>
      (_data[productId]?.values ?? []).fold(0.0, (sum, o) {
        final extra = double.tryParse(o['additional_price']?.toString() ?? '0') ?? 0.0;
        return sum + extra;
      });

  /// Total price = base price + additional costs
  static double totalPrice(int productId, double basePrice) =>
      basePrice + getAdditionalCost(productId);

  /// True if the user has selected at least one option for this product
  static bool hasSelections(int productId) =>
      (_data[productId]?.isNotEmpty) ?? false;

  /// Human-readable summary: "Red, Large Frame, Disc Brakes"
  static String summary(int productId) {
    final selections = _data[productId]?.values ?? [];
    if (selections.isEmpty) return 'No customizations selected';
    return selections.map((o) => o['option_name']?.toString() ?? '').join(', ');
  }
}
