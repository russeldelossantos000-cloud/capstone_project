import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'bikedetails_page.dart';
import 'cart_page.dart';
import 'orders_page.dart';
import 'profile_page.dart';
import 'notifications_page.dart';
import 'messages_page.dart';
import 'search_page.dart';

import 'parts_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _tab = 0;
  int _cartCount   = 0;
  int _unreadNotif = 0;
  final int _unreadMsgs  = 0;

  List<Map<String, dynamic>> _allBikes   = [];
  List<Map<String, dynamic>> _filtered   = [];
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = '';
  bool _loading = true, _error = false;
  final _searchCtrl = TextEditingController();

  late AnimationController _anim;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _fetchAll();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _anim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() { _loading = true; _error = false; });
    try {
      final results = await Future.wait([
        ApiService.getProducts(),
        ApiService.getCategories(),
        ApiService.getCart().catchError((_) => <String, dynamic>{}),
        ApiService.getNotifications().catchError((_) => <String, dynamic>{}),
      ]);

      final bikes  = results[0] as List<Map<String, dynamic>>;
      final cats   = results[1] as List<Map<String, dynamic>>;
      final cart   = results[2] as Map<String, dynamic>;
      final notifs = results[3] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _allBikes    = bikes;
        _categories  = cats;
        _cartCount   = (cart['items'] as List?)?.length ?? 0;
        _unreadNotif = notifs['unread_count'] as int? ?? 0;
        _loading     = false;
        _filter();
      });
      _anim.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allBikes.where((b) {
        final name  = (b['product_name'] ?? '').toString().toLowerCase();
        final catId = (b['category_id'] ?? '').toString();
        return (q.isEmpty || name.contains(q)) &&
               (_selectedCategory.isEmpty || catId == _selectedCategory);
      }).toList();
    });
  }

String _imageUrl(Map<String, dynamic> bike) => AppConstants.imageUrl(bike['image']?.toString());
  void _refreshCartCount() async {
    try {
      final cart = await ApiService.getCart();
      if (mounted) setState(() => _cartCount = (cart['items'] as List?)?.length ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _tab, children: [
        _catalogView(),
        const PartsPage(),
        const MessagesPage(),
        const OrdersPage(),
        const ProfilePage(),
        
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _catalogView() {
    return NestedScrollView(
      headerSliverBuilder: (_, _) => [
        SliverAppBar(
          backgroundColor: AppColors.surface,
          floating: true, pinned: true,
          title: RichText(text: const TextSpan(children: [
            TextSpan(text: "MICO'S BIKE ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary, letterSpacing: 2)),
            TextSpan(text: "SHOP",   style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary, letterSpacing: 2)),
          ])),
          actions: [
            // Search
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
            ),
            // Cost Estimator
          
            // Cart
            Stack(children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
                  _refreshCartCount();
                },
              ),
              if (_cartCount > 0) Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(child: Text('$_cartCount', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w800))),
                ),
              ),
            ]),
            // Notifications
            Stack(children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                  setState(() => _unreadNotif = 0);
                },
              ),
              if (_unreadNotif > 0) Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: Center(child: Text('$_unreadNotif', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))),
                ),
              ),
            ]),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _categories.length + 1,
                itemBuilder: (_, i) {
                  final isAll   = i == 0;
                  final catId   = isAll ? '' : _categories[i - 1]['id'].toString();
                  final catName = isAll ? 'All' : (_categories[i - 1]['category_name'] ?? '').toString();
                  final active  = _selectedCategory == catId;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedCategory = catId); _filter(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder),
                      ),
                      child: Center(child: Text(catName, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: active ? Colors.black : AppColors.textMuted,
                      ))),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
      body: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    if (_error) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 52),
      const SizedBox(height: 12),
      const Text("Could not load products", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _fetchAll,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text("Retry"),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ]));
    }
    if (_filtered.isEmpty) return const Center(child: Text("No bikes found", style: TextStyle(color: AppColors.textMuted)));

    return FadeTransition(
      opacity: _fade,
      child: RefreshIndicator(
        color: AppColors.primary, backgroundColor: AppColors.card,
        onRefresh: _fetchAll,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
          ),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _bikeCard(_filtered[i]),
        ),
      ),
    );
  }

Widget _bikeCard(Map<String, dynamic> bike) {
  final url      = _imageUrl(bike);
  final name     = bike['product_name']?.toString() ?? '';
  final price    = bike['price']?.toString() ?? '0';
  final catName  = bike['category_name']?.toString() ?? '';
  final stock    = int.tryParse(bike['stock']?.toString() ?? '0') ?? 0;
  final isCustom = bike['is_customizable'] == 1 || bike['is_customizable'] == true;

  debugPrint('🖼 $name → raw: ${bike['image']} → url: $url');
  
  return GestureDetector(
    onTap: () async {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => BikeDetailsPage(bike: bike, imageUrl: url),
      ));
      _refreshCartCount();
    },
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.card, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: AppColors.cardBorder)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image + badges (fixed Stack positioning)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url, 
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.surface, 
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary, 
                                strokeWidth: 2
                              )
                            )
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surface, 
                            child: const Icon(
                              Icons.directions_bike_rounded, 
                              color: AppColors.primary, 
                              size: 44
                            )
                          ),
                        )
                      : Container(
                          color: AppColors.surface, 
                          child: const Icon(
                            Icons.directions_bike_rounded, 
                            color: AppColors.primary, 
                            size: 44
                          )
                        ),
                ),
              ),
              // Custom badge
              if (isCustom) Positioned(
                top: 8, 
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary, 
                    borderRadius: BorderRadius.circular(6)
                  ),
                  child: const Text(
                    "CUSTOM", 
                    style: TextStyle(
                      fontSize: 9, 
                      color: Colors.black, 
                      fontWeight: FontWeight.w800, 
                      letterSpacing: 0.5
                    )
                  ),
                ),
              ),
              // Out of stock overlay
              if (stock == 0) Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Text(
                        "OUT OF STOCK",
                        style: TextStyle(
                          fontSize: 10, 
                          color: Colors.white, 
                          fontWeight: FontWeight.w800, 
                          letterSpacing: 1
                        )
                      )
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Info section
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (catName.isNotEmpty)
                  Text(
                    catName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.w700, 
                      color: AppColors.primary, 
                      letterSpacing: 1.5
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w700, 
                    color: AppColors.textPrimary
                  ),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "₱$price",
                      style: const TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.w900, 
                        color: AppColors.primary
                      ),
                    ),
                    Container(
                      width: 28, 
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGlow, 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded, 
                        color: AppColors.primary, 
                        size: 12
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _bottomNav() => Container(
    decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.divider))),
    child: BottomNavigationBar(
      backgroundColor: Colors.transparent, elevation: 0,
      selectedItemColor: AppColors.primary, unselectedItemColor: AppColors.textMuted,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      type: BottomNavigationBarType.fixed,
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: "Catalog"),
        const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: "Parts"),
        BottomNavigationBarItem(
          icon: Stack(children: [
            const Icon(Icons.chat_bubble_outline_rounded),
            if (_unreadMsgs > 0) Positioned(right: 0, top: 0, child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            )),
          ]),
          activeIcon: const Icon(Icons.chat_bubble_rounded),
          label: "Messages",
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.history), activeIcon: Icon(Icons.history_outlined), label: "Orders"),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: "Profile"),
        
      ],
    ),
  );
}
