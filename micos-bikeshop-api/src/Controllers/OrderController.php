<?php

namespace App\Controllers;

use App\Config\Database;
use App\Controllers\NotificationController;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Services\InventoryService;

class OrderController
{
    // GET /api/orders
    public function index(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();

        $stmt = $db->prepare('
            SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC
        ');
        $stmt->execute([$userId]);

        return $this->json($response, $stmt->fetchAll());
    }

    // GET /api/orders/{id}
    public function show(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();

        $stmt = $db->prepare('SELECT * FROM orders WHERE id = ? AND user_id = ?');
        $stmt->execute([$args['id'], $userId]);
        $order = $stmt->fetch();

        if (!$order) {
            return $this->json($response, ['error' => 'Order not found.'], 404);
        }

        // Load order items
        $items = $db->prepare("
            SELECT oi.*, p.product_name, p.image,
           pv.variant_type, pv.variant_value
    FROM order_items oi
    JOIN products p ON oi.product_id = p.id
    LEFT JOIN product_variants pv ON oi.variant_id = pv.id
    WHERE oi.order_id = ?
        ");
        $items->execute([$args['id']]);
        $order['items'] = $items->fetchAll();

        return $this->json($response, $order);
    }

    // POST /api/orders
    public function store(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();

        $required = ['payment_method'];
        foreach ($required as $f) {
        if (empty($data[$f])) {
         return $this->json($response, ['error' => "Field '{$f}' is required."], 422);
        }
     }

       if (!in_array($data['payment_method'], ['cash_on_delivery', 'cash_on_pickup'], true)) {
        return $this->json($response, ['error' => "payment_method must be 'cash_on_delivery' or 'cash_on_pickup'."], 422);
     }

        // ── Direct order (Order Now — skips cart) ────────────────────────────────
         if (!empty($data['product_id']) && !empty($data['quantity'])) {
           return $this->storeDirect($request, $response, $userId, $data, $db);
}
        // Fetch cart items
        $cartStmt = $db->prepare('SELECT id FROM carts WHERE user_id = ?');
        $cartStmt->execute([$userId]);
        $cart = $cartStmt->fetch();

        if (!$cart) {
            return $this->json($response, ['error' => 'Cart is empty.'], 400);
        }

        $itemsStmt = $db->prepare('
    SELECT ci.product_id, ci.variant_id, ci.quantity, p.price AS base_price,
           pv.price_adjustment, pv.stock AS variant_stock, p.stock AS product_stock
    FROM cart_items ci
    JOIN products p ON ci.product_id = p.id
    LEFT JOIN product_variants pv ON ci.variant_id = pv.id
    WHERE ci.cart_id = ?
');
        $itemsStmt->execute([$cart['id']]);
        $cartItems = $itemsStmt->fetchAll();

        if (empty($cartItems)) {
            return $this->json($response, ['error' => 'Cart is empty.'], 400);
        }

        
        // Validate stock — variant stock if variant chosen, else product stock
foreach ($cartItems as $item) {
    $available = $item['variant_id'] ? (int) $item['variant_stock'] : (int) $item['product_stock'];
    if ($item['quantity'] > $available) {
        return $this->json($response, [
            'error' => "Insufficient stock for product ID {$item['product_id']}.",
        ], 409);
    }
}

$totalAmount = array_sum(array_map(
    fn($i) => $i['quantity'] * ((float) $i['base_price'] + (float) ($i['price_adjustment'] ?? 0)),
    $cartItems
));

        $refNumber    = 'ORD-' . strtoupper(bin2hex(random_bytes(6)));
        $delivery     = $this->extractDeliveryData($data);
        $deliveryFee  = $this->getDeliveryFee($db, $delivery['delivery_type'], $delivery['address_city']);
        $totalAmount  = round($totalAmount + $deliveryFee, 2);

        $db->beginTransaction();

        try {
            // Create order
           $db->prepare('
    INSERT INTO orders (
        user_id, total_amount, delivery_fee, status, payment_method, payment_status, reference_number,
        delivery_type, delivery_address, address_street, address_barangay,
        address_city, address_province, address_zipcode, address_landmark,
        latitude, longitude
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
')->execute([
    $userId,
    $totalAmount,
    $deliveryFee,
    'pending',
    $data['payment_method'],
    'unpaid',
    $refNumber,
    $delivery['delivery_type'],
    $delivery['delivery_address'],
    $delivery['address_street'],
    $delivery['address_barangay'],
    $delivery['address_city'],
    $delivery['address_province'],
    $delivery['address_zipcode'],
    $delivery['address_landmark'],
    $delivery['latitude'],
    $delivery['longitude'],
]);
            $orderId = (int) $db->lastInsertId();

            // Insert order items & deduct stock
            foreach ($cartItems as $item) {
    $unitPrice = (float) $item['base_price'] + (float) ($item['price_adjustment'] ?? 0);

    $db->prepare('
        INSERT INTO order_items (order_id, product_id, variant_id, quantity, price)
        VALUES (?, ?, ?, ?, ?)
    ')->execute([$orderId, $item['product_id'], $item['variant_id'], $item['quantity'], $unitPrice]);

    InventoryService::adjustStock(
        productId: $item['product_id'],
        variantId: $item['variant_id'],
        changeType: 'OUT',
        quantity: $item['quantity'],
        transactionType: 'online_order',
        reason: "Order #{$orderId}",
        reference: $refNumber,
        loggedBy: 'System'
    );
}

            // Clear cart
            $db->prepare('DELETE FROM cart_items WHERE cart_id = ?')->execute([$cart['id']]);

            $db->commit();

// Notify admin panel via Firestore
    $this->writeAdminNotification([
    'type'       => 'new_order',
    'category'   => 'orders',
    'message'    => "New order {$refNumber} placed",
    'reference'  => $refNumber,
    'record_id'  => $orderId,
    'read'       => false,
  ]);

     return $this->json($response, [
    'message'          => 'Order placed successfully.',
    'order_id'         => $orderId,
    'reference_number' => $refNumber,
    'total_amount'     => round($totalAmount, 2),
    ], 201);


        } catch (\Exception $e) {
            $db->rollBack();
            return $this->json($response, ['error' => 'Order failed: ' . $e->getMessage()], 500);
        }
    }

    // PUT /api/orders/{id}/status  [admin]
    public function updateStatus(Request $request, Response $response, array $args): Response
    {
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();

        $validStatuses  = ['pending', 'processing', 'shipped', 'delivered', 'cancelled'];
        $validPayments  = ['unpaid', 'paid', 'refunded'];

        $fields = [];
        $values = [];

        if (!empty($data['status'])) {
    if (!in_array($data['status'], $validStatuses, true)) {
        return $this->json($response, ['error' => 'Invalid status value.'], 422);
    }
    $fields[] = 'status = ?';
    $values[] = $data['status'];

    // Store cancellation reason when status is set to cancelled
    if ($data['status'] === 'cancelled') {
    $fields[] = 'cancellation_reason = ?';
    $values[] = $data['cancellation_reason'] ?? null;
    $fields[] = 'cancelled_by = ?';
    $values[] = 'admin';
    }
   }

        if (!empty($data['payment_status'])) {
            if (!in_array($data['payment_status'], $validPayments, true)) {
                return $this->json($response, ['error' => 'Invalid payment_status value.'], 422);
            }
            $fields[] = 'payment_status = ?';
            $values[] = $data['payment_status'];
        }

       // Add before the $fields building block:
         if (!empty($data['status']) && $data['status'] === 'cancelled') {
    $orderRef = $db->prepare('SELECT reference_number FROM orders WHERE id = ?');
    $orderRef->execute([$args['id']]);
    $refNum = $orderRef->fetchColumn();

    $items = $db->prepare('SELECT product_id, variant_id, quantity FROM order_items WHERE order_id = ?');
    $items->execute([$args['id']]);
    foreach ($items->fetchAll() as $item) {
        InventoryService::adjustStock(
            productId: $item['product_id'],
            variantId: $item['variant_id'],
            changeType: 'IN',
            quantity: $item['quantity'],
            transactionType: 'cancelled_order',
            reason: "Order #{$args['id']} cancelled by admin",
            reference: $refNum,
            loggedBy: $request->getAttribute('username') ?? 'Admin'
        );
    }
  }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        $db->prepare('UPDATE orders SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($values);

        // Fire in-app + email notification to the customer
        $order = $db->prepare('SELECT user_id, reference_number, status, payment_status FROM orders WHERE id = ?');
        $order->execute([$args['id']]);
        $o = $order->fetch();
        if ($o) {
            NotificationController::orderStatusChanged(
                (int) $o['user_id'],
                (int) $args['id'],
                $o['reference_number'],
                $data['status']         ?? $o['status'],
                $data['payment_status'] ?? $o['payment_status']
            );
        }

        return $this->json($response, ['message' => 'Order status updated.']);
    }

    // PUT /api/orders/{id}/cancel  [user]
public function cancelOrder(Request $request, Response $response, array $args): Response
{
    $userId = $request->getAttribute('user_id');
    $data   = $request->getParsedBody();
    $db     = Database::getConnection();

    // Verify order belongs to this user and is still pending
    $stmt = $db->prepare('SELECT * FROM orders WHERE id = ? AND user_id = ?');
    $stmt->execute([$args['id'], $userId]);
    $order = $stmt->fetch();

    if (!$order) {
        return $this->json($response, ['error' => 'Order not found.'], 404);
    }

    if (!in_array($order['status'], ['pending'], true)) {
        return $this->json($response, [
            'error' => 'Only pending orders can be cancelled.',
        ], 409);
    }

    $items = $db->prepare('SELECT product_id, variant_id, quantity FROM order_items WHERE order_id = ?');
$items->execute([$args['id']]);
foreach ($items->fetchAll() as $item) {
    InventoryService::adjustStock(
        productId: $item['product_id'],
        variantId: $item['variant_id'],
        changeType: 'IN',
        quantity: $item['quantity'],
        transactionType: 'cancelled_order',
        reason: "Order #{$args['id']} cancelled by user",
        reference: $order['reference_number'],
        loggedBy: 'System'
    );
}

    $reason = $data['cancellation_reason'] ?? null;

    $db->prepare("UPDATE orders SET status = 'cancelled', cancellation_reason = ?,cancelled_by = 'customer'WHERE id = ?")
        ->execute([$reason, $args['id']]);

    NotificationController::orderStatusChanged(
        (int) $order['user_id'],
        (int) $args['id'],
        $order['reference_number'],
        'cancelled',
        $order['payment_status']
    );

    return $this->json($response, ['message' => 'Order cancelled successfully.']);
}

// PUT /api/orders/{id}/gcash-receipt  [user]


// PUT /api/orders/{id}/confirm-payment  [admin]
// PUT /api/orders/{id}/confirm-payment  [admin]
// Marks a Cash on Delivery / Cash on Pickup order as paid.
public function confirmPayment(Request $request, Response $response, array $args): Response
{
    $db   = Database::getConnection();
    $stmt = $db->prepare("SELECT * FROM orders WHERE id = ?");
    $stmt->execute([$args['id']]);
    $order = $stmt->fetch();

    if (!$order) {
        return $this->json($response, ['error' => 'Order not found.'], 404);
    }

    if ($order['payment_status'] === 'paid') {
        return $this->json($response, ['error' => 'This order is already marked as paid.'], 409);
    }

    if ($order['status'] === 'cancelled') {
        return $this->json($response, ['error' => 'Cannot mark a cancelled order as paid.'], 409);
    }

    $db->prepare("UPDATE orders SET payment_status = 'paid' WHERE id = ?")
       ->execute([$args['id']]);

    NotificationController::orderStatusChanged(
        (int) $order['user_id'],
        (int) $args['id'],
        $order['reference_number'],
        $order['status'],
        'paid'
    );

    return $this->json($response, ['message' => 'Payment confirmed. Order marked as paid.']);
}

    private function storeDirect(Request $request, Response $response, int $userId, array $data, \PDO $db): Response
{
    $productId = (int) $data['product_id'];
    $variantId = !empty($data['variant_id']) ? (int) $data['variant_id'] : null;
    $quantity  = (int) $data['quantity'];

    $p = $db->prepare('SELECT id, price FROM products WHERE id = ?');
    $p->execute([$productId]);
    $product = $p->fetch();

    if (!$product) {
        return $this->json($response, ['error' => 'Product not found.'], 404);
    }

    $unitPrice   = (float) $product['price'];
    $availableStock = 0;

    if ($variantId !== null) {
        $v = $db->prepare('SELECT id, price_adjustment, stock FROM product_variants WHERE id = ? AND product_id = ? AND is_archived = 0');
        $v->execute([$variantId, $productId]);
        $variant = $v->fetch();
        if (!$variant) {
            return $this->json($response, ['error' => 'Variant not found for this product.'], 404);
        }
        $unitPrice      = $unitPrice + (float) $variant['price_adjustment'];
        $availableStock = (int) $variant['stock'];
    } else {
        $s = $db->prepare('SELECT stock FROM products WHERE id = ?');
        $s->execute([$productId]);
        $availableStock = (int) $s->fetch()['stock'];
    }

    if ($quantity > $availableStock) {
        return $this->json($response, ['error' => 'Insufficient stock.'], 409);
    }
    if ($quantity < 1) {
        return $this->json($response, ['error' => 'Quantity must be at least 1.'], 422);
    }
    if (!in_array($data['payment_method'], ['cash_on_delivery', 'cash_on_pickup'], true)) {
        return $this->json($response, ['error' => "payment_method must be 'cash_on_delivery' or 'cash_on_pickup'."], 422);
    }

    $subtotal = round($unitPrice * $quantity, 2);
    $delivery     = $this->extractDeliveryData($data);
    $deliveryFee  = $this->getDeliveryFee($db, $delivery['delivery_type'], $delivery['address_city']);
    $totalAmount  = round($subtotal + $deliveryFee, 2);
    $refNumber    = 'ORD-' . strtoupper(bin2hex(random_bytes(6)));

    $db->beginTransaction();

    try {
       $db->prepare('
    INSERT INTO orders (
        user_id, total_amount, delivery_fee, status, payment_method, payment_status, reference_number,
        delivery_type, delivery_address, address_street, address_barangay,
        address_city, address_province, address_zipcode, address_landmark,
        latitude, longitude
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
   ')->execute([
    $userId, $totalAmount, $deliveryFee, 'pending', $data['payment_method'], 'unpaid', $refNumber,
    $delivery['delivery_type'],
    $delivery['delivery_address'],
    $delivery['address_street'],
    $delivery['address_barangay'],
    $delivery['address_city'],
    $delivery['address_province'],
    $delivery['address_zipcode'],
    $delivery['address_landmark'],
    $delivery['latitude'],
    $delivery['longitude'],
   ]);

        $orderId     = (int) $db->lastInsertId();

        $db->prepare('
    INSERT INTO order_items (order_id, product_id, variant_id, quantity, price)
    VALUES (?, ?, ?, ?, ?)
')->execute([$orderId, $productId, $variantId, $quantity, $unitPrice]);

// Deduct stock + log via centralized service — variant stock if variant chosen, else product stock
InventoryService::adjustStock(
    productId: $productId,
    variantId: $variantId,
    changeType: 'OUT',
    quantity: $quantity,
    transactionType: 'online_order',
    reason: "Direct order #{$orderId}",
    reference: $refNumber,
    loggedBy: 'System'
);

        $db->commit();

    $this->writeAdminNotification([
    'type'       => 'new_order',
    'category'   => 'orders',
    'message'    => "New order {$refNumber} placed",
    'reference'  => $refNumber,
    'record_id'  => $orderId,
    'read'       => false,
    ]);

    return $this->json($response, [
    'message'          => 'Order placed successfully.',
    'order_id'         => $orderId,
    'reference_number' => $refNumber,
    'total_amount'     => $totalAmount,
     ], 201);
    } catch (\Exception $e) {
        $db->rollBack();
        return $this->json($response, ['error' => 'Order failed: ' . $e->getMessage()], 500);
    }
   }
    // ─── helpers ────────────────────────────────────────────────────────────────
   private function extractDeliveryData(array $data): array
   {
    $type = $data['delivery_type'] ?? 'delivery';

    if ($type !== 'delivery') {
        return [
            'delivery_type'    => 'pickup',
            'delivery_address' => null,
            'address_street'   => null,
            'address_barangay' => null,
            'address_city'     => null,
            'address_province' => null,
            'address_zipcode'  => null,
            'address_landmark' => null,
            'latitude'         => null,
            'longitude'        => null,
        ];
    }

    $street   = $data['address_street']   ?? null;
    $barangay = $data['address_barangay'] ?? null;
    $city     = $data['address_city']     ?? null;
    $province = $data['address_province'] ?? null;
    $zipcode  = $data['address_zipcode']  ?? null;
    $landmark = $data['address_landmark'] ?? null;

    // Auto-generate readable summary from structured fields
    $parts = array_filter([$street, $barangay, $city, $province, $zipcode]);
    $summary = implode(', ', $parts);

    return [
        'delivery_type'    => 'delivery',
        'delivery_address' => $summary ?: null,
        'address_street'   => $street,
        'address_barangay' => $barangay,
        'address_city'     => $city,
        'address_province' => $province,
        'address_zipcode'  => $zipcode,
        'address_landmark' => $landmark,
        'latitude'         => isset($data['latitude'])  ? (float) $data['latitude']  : null,
        'longitude'        => isset($data['longitude']) ? (float) $data['longitude'] : null,
    ];
   }

    private function getDeliveryFee(\PDO $db, string $deliveryType, ?string $city): float
    {
    // Pickup orders always have zero delivery fee
    if ($deliveryType !== 'delivery' || empty($city)) {
        return 0.00;
    }

    $stmt = $db->prepare('SELECT fee FROM delivery_fees WHERE city = ? AND is_active = 1');
    $stmt->execute([$city]);
    $row = $stmt->fetch();

    // If city not found in table default to highest zone fee
    return $row ? (float) $row['fee'] : 150.00;
}

    private function writeAdminNotification(array $data): void  
   {
    try {
        $projectId = 'my-micos-bikeshop';
        $url       = "https://firestore.googleapis.com/v1/projects/{$projectId}/databases/(default)/documents/admin_notifications";

        $fields = [];
        foreach ($data as $key => $value) {
            if (is_bool($value)) {
                $fields[$key] = ['booleanValue' => $value];
            } elseif (is_int($value)) {
                $fields[$key] = ['integerValue' => (string) $value];
            } else {
                $fields[$key] = ['stringValue' => (string) $value];
            }
        }
        $fields['created_at'] = ['stringValue' => date('c')];

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode(['fields' => $fields]),
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_TIMEOUT        => 5,
        ]);
        curl_exec($ch);
        curl_close($ch);
    } catch (\Exception $e) {
        // Never break core order flow for a notification failure
    }
  }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
