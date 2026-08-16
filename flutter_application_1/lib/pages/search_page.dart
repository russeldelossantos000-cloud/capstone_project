import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/api_service.dart';
import 'bikedetails_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();
  final _focus      = FocusNode();

  List<Map<String, dynamic>> _results    = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands     = [];
  List<Map<String, dynamic>> _allProducts = [];

  String  _selectedCategory = '';
  String  _selectedBrand    = '';
  String  _sortBy  = 'default';
  double  _minPrice = 0;
  double  _maxPrice = 500000;
  final bool    _loading  = false;
  bool    _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _focus.requestFocus();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getBrands(),
        ApiService.getProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories  = results[0];
        _brands      = results[1];
        _allProducts = results[2];
        _results     = _allProducts;
      });
    } catch (_) {}
  }

  void _onSearch() {
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _results = _allProducts.where((p) {
        final name  = (p['product_name'] ?? '').toString().toLowerCase();
        final catId = (p['category_id'] ?? '').toString();
        final brandId = (p['brand_id'] ?? '').toString();
        final price = double.tryParse(p['price']?.toString() ?? '0') ?? 0;

        return (q.isEmpty || name.contains(q)) &&
               (_selectedCategory.isEmpty || catId == _selectedCategory) &&
               (_selectedBrand.isEmpty    || brandId == _selectedBrand)  &&
               (price >= _minPrice && price <= _maxPrice);
      }).toList();

      switch (_sortBy) {
        case 'price_asc':
          _results.sort((a, b) => (double.tryParse(a['price']?.toString() ?? '0') ?? 0)
              .compareTo(double.tryParse(b['price']?.toString() ?? '0') ?? 0));
          break;
        case 'price_desc':
          _results.sort((a, b) => (double.tryParse(b['price']?.toString() ?? '0') ?? 0)
              .compareTo(double.tryParse(a['price']?.toString() ?? '0') ?? 0));
          break;
        case 'name':
          _results.sort((a, b) => (a['product_name'] ?? '').toString()
              .compareTo((b['product_name'] ?? '').toString()));
          break;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = '';
      _selectedBrand    = '';
      _sortBy   = 'default';
      _minPrice = 0;
      _maxPrice = 500000;
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _selectedCategory.isNotEmpty || _selectedBrand.isNotEmpty || _sortBy != 'default';

  String _imageUrl(Map<String, dynamic> bike) => AppConstants.imageUrl(bike['image']?.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _focus,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Search bikes, brands…",
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        actions: [
          Stack(children: [
            IconButton(
              icon: Icon(
                _filtersOpen ? Icons.tune_rounded : Icons.tune_rounded,
                color: _hasActiveFilters ? AppColors.primary : AppColors.textPrimary,
              ),
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            ),
            if (_hasActiveFilters) Positioned(
              right: 8, top: 8,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
          ]),
        ],
      ),
      body: Column(children: [
        // Filter panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: _filtersOpen ? null : 0,
          child: _filtersOpen ? _filterPanel() : const SizedBox.shrink(),
        ),

        // Results count bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            Text("${_results.length} results",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (_hasActiveFilters) GestureDetector(
              onTap: _clearFilters,
              child: const Row(children: [
                Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text("Clear filters", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),

        // Results
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              : _results.isEmpty
                  ? _emptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (_, i) => _bikeCard(_results[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _filterPanel() => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Category
      _filterLabel("Category"),
      const SizedBox(height: 8),
      _chipRow([
        _chip("All", "", _selectedCategory == '', () { setState(() => _selectedCategory = ''); _applyFilters(); }),
        ..._categories.map((c) => _chip(c['category_name'].toString(), c['id'].toString(),
            _selectedCategory == c['id'].toString(), () { setState(() => _selectedCategory = c['id'].toString()); _applyFilters(); })),
      ]),
      const SizedBox(height: 12),

      // Brand
      _filterLabel("Brand"),
      const SizedBox(height: 8),
      _chipRow([
        _chip("All", "", _selectedBrand == '', () { setState(() => _selectedBrand = ''); _applyFilters(); }),
        ..._brands.map((b) => _chip(b['brand_name'].toString(), b['id'].toString(),
            _selectedBrand == b['id'].toString(), () { setState(() => _selectedBrand = b['id'].toString()); _applyFilters(); })),
      ]),
      const SizedBox(height: 12),

      // Sort
      _filterLabel("Sort by"),
      const SizedBox(height: 8),
      _chipRow([
        _chip("Default",       "default",    _sortBy == 'default',    () { setState(() => _sortBy = 'default'); _applyFilters(); }),
        _chip("Price ↑",       "price_asc",  _sortBy == 'price_asc',  () { setState(() => _sortBy = 'price_asc'); _applyFilters(); }),
        _chip("Price ↓",       "price_desc", _sortBy == 'price_desc', () { setState(() => _sortBy = 'price_desc'); _applyFilters(); }),
        _chip("Name A–Z",      "name",       _sortBy == 'name',       () { setState(() => _sortBy = 'name'); _applyFilters(); }),
      ]),
    ]),
  );

  Widget _filterLabel(String text) => Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5));

  Widget _chipRow(List<Widget> chips) => Wrap(spacing: 8, runSpacing: 8, children: chips);

  Widget _chip(String label, String value, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: active ? Colors.black : AppColors.textMuted,
          )),
        ),
      );

  Widget _bikeCard(Map<String, dynamic> bike) {
    final url = _imageUrl(bike);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BikeDetailsPage(bike: bike, imageUrl: url),
      )),
      child: Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity,
                    placeholder: (_, _) => Container(color: AppColors.surface, child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                    errorWidget: (_, _, _) => Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 44)))
                : Container(color: AppColors.surface, child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 44)),
          )),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((bike['category_name'] ?? '').toString().toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text(bike['product_name'] ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text("₱${bike['price']}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 56),
    const SizedBox(height: 14),
    const Text("No bikes found", style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    const Text("Try different keywords or filters", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    if (_hasActiveFilters) ...[
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _clearFilters,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text("Clear Filters", style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  ]));
}
