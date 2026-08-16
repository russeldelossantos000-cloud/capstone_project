<?php

use App\Controllers\AdminController;
use App\Controllers\ARModelController;
use App\Controllers\AuthController;
use App\Controllers\BrandController;
use App\Controllers\CartController;
use App\Controllers\CategoryController;
use App\Controllers\MessageController;
use App\Controllers\NotificationController;
use App\Controllers\OrderController;
use App\Controllers\ProductController;
use App\Controllers\ProductImageController;
use App\Controllers\ReviewController;
use App\Controllers\SSEController;
use App\Controllers\UserController;
use App\Controllers\UploadController;
use App\Middleware\AdminMiddleware;
use App\Middleware\AuthMiddleware;
use Slim\App;
use Slim\Routing\RouteCollectorProxy;
use App\Controllers\SupplierController;
use App\Controllers\DeliveryFeeController;
use App\Controllers\VariantController;

/** @var App $app */

// Auth
$app->group('/api/auth', function (RouteCollectorProxy $group) {
    $group->post('/register',            [AuthController::class, 'register']);
    $group->post('/login',               [AuthController::class, 'login']);
    $group->post('/admin/login',         [AuthController::class, 'adminLogin']);
    $group->get('/verify-email',         [AuthController::class, 'verifyEmail']);
    $group->post('/resend-verification', [AuthController::class, 'resendVerification']);
    $group->post('/forgot-password',     [AuthController::class, 'forgotPassword']);
    $group->post('/verify-reset-otp',    [AuthController::class, 'verifyResetOtp']);
    $group->post('/reset-password',      [AuthController::class, 'resetPassword']);
});

// Users
$app->group('/api/users', function (RouteCollectorProxy $group) {
    $group->get('/me',    [UserController::class, 'me']);
    $group->put('/me',    [UserController::class, 'update']);
    $group->delete('/me', [UserController::class, 'delete']);
})->add(new AuthMiddleware());

// Products
$app->group('/api/products', function (RouteCollectorProxy $group) {
    $group->get('',              [ProductController::class, 'index']);
    $group->get('/{id}',         [ProductController::class, 'show']);
    $group->get('/{id}/ar-model',[ARModelController::class, 'show']);
    $group->get('/{id}/images',  [ProductImageController::class, 'index']);
    $group->get('/{id}/reviews', [ReviewController::class, 'index']);
    $group->post('',                   [ProductController::class, 'store'])->add(new AdminMiddleware());
    $group->put('/{id}',               [ProductController::class, 'update'])->add(new AdminMiddleware());
    $group->delete('/{id}',            [ProductController::class, 'destroy'])->add(new AdminMiddleware());
    $group->post('/{id}/ar-model',     [ARModelController::class, 'store'])->add(new AdminMiddleware());
    $group->post('/{id}/images',       [ProductImageController::class, 'store'])->add(new AdminMiddleware());
    $group->post('/{id}/images/batch', [ProductImageController::class, 'storeBatch'])->add(new AdminMiddleware());
    $group->put('/{id}/unarchive', [ProductController::class, 'unarchive'])->add(new AdminMiddleware());
});

// Product Variants
$app->group('/api/products/{id}/variants', function (RouteCollectorProxy $group) {
    $group->get('', [VariantController::class, 'index']);
    $group->post('', [VariantController::class, 'store'])->add(new AdminMiddleware());
});
$app->group('/api/variants', function (RouteCollectorProxy $group) {
    $group->get('/{id}',            [VariantController::class, 'show']);
    $group->put('/{id}',            [VariantController::class, 'update'])->add(new AdminMiddleware());
    $group->delete('/{id}',         [VariantController::class, 'destroy'])->add(new AdminMiddleware());
    $group->put('/{id}/restore',    [VariantController::class, 'restore'])->add(new AdminMiddleware());
    $group->get('/{id}/ar-model',   [ARModelController::class, 'showForVariant']);
    $group->post('/{id}/ar-model',  [ARModelController::class, 'storeForVariant'])->add(new AdminMiddleware());
});

// Product images
$app->group('/api/product-images', function (RouteCollectorProxy $group) {
    $group->put('/{id}/set-primary', [ProductImageController::class, 'setPrimary']);
    $group->put('/{id}',             [ProductImageController::class, 'update']);
    $group->delete('/{id}',          [ProductImageController::class, 'destroy']);
})->add(new AdminMiddleware());

// AR Models
$app->group('/api/ar-models', function (RouteCollectorProxy $group) {
    $group->put('/{id}',    [ARModelController::class, 'update']);
    $group->delete('/{id}', [ARModelController::class, 'destroy']);
})->add(new AdminMiddleware());

// Categories
$app->group('/api/categories', function (RouteCollectorProxy $group) {
    $group->get('',      [CategoryController::class, 'index']);
    $group->get('/{id}', [CategoryController::class, 'show']);
    $group->post('',        [CategoryController::class, 'store'])->add(new AdminMiddleware());
    $group->put('/{id}',    [CategoryController::class, 'update'])->add(new AdminMiddleware());
    $group->delete('/{id}', [CategoryController::class, 'destroy'])->add(new AdminMiddleware());
});

// Brands
$app->group('/api/brands', function (RouteCollectorProxy $group) {
    $group->get('',      [BrandController::class, 'index']);
    $group->get('/{id}', [BrandController::class, 'show']);
    $group->post('',        [BrandController::class, 'store'])->add(new AdminMiddleware());
    $group->put('/{id}',    [BrandController::class, 'update'])->add(new AdminMiddleware());
    $group->delete('/{id}', [BrandController::class, 'destroy'])->add(new AdminMiddleware());
});

// Cart
$app->group('/api/cart', function (RouteCollectorProxy $group) {
    $group->get('',               [CartController::class, 'index']);
    $group->delete('',            [CartController::class, 'clear']);
    $group->post('/items',        [CartController::class, 'addItem']);
    $group->put('/items/{id}',    [CartController::class, 'updateItem']);
    $group->delete('/items/{id}', [CartController::class, 'removeItem']);
})->add(new AuthMiddleware());

// Orders
$app->group('/api/orders', function (RouteCollectorProxy $group) {
    $group->get('',      [OrderController::class, 'index']);
    $group->get('/{id}', [OrderController::class, 'show']);
    $group->post('',     [OrderController::class, 'store']);
    $group->put('/{id}/status', [OrderController::class, 'updateStatus'])->add(new AdminMiddleware());
    $group->put('/{id}/cancel', [OrderController::class, 'cancelOrder']);
    $group->put('/{id}/confirm-payment', [OrderController::class, 'confirmPayment'])->add(new AdminMiddleware());
    })->add(new AuthMiddleware());

// SSE stream (auth via ?token= query param — EventSource cannot set headers)
$app->get('/api/messages/stream', [SSEController::class, 'stream']);

// Messages — user-facing (AuthMiddleware: user tokens only)
$app->group('/api/messages', function (RouteCollectorProxy $group) {
    $group->get('',           [MessageController::class, 'index']);
    $group->get('/poll',      [SSEController::class,     'poll']);
    $group->get('/{userId}',  [MessageController::class, 'thread']);
    $group->post('',          [MessageController::class, 'store']);
    $group->put('/{id}/read', [MessageController::class, 'markRead']);
})->add(new AuthMiddleware());

// Notifications
$app->group('/api/notifications', function (RouteCollectorProxy $group) {
    $group->get('',           [NotificationController::class, 'index']);
    $group->put('/read-all',  [NotificationController::class, 'markAllRead']);
    $group->put('/{id}/read', [NotificationController::class, 'markRead']);
    $group->delete('/{id}',   [NotificationController::class, 'destroy']);
})->add(new AuthMiddleware());

// Reviews
$app->post('/api/products/{id}/reviews', [ReviewController::class, 'store'])->add(new AuthMiddleware());
$app->group('/api/reviews', function (RouteCollectorProxy $group) {
    $group->put('/{id}',    [ReviewController::class, 'update']);
    $group->delete('/{id}', [ReviewController::class, 'destroy']);
})->add(new AuthMiddleware());


// ── File Upload (admin only) ──────────────────────────────────────────────────
$app->group('/api/upload', function (RouteCollectorProxy $group) {
    $group->post('/product-image',   [UploadController::class, 'productImage']);
    $group->delete('/product-image', [UploadController::class, 'deleteImage']);
    $group->post('/chat-image', [UploadController::class, 'chatImage']);
})->add(new AdminMiddleware());

// Public delivery fee lookup — Flutter app uses this at checkout
$app->get('/api/delivery-fees/city', [DeliveryFeeController::class, 'getByCity']);

// Admin panel (AdminMiddleware — accepts admin tokens only)
$app->group('/api/admin', function (RouteCollectorProxy $group) {
    $group->get('/dashboard',      [AdminController::class, 'dashboard']);
    $group->get('/users',          [AdminController::class, 'users']);
    $group->get('/orders',         [AdminController::class, 'orders']);
    $group->get('/inventory',      [AdminController::class, 'inventory']);
    $group->get('/inventory/logs', [AdminController::class, 'inventoryLogs']);
    $group->post('/inventory/log', [AdminController::class, 'logInventory']);
    $group->get('/shop',           [AdminController::class, 'shop']);
    $group->put('/shop',           [AdminController::class, 'updateShop']);
    $group->get('/reviews',        [ReviewController::class, 'adminIndex']);

// Suppliers
    $group->get('/suppliers',              [SupplierController::class, 'index']);
    $group->get('/suppliers/{id}',         [SupplierController::class, 'show']);
    $group->post('/suppliers',             [SupplierController::class, 'store']);
    $group->put('/suppliers/{id}',         [SupplierController::class, 'update']);
    $group->delete('/suppliers/{id}',      [SupplierController::class, 'destroy']);
    $group->put('/suppliers/{id}/restore', [SupplierController::class, 'restore']);

    $group->get('/analytics', [AdminController::class, 'analytics']);

// Delivery Fees
    $group->get('/delivery-fees',               [DeliveryFeeController::class, 'index']);
    $group->put('/delivery-fees/{id}',          [DeliveryFeeController::class, 'update']);
    $group->put('/delivery-fees/zone/{zone}',   [DeliveryFeeController::class, 'updateZone']);

    // Admin message routes — separate from /api/messages (which uses AuthMiddleware).
    // These accept admin tokens so the admin panel can read and reply to messages.
    $group->get('/messages',          [MessageController::class, 'adminIndex']);
    $group->get('/messages/{userId}', [MessageController::class, 'adminThread']);
    $group->post('/messages',         [MessageController::class, 'adminSend']);
})->add(new AdminMiddleware());