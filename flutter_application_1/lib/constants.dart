import 'package:flutter/material.dart';

class AppConstants {
 
  static const String serverIp = "https://capstone-production-6d44.up.railway.app/api";
  static const String imageBaseUrl = "https://capstone-production-6d44.up.railway.app/api/uploads/products";

  static String get baseApiUrl =>
      "https://capstone-production-6d44.up.railway.app/api";

  static String get productsApiUrl    => "$baseApiUrl/products";
  static String get categoriesApiUrl  => "$baseApiUrl/categories";
  static String get brandsApiUrl      => "$baseApiUrl/brands";
  static String get cartApiUrl        => "$baseApiUrl/cart";
  static String get ordersApiUrl      => "$baseApiUrl/orders";
  static String get authApiUrl        => "$baseApiUrl/auth";
  static String get messagesApiUrl    => "$baseApiUrl/messages";
  static String get notifApiUrl       => "$baseApiUrl/notifications";
  static String get usersApiUrl       => "$baseApiUrl/users";

 static String imageUrl(String? path) {
  if (path == null || path.trim().isEmpty) return '';
  final raw = path.trim();
  if (raw.startsWith('http')) return raw;
  final clean = raw.startsWith('/') ? raw.substring(1) : raw;
  final base = serverIp.replaceFirst('/api', '');
  return '$base/$clean';
}
}

class AppColors {
  static const Color background   = Color(0xFF0A0A0A);
  static const Color surface      = Color(0xFF131313);
  static const Color card         = Color(0xFF1C1C1C);
  static const Color cardBorder   = Color(0xFF2A2A2A);
  static const Color primary      = Color(0xFFFF6B00);
  static const Color primaryGlow  = Color(0x33FF6B00);
  static const Color primaryLight = Color(0xFFFF8C38);
  static const Color textPrimary  = Color(0xFFFFFFFF);
  static const Color textMuted    = Color(0xFF7A7A7A);
  static const Color divider      = Color(0xFF252525);
  static const Color error        = Color(0xFFFF4C4C);
  static const Color success      = Color(0xFF2ECC71);
  static const Color warning      = Color(0xFFEAB308);
  static const Color info         = Color(0xFF3B82F6);
}


class ShopInfo {
  static const String name          = "DI2's Mico's Bike Shop";
  static const String address       = "Central Balanga City, Bataan, Philippines";
  static const String tagline       = " ";
  static const String phone         = " ";
  static const String email         = "micos.bikeshop@email.com";
  static const String facebook      = "https://facebook.com/micosbikeshop";
  static const double latitude      = 14.6760;
  static const double longitude     = 120.5374;
  static const String mapsUrl       = "https://maps.google.com/?q=14.6760,120.5374";

  
  static const int adminUserId      = 2;
  static const String adminName     = "smok";

  static const List<Map<String, String>> hours = [
    {'day': 'Monday – Friday', 'time': '8:00 AM – 6:00 PM'},
    {'day': 'Saturday',        'time': '8:00 AM – 5:00 PM'},
    {'day': 'Sunday',          'time': 'Closed'},
  ];
}
