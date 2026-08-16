import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 12);

 
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await AuthService.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  
  static Future<dynamic> _request(
    String method,
    String url, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    try {
      final headers = await _headers(auth: auth);
      final uri     = Uri.parse(url);
      http.Response res;

      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          res = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(_timeout);
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(_timeout);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw ApiException('Unknown method: $method');
      }

      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        throw ApiException('Invalid server response');
      }

      if (res.statusCode >= 200 && res.statusCode < 300) return data;

      final msg = (data is Map ? data['error'] ?? data['message'] : null) ?? 'Request failed';
      throw ApiException(msg.toString(), statusCode: res.statusCode);
    } on TimeoutException {
      throw ApiException('Request timed out. Check your network.');
    } on SocketException {
      throw ApiException('No connection. Check your server IP in constants.dart.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // AUTH
  // ════════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> login(String email, String password) async {
    return await _request('POST', '${AppConstants.authApiUrl}/login',
        body: {'email': email, 'password': password});
  }

 static Future<Map<String, dynamic>> register({
  required String firstName,
  required String lastName,
  required String email,
  required String password,
  String? phone,
  required bool privacyAccepted,
}) async {
  return await _request('POST', '${AppConstants.authApiUrl}/register', body: {
    'first_name': firstName,
    'last_name':  lastName,
    'email':      email,
    'password':   password,
    'phone': ?phone,
    'privacy_accepted': privacyAccepted,
  });
}

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await _request('POST', '${AppConstants.authApiUrl}/forgot-password',
        body: {'email': email});
  }

  static Future<Map<String, dynamic>> resetPassword(String token, String password) async {
    return await _request('POST', '${AppConstants.authApiUrl}/reset-password',
        body: {'token': token, 'password': password});
  }

  // Verifies the OTP is valid without consuming it (Step 2 gate).
  // Throws ApiException if the code is wrong or expired.
  static Future<Map<String, dynamic>> verifyResetOtp(String token) async {
    return await _request('POST', '${AppConstants.authApiUrl}/verify-reset-otp',
        body: {'token': token});
  }

  static Future<Map<String, dynamic>> resendVerification(String email) async {
    return await _request('POST', '${AppConstants.authApiUrl}/resend-verification',
        body: {'email': email});
  }

  static Future<Map<String, dynamic>> verifyEmail(String token) async {
    return await _request('GET', '${AppConstants.authApiUrl}/verify-email?token=$token');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PRODUCTS
  // ════════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    String? brandId,
    int? isCustomizable,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId;
    if (brandId != null) params['brand_id'] = brandId;
    if (isCustomizable != null) params['is_customizable'] = isCustomizable.toString();

    final uri = Uri.parse(AppConstants.productsApiUrl).replace(queryParameters: params.isNotEmpty ? params : null);
    final data = await _request('GET', uri.toString());
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<Map<String, dynamic>> getProduct(int id) async {
    return await _request('GET', '${AppConstants.productsApiUrl}/$id');
  }

  static Future<List<Map<String, dynamic>>> getProductImages(int productId) async {
    final data = await _request('GET', '${AppConstants.productsApiUrl}/$productId/images');
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<Map<String, dynamic>> getProductReviews(int productId) async {
    return await _request('GET', '${AppConstants.productsApiUrl}/$productId/reviews');
  }

  static Future<Map<String, dynamic>> submitReview(int productId, int rating, String? comment, {int? orderId}) async {
    return await _request('POST', '${AppConstants.productsApiUrl}/$productId/reviews',
        body: {
       'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        'order_id': ?orderId,
       },
        auth: true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORIES & BRANDS
  // ════════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final data = await _request('GET', AppConstants.categoriesApiUrl);
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<List<Map<String, dynamic>>> getBrands() async {
    final data = await _request('GET', AppConstants.brandsApiUrl);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CART
  // ════════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getCart() async {
    return await _request('GET', AppConstants.cartApiUrl, auth: true);
  }

  static Future<Map<String, dynamic>> addToCart(int productId, int quantity, {int? variantId}) async {
  final body = <String, dynamic>{'product_id': productId, 'quantity': quantity};
  if (variantId != null) body['variant_id'] = variantId;
  return await _request('POST', '${AppConstants.cartApiUrl}/items', body: body, auth: true);
}

  static Future<Map<String, dynamic>> updateCartItem(int itemId, int quantity) async {
    return await _request('PUT', '${AppConstants.cartApiUrl}/items/$itemId',
        body: {'quantity': quantity}, auth: true);
  }

  static Future<Map<String, dynamic>> removeCartItem(int itemId) async {
    return await _request('DELETE', '${AppConstants.cartApiUrl}/items/$itemId', auth: true);
  }

  static Future<Map<String, dynamic>> clearCart() async {
    return await _request('DELETE', AppConstants.cartApiUrl, auth: true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ORDERS
  // ════════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final data = await _request('GET', AppConstants.ordersApiUrl, auth: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<Map<String, dynamic>> getOrder(int id) async {
    return await _request('GET', '${AppConstants.ordersApiUrl}/$id', auth: true);
  }

  static Future<Map<String, dynamic>> cancelOrder(int id) async {
    return await _request('PUT', '${AppConstants.ordersApiUrl}/$id/cancel', auth: true);
}

  static Future<Map<String, dynamic>> placeOrder({
  required String paymentMethod,
  String? deliveryType,
  String? addressStreet,
  String? addressBarangay,
  String? addressCity,
  String? addressProvince,
  String? addressZipcode,
  String? addressLandmark,
  double? latitude,
  double? longitude,
}) async {
  final body = <String, dynamic>{'payment_method': paymentMethod};
  if (deliveryType != null) body['delivery_type'] = deliveryType;
  if (addressStreet != null) body['address_street'] = addressStreet;
  if (addressBarangay != null) body['address_barangay'] = addressBarangay;
  if (addressCity != null) body['address_city'] = addressCity;
  if (addressProvince != null) body['address_province'] = addressProvince;
  if (addressZipcode != null) body['address_zipcode'] = addressZipcode;
  if (addressLandmark != null) body['address_landmark'] = addressLandmark;
  if (latitude != null) body['latitude'] = latitude;
  if (longitude != null) body['longitude'] = longitude;
  return await _request('POST', AppConstants.ordersApiUrl, body: body, auth: true);
}

   static Future<Map<String, dynamic>> getDeliveryFeeByCity(String city) async {
  return await _request('GET', '${AppConstants.baseApiUrl}/delivery-fees/city?city=${Uri.encodeComponent(city)}');
  }

   static Future<Map<String, dynamic>> placeDirectOrder({
   required int productId,
   required int quantity,
   required String paymentMethod,
  int? variantId,
  String? deliveryType,
  String? addressStreet,
  String? addressBarangay,
  String? addressCity,
  String? addressProvince,
  String? addressZipcode,
  String? addressLandmark,
  double? latitude,
  double? longitude,
  Map<String, List<int>>? customizations,
  }) async {
  final body = <String, dynamic>{
    'product_id':     productId,
    'quantity':       quantity,
    'payment_method': paymentMethod,
  };
  if (variantId != null) body['variant_id'] = variantId;
  if (deliveryType != null) body['delivery_type'] = deliveryType;
  if (addressStreet != null) body['address_street'] = addressStreet;
  if (addressBarangay != null) body['address_barangay'] = addressBarangay;
  if (addressCity != null) body['address_city'] = addressCity;
  if (addressProvince != null) body['address_province'] = addressProvince;
  if (addressZipcode != null) body['address_zipcode'] = addressZipcode;
  if (addressLandmark != null) body['address_landmark'] = addressLandmark;
  if (latitude != null) body['latitude'] = latitude;
  if (longitude != null) body['longitude'] = longitude;
  if (customizations != null && customizations.isNotEmpty) {
    body['customizations'] = customizations;
  }
  return await _request('POST', AppConstants.ordersApiUrl, body: body, auth: true);
 }

  // ════════════════════════════════════════════════════════════════════════════
  // CUSTOMIZATIONS
  // ════════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getCustomizations() async {
    final data = await _request('GET', '${AppConstants.baseApiUrl}/customizations');
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<Map<String, dynamic>> getCustomizationWithOptions(int id) async {
    return await _request('GET', '${AppConstants.baseApiUrl}/customizations/$id');
  }

  static Future<List<Map<String, dynamic>>> getAllCustomizationsWithOptions() async {
    final groups = await getCustomizations();
    final result = <Map<String, dynamic>>[];
    for (final g in groups) {
      try {
        final full = await getCustomizationWithOptions(g['id'] as int);
        result.add(full);
      } catch (_) {
        result.add(g);
      }
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ════════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getNotifications() async {
    return await _request('GET', AppConstants.notifApiUrl, auth: true);
  }

  static Future<void> markNotificationRead(int id) async {
    await _request('PUT', '${AppConstants.notifApiUrl}/$id/read', auth: true);
  }

  static Future<void> markAllNotificationsRead() async {
    await _request('PUT', '${AppConstants.notifApiUrl}/read-all', auth: true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ════════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getMessages() async {
    final data = await _request('GET', AppConstants.messagesApiUrl, auth: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<List<Map<String, dynamic>>> getThread(int userId) async {
    final data = await _request('GET', '${AppConstants.messagesApiUrl}/$userId', auth: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<Map<String, dynamic>> sendMessage(int receiverId, String message) async {
    return await _request('POST', AppConstants.messagesApiUrl,
        body: {'receiver_id': receiverId, 'message': message}, auth: true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // USER PROFILE
  // ════════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getProfile() async {
    return await _request('GET', '${AppConstants.usersApiUrl}/me', auth: true);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await _request('PUT', '${AppConstants.usersApiUrl}/me', body: data, auth: true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // POLL (fallback for messages + notifications)
  // ════════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> poll(int lastId) async {
    return await _request('GET', '${AppConstants.messagesApiUrl}/poll?last_id=$lastId', auth: true);
  }
}