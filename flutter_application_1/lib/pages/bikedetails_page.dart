import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/customization_store.dart';
import 'customization_picker_page.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'ar_viewer_page.dart';
import 'checkout_page.dart';

class BikeDetailsPage extends StatefulWidget {
  final Map<String, dynamic> bike;
  final String imageUrl;
  const BikeDetailsPage({super.key, required this.bike, required this.imageUrl});

  @override
  State<BikeDetailsPage> createState() => _BikeDetailsPageState();
}

class _BikeDetailsPageState extends State<BikeDetailsPage> {
  List<Map<String, dynamic>> _images  = [];
  Map<String, dynamic>?      _reviews;
  List<Map<String, dynamic>> _variants = [];
  Map<String, dynamic>?      _selectedVariant;
  int _selectedImage = 0;
  bool _loadingImages   = true;
  bool _loadingReviews  = true;
  bool _addingToCart    = false;
  int  _qty = 1;

  @override
  void initState() {
    super.initState();
    _variants = (widget.bike['variants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final id = widget.bike['id'] as int;
    try {
      final imgs = await ApiService.getProductImages(id);
      if (mounted) setState(() { _images = imgs; _loadingImages = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingImages = false);
    }
    try {
      final rev = await ApiService.getProductReviews(id);
      if (mounted) setState(() { _reviews = rev; _loadingReviews = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _addToCart() async {
    if (_variants.isNotEmpty && _selectedVariant == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Please select an option first"),
      backgroundColor: AppColors.error,
    ));
    return;
  }
  setState(() => _addingToCart = true);
  try {
    await ApiService.addToCart(
      widget.bike['id'] as int,
      _qty,
      variantId: _selectedVariant?['id'] as int?,
    );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Text("${widget.bike['product_name']} added to cart!"),
        ]),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(e.message)),
        ]),
      ));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  void _orderNow() {
  if (_variants.isNotEmpty && _selectedVariant == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Please select an option first"),
      backgroundColor: AppColors.error,
    ));
    return;
  }
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => CheckoutPage.direct(
      bike: widget.bike,
      selectedVariant: _selectedVariant,
      quantity: _qty,
    ),
  ));
}


  String _activeImageUrl() {
  if (_images.isNotEmpty && _selectedImage < _images.length) {
    return AppConstants.imageUrl(_images[_selectedImage]['image_url']?.toString());
  }
  return widget.imageUrl;
}

  @override
  Widget build(BuildContext context) {
    final bike        = widget.bike;
    final name        = (bike['product_name'] ?? "Unknown Bike").toString();
    final price       = (bike['price'] ?? "0").toString();
    final category    = (bike['category_name'] ?? "").toString();
    final description = (bike['description'] ?? "").toString();
    final stock       = int.tryParse((bike['stock'] ?? "0").toString()) ?? 0;
    final effectiveStock = _variants.isNotEmpty ? (int.tryParse(_selectedVariant?['stock']?.toString() ?? '0') ?? 0) : stock;
    final variantAdj = double.tryParse(_selectedVariant?['price_adjustment']?.toString() ?? '0') ?? 0;
    final effectivePrice = (double.tryParse(price) ?? 0) + variantAdj;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        // ── Hero ────────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 320, pinned: true,
          backgroundColor: AppColors.background,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              _heroImage(_activeImageUrl()),
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 100, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [AppColors.background, Colors.transparent]),
                )),
              ),
              // Thumbnail strip
              if (_images.length > 1) Positioned(
                bottom: 16, left: 16, right: 16,
                child: SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal, itemCount: _images.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setState(() => _selectedImage = i),
                      child: Container(
                        width: 52, height: 52, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _selectedImage == i ? AppColors.primary : Colors.transparent, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          // thumbnail strip
                           child: CachedNetworkImage(
                           imageUrl: AppConstants.imageUrl(_images[i]['image_url']?.toString()),
                           fit: BoxFit.cover,
                           errorWidget: (_, _, _) => Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 20)),
                         ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Details ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (category.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                  child: Text(category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
              ],

              Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1)),
              const SizedBox(height: 16),

              Row(children: [
                Text("₱${effectivePrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined, color: effectiveStock > 0 ? AppColors.success : AppColors.error, size: 14),
                    const SizedBox(width: 6),
                   Text("$effectiveStock in stock", style: TextStyle(fontSize: 12, color: effectiveStock > 0 ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),

              // Qty selector
              Row(children: [
                const Text("QTY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5)),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _qtyBtn(Icons.remove, () { if (_qty > 1) setState(() => _qty--); }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("$_qty", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    _qtyBtn(Icons.add, () { if (_qty < effectiveStock) setState(() => _qty++); }),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 24),

              // Description
              const Text("DESCRIPTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
              const SizedBox(height: 10),
              Text(description.isNotEmpty ? description : "No description available.",
    style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.7)),

          const SizedBox(height: 24),

        // Customization banner — only shown if this product is customizable
        if (_variants.isNotEmpty) ...[
               _buildVariantPicker(),
          const SizedBox(height: 24),
        ] else if (bike['is_customizable'] == 1 || bike['is_customizable'] == true) ...[
             _buildCustomizationBanner(context, bike['id'] as int),
          const SizedBox(height: 24),
        ],

             // AR viewer button — TEMPORARY: always shown with test model for pipeline testing
              _buildArButton(context),
             const SizedBox(height: 24),

            // Reviews
              _buildReviews(),
              const SizedBox(height: 32),

              // Add to cart
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton.icon(
                  onPressed: (effectiveStock == 0 || (_variants.isNotEmpty && _selectedVariant == null) || _addingToCart) ? null : _addToCart,
                  icon: _addingToCart
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 20),
                  label: Text(effectiveStock == 0 ? "Out of Stock" : "Add to Cart",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveStock == 0 ? AppColors.textMuted : AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
               const SizedBox(height: 12),
               SizedBox(
               width: double.infinity, height: 54,
              child: ElevatedButton.icon(
               onPressed: (effectiveStock == 0 || (_variants.isNotEmpty && _selectedVariant == null)) ? null : _orderNow,
               icon: const Icon(Icons.now_widgets, color: Colors.black, size: 20),
               label: Text(effectiveStock == 0 ? "Out of Stock" : "Order Now",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
               backgroundColor: effectiveStock == 0 ? AppColors.textMuted : const Color.fromARGB(255, 52, 181, 40),
               elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ), 
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: const Text("Back to Catalog", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _heroImage(String url) {
    if (url.isEmpty) return Container(color: AppColors.card, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 80));
    return CachedNetworkImage(
      imageUrl: url, fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.card, child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
      errorWidget: (_, _, _) => Container(color: AppColors.card, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 80)),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Icon(icon, color: AppColors.textPrimary, size: 18),
    ),
  );

  Widget _buildReviews() {
    if (_loadingReviews) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)));
    if (_reviews == null) return const SizedBox.shrink();

    final stats   = _reviews!['stats'] as Map<String, dynamic>? ?? {};
    final reviews = (_reviews!['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final avg     = double.tryParse(stats['average']?.toString() ?? '0') ?? 0;
    final total   = int.tryParse(stats['total']?.toString() ?? '0') ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(color: AppColors.divider, height: 1),
      const SizedBox(height: 20),
      Row(children: [
        const Text("Reviews ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
        const SizedBox(width: 12),
        if (total > 0) ...[
          _stars(avg.round()),
          const SizedBox(width: 8),
          Text("$avg ($total)", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ]),
      const SizedBox(height: 12),
      if (reviews.isEmpty) const Text(" ", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ...reviews.take(3).map((r) => _reviewCard(r)),
    ]);
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(r['reviewer_name'] ?? 'Anonymous', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          _stars(int.tryParse(r['rating']?.toString() ?? '5') ?? 5),
        ]),
        if ((r['comment'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(r['comment'].toString(), style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
        ],
      ]),
    );
  }

  Widget _stars(int n) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < n ? Icons.star_rounded : Icons.star_border_rounded,
      color: AppColors.warning, size: 14,
    )),
  );



  String _variantImageUrl(Map<String, dynamic> v) => AppConstants.imageUrl(v['image']?.toString());   


Widget _buildVariantPicker() {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Text("CHOOSE AN OPTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
      const Spacer(),
      if (_selectedVariant != null)
        Text("${_selectedVariant!['variant_type']}: ${_selectedVariant!['variant_value']}",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
    ]),
    const SizedBox(height: 10),
    if (_selectedVariant == null)
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text("Tap an option below to select it", style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
      ),
    SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _variants.length,
        itemBuilder: (_, i) {
          final v = _variants[i];
          final isSelected = _selectedVariant?['id'] == v['id'];
          final stock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
          final adj = double.tryParse(v['price_adjustment']?.toString() ?? '0') ?? 0;
          final imgUrl = _variantImageUrl(v);

          return GestureDetector(
            onTap: stock == 0 ? null : () => setState(() {
                if (_selectedVariant?['id'] == v['id']) {
                _selectedVariant = null;
              } else {
               _selectedVariant = v;
               _qty = 1;
              }
             }),
            child: Opacity(
              opacity: stock == 0 ? 0.4 : 1,
              child: Stack(clipBehavior: Clip.none, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 120,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGlow : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder, width: isSelected ? 2 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: SizedBox(
                        height: 72, width: double.infinity,
                        child: imgUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 28)))
                            : Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 28)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v['variant_type']?.toString() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
                        Text(v['variant_value']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? AppColors.primary : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          stock == 0 ? "Out of stock" : (adj > 0 ? "+₱${adj.toStringAsFixed(0)}" : adj < 0 ? "-₱${adj.abs().toStringAsFixed(0)}" : "Included"),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: stock == 0 ? AppColors.error : (isSelected ? AppColors.primary : AppColors.textMuted)),
                        ),
                      ]),
                    ),
                  ]),
                ),
                if (isSelected)
                  Positioned(
                    top: -6, right: 4,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                      child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    ),
  ]);
}



  Widget _buildCustomizationBanner(BuildContext context, int productId) {
    final hasSelections = CustomizationStore.hasSelections(productId);
    final summary       = CustomizationStore.summary(productId);
    final additionalCost = CustomizationStore.getAdditionalCost(productId);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomizationPickerPage(product: widget.bike),
          ),
        );
        if (result == true) setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasSelections ? AppColors.primaryGlow : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasSelections ? AppColors.primary.withOpacity(0.5) : AppColors.cardBorder,
          ),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: hasSelections ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.tune_rounded,
                color: hasSelections ? AppColors.primary : AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              hasSelections ? "Customized" : "Customize this bike",
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: hasSelections ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasSelections ? summary : "Pick colors, parts, and accessories",
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (additionalCost > 0)
              Text("+₱${additionalCost.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 2),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
          ]),
        ]),
      ),
    );
  }

     Widget _buildArButton(BuildContext context) {
  // TEMPORARY test model — replace with bike['ar_model']['model_file'] once confirmed working
  const testModelUrl = 'https://modelviewer.dev/shared-assets/models/Astronaut.glb';

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArViewerPage(
            modelUrl: testModelUrl,
            productName: widget.bike['product_name']?.toString() ?? 'Product',
          ),
        ),
      );
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.view_in_ar_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("View in AR",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
          SizedBox(height: 2),
          Text("See this in your space using your camera",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
      ]),
    ),
  );
}

}

