<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class CartController
{
    // GET /api/cart
    public function index(Request $request, Response $response): Response
    {
    $userId = $request->getAttribute('user_id');
    $db     = Database::getConnection();

    $cart = $this->getOrCreateCart($db, $userId);

    $stmt = $db->prepare("
        SELECT ci.id, ci.quantity, ci.variant_id,
               p.id AS product_id, p.product_name, p.image,
               pv.variant_type, pv.variant_value, pv.price_adjustment, pv.image AS variant_image,
               (p.price + COALESCE(pv.price_adjustment, 0)) AS price,
               (ci.quantity * (p.price + COALESCE(pv.price_adjustment, 0))) AS subtotal
        FROM cart_items ci
        JOIN products p ON ci.product_id = p.id
        LEFT JOIN product_variants pv ON ci.variant_id = pv.id
        WHERE ci.cart_id = ?
    ");
    $stmt->execute([$cart['id']]);
    $items = $stmt->fetchAll();

    $total = array_sum(array_column($items, 'subtotal'));

    return $this->json($response, [
        'cart_id' => $cart['id'],
        'items'   => $items,
        'total'   => round($total, 2),
    ]);
   }

    // POST /api/cart/items
   public function addItem(Request $request, Response $response): Response
    {
    $userId = $request->getAttribute('user_id');
    $data   = $request->getParsedBody();
    $db     = Database::getConnection();

    if (empty($data['product_id']) || empty($data['quantity'])) {
        return $this->json($response, ['error' => 'product_id and quantity are required.'], 422);
    }

    $variantId = !empty($data['variant_id']) ? (int) $data['variant_id'] : null;

    $p = $db->prepare('SELECT id, stock FROM products WHERE id = ?');
    $p->execute([$data['product_id']]);
    $product = $p->fetch();

    if (!$product) {
        return $this->json($response, ['error' => 'Product not found.'], 404);
    }

    $availableStock = (int) $product['stock'];

    if ($variantId !== null) {
        $v = $db->prepare('SELECT id, stock FROM product_variants WHERE id = ? AND product_id = ? AND is_archived = 0');
        $v->execute([$variantId, $data['product_id']]);
        $variant = $v->fetch();
        if (!$variant) {
            return $this->json($response, ['error' => 'Variant not found for this product.'], 404);
        }
        $availableStock = (int) $variant['stock'];
    }

    if ((int) $data['quantity'] > $availableStock) {
        return $this->json($response, ['error' => 'Requested quantity exceeds stock.'], 409);
    }

    $cart = $this->getOrCreateCart($db, $userId);

    // Two different variants of the same product = two separate line items, not merged
    if ($variantId !== null) {
        $existing = $db->prepare('SELECT id, quantity FROM cart_items WHERE cart_id = ? AND product_id = ? AND variant_id = ?');
        $existing->execute([$cart['id'], $data['product_id'], $variantId]);
    } else {
        $existing = $db->prepare('SELECT id, quantity FROM cart_items WHERE cart_id = ? AND product_id = ? AND variant_id IS NULL');
        $existing->execute([$cart['id'], $data['product_id']]);
    }
    $item = $existing->fetch();

    if ($item) {
        $db->prepare('UPDATE cart_items SET quantity = quantity + ? WHERE id = ?')
           ->execute([$data['quantity'], $item['id']]);
    } else {
        $db->prepare('INSERT INTO cart_items (cart_id, product_id, variant_id, quantity) VALUES (?, ?, ?, ?)')
           ->execute([$cart['id'], $data['product_id'], $variantId, $data['quantity']]);
    }

    return $this->json($response, ['message' => 'Item added to cart.'], 201);
    }

    // PUT /api/cart/items/{id}
    public function updateItem(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();

        if (!isset($data['quantity']) || (int) $data['quantity'] < 1) {
            return $this->json($response, ['error' => 'A valid quantity is required.'], 422);
        }

        // Verify ownership
        $stmt = $db->prepare('
            SELECT ci.id FROM cart_items ci
            JOIN carts c ON ci.cart_id = c.id
            WHERE ci.id = ? AND c.user_id = ?
        ');
        $stmt->execute([$args['id'], $userId]);

        if (!$stmt->fetch()) {
            return $this->json($response, ['error' => 'Cart item not found.'], 404);
        }

        $db->prepare('UPDATE cart_items SET quantity = ? WHERE id = ?')
           ->execute([$data['quantity'], $args['id']]);

        return $this->json($response, ['message' => 'Cart item updated.']);
    }

    // DELETE /api/cart/items/{id}
    public function removeItem(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();

        $stmt = $db->prepare('
            SELECT ci.id FROM cart_items ci
            JOIN carts c ON ci.cart_id = c.id
            WHERE ci.id = ? AND c.user_id = ?
        ');
        $stmt->execute([$args['id'], $userId]);

        if (!$stmt->fetch()) {
            return $this->json($response, ['error' => 'Cart item not found.'], 404);
        }

        $db->prepare('DELETE FROM cart_items WHERE id = ?')->execute([$args['id']]);

        return $this->json($response, ['message' => 'Item removed from cart.']);
    }

    // DELETE /api/cart
    public function clear(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();
        $cart   = $this->getOrCreateCart($db, $userId);

        $db->prepare('DELETE FROM cart_items WHERE cart_id = ?')->execute([$cart['id']]);

        return $this->json($response, ['message' => 'Cart cleared.']);
    }

    // ─── helpers ────────────────────────────────────────────────────────────────

    private function getOrCreateCart(\PDO $db, int $userId): array
    {
        $stmt = $db->prepare('SELECT id FROM carts WHERE user_id = ?');
        $stmt->execute([$userId]);
        $cart = $stmt->fetch();

        if (!$cart) {
            $db->prepare('INSERT INTO carts (user_id) VALUES (?)')->execute([$userId]);
            $cart = ['id' => (int) $db->lastInsertId()];
        }

        return $cart;
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
