import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/customization_store.dart';

class CustomizationPickerPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onDone;

  const CustomizationPickerPage({
    super.key,
    required this.product,
    this.onDone,
  });

  @override
  State<CustomizationPickerPage> createState() => _CustomizationPickerPageState();
}

class _CustomizationPickerPageState extends State<CustomizationPickerPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  late int    _productId;
  late double _basePrice;

  @override
  void initState() {
    super.initState();
    _productId = widget.product['id'] as int;
    _basePrice = double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0;
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await ApiService.getAllCustomizationsWithOptions();
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _additionalCost => CustomizationStore.getAdditionalCost(_productId);
  double get _totalPrice     => _basePrice + _additionalCost;

  int _selectedCount() =>
      CustomizationStore.getSelections(_productId).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text("Customize",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedCount() > 0)
            TextButton(
              onPressed: () {
                CustomizationStore.clearProduct(_productId);
                setState(() {});
              },
              child: const Text("Reset",
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(children: [
        // Product header
        _productHeader(),

        // Groups
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              : _groups.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _groups.length,
                      itemBuilder: (_, i) => _groupCard(_groups[i]),
                    ),
        ),
      ]),

      // Sticky bottom
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _productHeader() => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryGlow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 28),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.product['product_name']?.toString() ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text("Base price: ₱${_basePrice.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text("TOTAL", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
        Text("₱${_totalPrice.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
      ]),
    ]),
  );

  Widget _groupCard(Map<String, dynamic> group) {
    final groupId = group['id'] as int;
    final groupName = group['name']?.toString() ?? '';
    final options = (group['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selected = CustomizationStore.getSelection(_productId, groupId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected != null ? AppColors.primary.withOpacity(0.4) : AppColors.cardBorder,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Text(groupName.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: AppColors.textMuted, letterSpacing: 1.5)),
            const Spacer(),
            if (selected != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(selected['option_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ] else
              const Text("Optional", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),

        const Divider(height: 1, color: AppColors.divider),

        // Options
        if (options.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text("No options available", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) {
                final optId    = opt['id'] as int;
                final optName  = opt['option_name']?.toString() ?? '';
                final price    = double.tryParse(opt['additional_price']?.toString() ?? '0') ?? 0.0;
                final isSelected = selected?['id'] == optId;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        CustomizationStore.deselect(_productId, groupId);
                      } else {
                        CustomizationStore.select(_productId, groupId, opt);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isSelected) ...[
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: isSelected ? Colors.black : AppColors.primary),
                          const SizedBox(width: 5),
                        ],
                        Text(optName,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.black : AppColors.textPrimary,
                            )),
                      ]),
                      if (price > 0) ...[
                        const SizedBox(height: 3),
                        Text("+₱${price.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.black87 : AppColors.primary,
                            )),
                      ] else ...[
                        const SizedBox(height: 3),
                        Text("Free",
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.black54 : AppColors.textMuted,
                            )),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _bottomBar() {
    final count = _selectedCount();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Cost breakdown
        if (_additionalCost > 0) ...[
          Row(children: [
            const Text("Base price", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Spacer(),
            Text("₱${_basePrice.toStringAsFixed(2)}",
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text("Customizations ($count selected)",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Spacer(),
            Text("+₱${_additionalCost.toStringAsFixed(2)}",
                style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
        ],

        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("TOTAL", style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            Text("₱${_totalPrice.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.onDone != null) widget.onDone!();
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check_rounded, color: Colors.black, size: 20),
                label: Text(
                  count == 0 ? "Continue without changes" : "Apply ($count selected)",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 56),
    const SizedBox(height: 14),
    const Text("No customization options available",
        style: TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    const Text("Check back later or contact the shop",
        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
  ]));
}
