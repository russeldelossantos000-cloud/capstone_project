<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ProductController
{
    // GET /api/products
    public function index(Request $request, Response $response): Response
   {
    $db     = Database::getConnection();
    $params = $request->getQueryParams();

    $archivedFilter = !empty($params['archived']) && $params['archived'] === 'true'
        ? 'p.is_archived = 1'
        : 'p.is_archived = 0';

    $where  = [$archivedFilter];
    $values = [];

        if (!empty($params['category_id'])) {
            $where[]  = 'p.category_id = ?';
            $values[] = $params['category_id'];
        }

        if (!empty($params['brand_id'])) {
            $where[]  = 'p.brand_id = ?';
            $values[] = $params['brand_id'];
        }

        if (!empty($params['search'])) {
            $where[]  = 'p.product_name LIKE ?';
            $values[] = '%' . $params['search'] . '%';
        }

        if (isset($params['is_customizable'])) {
            $where[]  = 'p.is_customizable = ?';
            $values[] = (int) $params['is_customizable'];
        }

        $whereClause = implode(' AND ', $where);

       $stmt = $db->prepare("
    SELECT p.*, c.category_name, b.brand_name,
           COALESCE(sales.units_sold, 0) AS units_sold_30days
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN brands b     ON p.brand_id    = b.id
    LEFT JOIN (
        SELECT oi.product_id, SUM(oi.quantity) AS units_sold
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.payment_status = 'paid'
          AND o.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY oi.product_id
    ) sales ON sales.product_id = p.id
    WHERE {$whereClause}
    ORDER BY p.id DESC
");
$stmt->execute($values);
$products = $stmt->fetchAll();

// Fetch all active variants for these products in one query
$productIds = array_column($products, 'id');
$variantsByProduct = [];
if (!empty($productIds)) {
    $placeholders = implode(',', array_fill(0, count($productIds), '?'));
    $vStmt = $db->prepare("
        SELECT * FROM product_variants
        WHERE product_id IN ({$placeholders}) AND is_archived = 0
        ORDER BY variant_type ASC, variant_value ASC
    ");
    $vStmt->execute($productIds);
    foreach ($vStmt->fetchAll() as $variant) {
        $variantsByProduct[$variant['product_id']][] = $variant;
    }
}

foreach ($products as &$product) {
    $product['demand_level'] = $this->classifyDemand(
        (int)   $product['units_sold_30days'],
        (float) $product['price'],
        (int)   $product['stock'],
        (int)   $product['stock_threshold']
    );
    $product['variants']    = $variantsByProduct[$product['id']] ?? [];
    $product['has_variants'] = !empty($product['variants']);
}
unset($product);

return $this->json($response, $products);
    }

    // GET /api/products/{id}
    public function show(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare("
    SELECT p.*, c.category_name, b.brand_name,
           COALESCE(sales.units_sold, 0) AS units_sold_30days
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN brands b     ON p.brand_id    = b.id
    LEFT JOIN (
        SELECT oi.product_id, SUM(oi.quantity) AS units_sold
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.payment_status = 'paid'
          AND o.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY oi.product_id
    ) sales ON sales.product_id = p.id
    WHERE p.id = ? AND p.is_archived = 0
");
$stmt->execute([$args['id']]);
$product = $stmt->fetch();

     if (!$product) {
    return $this->json($response, ['error' => 'Product not found.'], 404);
}

$product['demand_level'] = $this->classifyDemand(
    (int)   $product['units_sold_30days'],
    (float) $product['price'],
    (int)   $product['stock'],
    (int)   $product['stock_threshold']
);

// Fetch active variants for this product
$vStmt = $db->prepare("
    SELECT * FROM product_variants
    WHERE product_id = ? AND is_archived = 0
    ORDER BY variant_type ASC, variant_value ASC
");
$vStmt->execute([$args['id']]);
$variants = $vStmt->fetchAll();
$product['variants']     = $variants;
$product['has_variants'] = !empty($variants);

// AR model: product-level (no variants) takes ar_models.product_id where variant_id IS NULL.
// Variant-level models are attached to each variant individually below.
$ar = $db->prepare('SELECT * FROM ar_models WHERE product_id = ? AND variant_id IS NULL');
$ar->execute([$args['id']]);
$product['ar_model'] = $ar->fetch() ?: null;

// Attach each variant's own AR model, if any
foreach ($product['variants'] as &$variant) {
    $vAr = $db->prepare('SELECT * FROM ar_models WHERE variant_id = ?');
    $vAr->execute([$variant['id']]);
    $variant['ar_model'] = $vAr->fetch() ?: null;
}
unset($variant);

return $this->json($response, $product);
    }

    // POST /api/products  [admin]
    public function store(Request $request, Response $response): Response
    {
        $data     = $request->getParsedBody();
        $required = ['product_name', 'price', 'stock', 'category_id'];

        foreach ($required as $field) {
            if (!isset($data[$field]) || $data[$field] === '') {
                return $this->json($response, ['error' => "Field '{$field}' is required."], 422);
            }
        }

        $db = Database::getConnection();
        $db->prepare('
    INSERT INTO products
        (category_id, product_name, description, price, stock, image, brand_id)
    VALUES (?, ?, ?, ?, ?, ?, ?)
')->execute([
    $data['category_id'],
    $data['product_name'],
    $data['description']    ?? null,
    $data['price'],
    $data['stock'],
    $data['image']          ?? null,
    $data['brand_id']       ?? null,
]);

        return $this->json($response, [
            'message' => 'Product created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // PUT /api/products/{id}  [admin]
    public function update(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $data = $request->getParsedBody();

        $fields = [];
        $values = [];

        $allowed = ['category_id', 'product_name', 'description', 'price', 'stock', 'image', 'brand_id'];
        foreach ($allowed as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        $db->prepare('UPDATE products SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($values);

        return $this->json($response, ['message' => 'Product updated.']);
    }

    // DELETE /api/products/{id}  [admin]
      public function destroy(Request $request, Response $response, array $args): Response
  {
    $db   = Database::getConnection();
    $stmt = $db->prepare('SELECT id FROM products WHERE id = ? AND is_archived = 0');
    $stmt->execute([$args['id']]);

    if (!$stmt->fetch()) {
        return $this->json($response, ['error' => 'Product not found or already archived.'], 404);
    }

    $db->prepare('UPDATE products SET is_archived = 1 WHERE id = ?')
       ->execute([$args['id']]);

    return $this->json($response, ['message' => 'Product archived successfully.']);
   }

// PUT /api/products/{id}/unarchive  [admin]
     public function unarchive(Request $request, Response $response, array $args): Response
   {
    $db   = Database::getConnection();
    $stmt = $db->prepare('SELECT id FROM products WHERE id = ? AND is_archived = 1');
    $stmt->execute([$args['id']]);

    if (!$stmt->fetch()) {
        return $this->json($response, ['error' => 'Product not found or not archived.'], 404);
    }

    $db->prepare('UPDATE products SET is_archived = 0 WHERE id = ?')
       ->execute([$args['id']]);

    return $this->json($response, ['message' => 'Product restored successfully.']);
   }
    // ─── helpers ────────────────────────────────────────────────────────────────

private function classifyDemand(int $unitsSold, float $price, int $stock, int $threshold): string
{
    // Specialty — high price items regardless of sales volume
    if ($price >= 5000) {
        return 'specialty';
    }

    // High demand — sells 10+ units per month
    if ($unitsSold >= 10) {
        return 'high';
    }

    // Low demand — sells 2 or fewer units per month
    if ($unitsSold <= 2) {
        return 'low';
    }

    // Normal — everything in between
    return 'normal';
}

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
