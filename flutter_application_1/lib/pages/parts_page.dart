import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/api_service.dart';
import 'bikedetails_page.dart';

/// Parts & Accessories page — shows products filtered by category,
/// with a horizontal category bar at the top.
class PartsPage extends StatefulWidget {
  const PartsPage({super.key});
  @override
  State<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products   = [];
  List<Map<String, dynamic>> _filtered   = [];
  String _selectedCatId   = '';
  String _selectedCatName = 'All Parts';
  bool _loading = true;

  // Part-type keywords to identify parts vs complete bikes
  static const _bikeKeywords = ['bicycle', 'cycle', 'mtb', 'road bike', 'bmx','mountain bikes', 'road bikes', 'electric bike', 'folding bike', 'hybrid bike', 'cruiser bike', 'kids bike'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Filter out complete bikes, keeping only parts & accessories
  /// Filter out complete bikes, keeping only parts & accessories
bool _isPart(Map<String, dynamic> product) {
  final categoryName = (product['category_name'] ?? '').toString().toLowerCase();
  
  // If category contains any bike keywords, it's likely a complete bike category
  for (final keyword in _bikeKeywords) {
    if (categoryName.contains(keyword.toLowerCase())) {
      return false;
    }
  }
  return true;
}

 Future<void> _load() async {
  setState(() => _loading = true);
  try {
    final results = await Future.wait([ApiService.getCategories(), ApiService.getProducts()]);
    final allCats = results[0];
    final prods   = results[1];

    if (mounted) {
      setState(() {
        // Filter categories - hide any bike-related categories
        _categories = allCats.where((cat) {
          final catName = (cat['category_name'] ?? '').toString().toLowerCase();
          for (final keyword in _bikeKeywords) {
            if (catName.contains(keyword.toLowerCase())) {
              return false; // Hide bike categories
            }
          }
          return true; // Show parts categories
        }).toList();

        // Filter products - only keep products from parts categories
        _products = prods.where((p) {
          final catName = (p['category_name'] ?? '').toString().toLowerCase();
          for (final keyword in _bikeKeywords) {
            if (catName.contains(keyword.toLowerCase())) {
              return false; // Hide bike products
            }
          }
          return true; // Show parts products
        }).toList();

        _loading = false;
        _applyFilter();
      });
    }
  } catch (_) {
    if (mounted) setState(() => _loading = false);
  }
}

  void _applyFilter() {
    setState(() {
      if (_selectedCatId.isEmpty) {
        _filtered = _products;
      } else {
        _filtered = _products
            .where((p) => p['category_id'].toString() == _selectedCatId)
            .toList();
      }
    });
  }

  String _imageUrl(Map<String, dynamic> bike) => AppConstants.imageUrl(bike['image']?.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Parts & Accessories",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary)),
          Text("${_filtered.length} items",
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 50,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: _loading ? const SizedBox.shrink() : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length + 1,
              itemBuilder: (_, i) {
                final isAll   = i == 0;
                final catId   = isAll ? '' : _categories[i - 1]['id'].toString();
                final catName = isAll ? 'All' : (_categories[i - 1]['category_name'] ?? '').toString();
                final active  = _selectedCatId == catId;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCatId   = catId;
                      _selectedCatName = isAll ? 'All Parts' : catName;
                    });
                    _applyFilter();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder),
                    ),
                    child: Center(child: Text(catName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: active ? Colors.black : AppColors.textMuted))),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _filtered.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: AppColors.primary, backgroundColor: AppColors.card,
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12,
                      mainAxisSpacing: 12, childAspectRatio: 0.72,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _partCard(_filtered[i]),
                  ),
                ),
    );
  }

  Widget _partCard(Map<String, dynamic> p) {
    final url      = _imageUrl(p);
    final name     = p['product_name']?.toString() ?? '';
    final price    = p['price']?.toString() ?? '0';
    final catName  = p['category_name']?.toString() ?? '';
    final stock    = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
    final isCustom = p['is_customizable'] == 1 || p['is_customizable'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BikeDetailsPage(bike: p, imageUrl: url),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image + badge
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 120, width: double.infinity,
                child: url.isNotEmpty
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _placeholder())
                    : _placeholder(),
              ),
            ),
            if (isCustom) Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                child: const Text("CUSTOM", style: TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),
            if (stock == 0) Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  color: Colors.black54,
                  child: const Center(child: Text("OUT OF STOCK",
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1))),
                ),
              ),
            ),
          ]),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (catName.isNotEmpty)
                Text(catName.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.primary, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text(name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Text("₱$price",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                const Spacer(),
                Text("$stock left",
                    style: TextStyle(fontSize: 10, color: stock < 5 ? AppColors.error : AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.surface,
    child: const Center(child: Icon(Icons.settings_outlined, color: AppColors.primary, size: 40)),
  );

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.settings_outlined, color: AppColors.textMuted, size: 56),
    const SizedBox(height: 14),
    Text("No items in '$_selectedCatName'",
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
    const SizedBox(height: 6),
    const Text("Try a different category", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
  ]));
}