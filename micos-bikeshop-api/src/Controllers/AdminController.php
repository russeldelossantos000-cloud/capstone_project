<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class AdminController
{
    // GET /api/admin/dashboard
    public function dashboard(Request $request, Response $response): Response
    {
        $db = Database::getConnection();

        $stats = [
            'total_users'    => (int) $db->query('SELECT COUNT(*) FROM users')->fetchColumn(),
            'total_products' => (int) $db->query('SELECT COUNT(*) FROM products WHERE is_archived = 0')->fetchColumn(),
            'total_orders'   => (int) $db->query('SELECT COUNT(*) FROM orders')->fetchColumn(),
            'pending_orders' => (int) $db->query("SELECT COUNT(*) FROM orders WHERE status = 'pending'")->fetchColumn(),
            'total_revenue'  => (float) $db->query("SELECT COALESCE(SUM(total_amount),0) FROM orders WHERE payment_status = 'paid'")->fetchColumn(),
            'low_stock' => (int) $db->query('SELECT COUNT(*) FROM products WHERE stock <= 5 AND is_archived = 0')->fetchColumn(),
        ];

        return $this->json($response, $stats);
    }

    // GET /api/admin/users
    public function users(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $db     = Database::getConnection();

        $where  = ['1=1'];
        $values = [];

        if (!empty($params['search'])) {
          $where[]  = '(email LIKE ? OR first_name LIKE ? OR last_name LIKE ?)';
          $values[] = '%' . $params['search'] . '%';
          $values[] = '%' . $params['search'] . '%';
          $values[] = '%' . $params['search'] . '%';
        }

        $whereClause = implode(' AND ', $where);
        $stmt        = $db->prepare("
            SELECT id, email, first_name, last_name, phone, address, created_at
            FROM users WHERE {$whereClause}
            ORDER BY created_at DESC
        ");
        $stmt->execute($values);

        return $this->json($response, $stmt->fetchAll());
    }

    // GET /api/admin/orders
    public function orders(Request $request, Response $response): Response
{
    $params = $request->getQueryParams();
    $db     = Database::getConnection();

    $where  = ['1=1'];
    $values = [];

    if (!empty($params['status'])) {
        $where[]  = 'o.status = ?';
        $values[] = $params['status'];
    }

    if (!empty($params['payment_status'])) {
        $where[]  = 'o.payment_status = ?';
        $values[] = $params['payment_status'];
    }

    $whereClause = implode(' AND ', $where);
    $stmt        = $db->prepare("
        SELECT o.*,
               CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
               u.email  AS customer_email,
               u.phone  AS customer_phone
        FROM orders o
        JOIN users u ON o.user_id = u.id
        WHERE {$whereClause}
        ORDER BY o.created_at DESC
    ");
    $stmt->execute($values);
    $orders = $stmt->fetchAll();

    // Attach items with customizations to each order
    foreach ($orders as &$order) {
        $items = $db->prepare("
            SELECT oi.id, oi.product_id, oi.variant_id, oi.quantity, oi.price,
           p.product_name, p.image,
           pv.variant_type, pv.variant_value
    FROM order_items oi
    JOIN products p ON oi.product_id = p.id
    LEFT JOIN product_variants pv ON oi.variant_id = pv.id
    WHERE oi.order_id = ?
        ");
        $items->execute([$order['id']]);
        $order['items'] = $items->fetchAll();
    }
    unset($order);

    return $this->json($response, $orders);
}
    // GET /api/admin/inventory
   public function inventory(Request $request, Response $response): Response
{
    $db     = Database::getConnection();
    $params = $request->getQueryParams();

    // Show archived products if requested
    $archivedFilter = !empty($params['archived']) && $params['archived'] === 'true'
        ? 'p.is_archived = 1'
        : 'p.is_archived = 0';

    $rows = $db->query("
        SELECT
            p.id, p.product_name, p.stock, p.price,
            p.stock_threshold, p.demand_level, p.priority,
            p.is_archived,
            c.category_name, c.id AS category_id,
            b.brand_name,

            -- Stock status relative to threshold
            CASE
                WHEN p.stock = 0              THEN 'out_of_stock'
                WHEN p.stock <= p.stock_threshold THEN 'low'
                ELSE 'ok'
            END AS stock_status,

            -- Last restock date
            (
                SELECT MAX(il.created_at)
                FROM inventory_logs il
                WHERE il.product_id = p.id
                  AND il.transaction_type = 'restock'
            ) AS last_restocked,

            -- Last restock supplier
            (
                SELECT s.supplier_name
                FROM inventory_logs il
                LEFT JOIN suppliers s ON s.id = il.supplier_id
                WHERE il.product_id = p.id
                  AND il.transaction_type = 'restock'
                ORDER BY il.created_at DESC
                LIMIT 1
            ) AS last_supplier,

            -- Units sold online in last 30 days
            COALESCE((
                SELECT SUM(oi.quantity)
                FROM order_items oi
                JOIN orders o ON o.id = oi.order_id
                WHERE oi.product_id = p.id
                  AND o.payment_status = 'paid'
                  AND o.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            ), 0) AS online_sold_30days,

            -- Units sold walk-in in last 30 days
            COALESCE((
                SELECT SUM(il2.quantity)
                FROM inventory_logs il2
                WHERE il2.product_id = p.id
                  AND il2.transaction_type = 'walk_in_sale'
                  AND il2.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            ), 0) AS walkin_sold_30days

        FROM products p
        LEFT JOIN categories c ON p.category_id = c.id
        LEFT JOIN brands b     ON p.brand_id    = b.id
        WHERE {$archivedFilter}
        ORDER BY p.stock ASC
    ")->fetchAll();

    // Add combined total sold and stock health score
    foreach ($rows as &$row) {
        $row['total_sold_30days'] = (int)$row['online_sold_30days'] + (int)$row['walkin_sold_30days'];
    }
    unset($row);

    return $this->json($response, $rows);
}

    // GET /api/admin/inventory/logs
    public function inventoryLogs(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $db     = Database::getConnection();

        $where  = ['1=1'];
        $values = [];

       if (!empty($params['product_id'])) {
    $where[]  = 'il.product_id = ?';
    $values[] = $params['product_id'];
   }

      if (!empty($params['change_type'])) {
    $where[]  = 'il.change_type = ?';
    $values[] = $params['change_type'];
  }

      if (!empty($params['transaction_type'])) {
    $where[]  = 'il.transaction_type = ?';
    $values[] = $params['transaction_type'];
  }

      if (!empty($params['category_id'])) {
    $where[]  = 'p.category_id = ?';
    $values[] = $params['category_id'];
  }

      if (!empty($params['supplier_id'])) {
    $where[]  = 'il.supplier_id = ?';
    $values[] = $params['supplier_id'];
  }

      if (!empty($params['start']) && !empty($params['end'])) {
    $where[]  = 'DATE(il.created_at) BETWEEN ? AND ?';
    $values[] = $params['start'];
    $values[] = $params['end'];
  }

        $whereClause = implode(' AND ', $where);

        $stmt = $db->prepare("
    SELECT il.*, p.product_name, c.category_name,
           s.supplier_name
    FROM inventory_logs il
    JOIN products p    ON il.product_id  = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN suppliers s  ON il.supplier_id = s.id
    WHERE {$whereClause}
    ORDER BY il.created_at DESC
   ");

        $stmt->execute($values);

        return $this->json($response, $stmt->fetchAll());
    }

    // POST /api/admin/inventory/log
    public function logInventory(Request $request, Response $response): Response
{
    $data = $request->getParsedBody();
    $db   = Database::getConnection();

    $required = ['product_id', 'change_type', 'quantity', 'transaction_type'];
    foreach ($required as $f) {
        if (empty($data[$f])) {
            return $this->json($response, ['error' => "Field '{$f}' is required."], 422);
        }
    }

    if (!in_array($data['change_type'], ['IN', 'OUT'], true)) {
        return $this->json($response, ['error' => "change_type must be 'IN' or 'OUT'."], 422);
    }

    $validTypes = ['online_order','walk_in_sale','restock','adjustment','return','cancelled_order'];
    if (!in_array($data['transaction_type'], $validTypes, true)) {
        return $this->json($response, ['error' => 'Invalid transaction_type.'], 422);
    }

    $p = $db->prepare('SELECT id FROM products WHERE id = ?');
    $p->execute([$data['product_id']]);
    if (!$p->fetch()) {
        return $this->json($response, ['error' => 'Product not found.'], 404);
    }

    \App\Services\InventoryService::adjustStock(
        productId: (int) $data['product_id'],
        changeType: $data['change_type'],
        quantity: (int) $data['quantity'],
        transactionType: $data['transaction_type'],
        reason: $data['reason'] ?? null,
        reference: $data['reference'] ?? null,
        supplierId: !empty($data['supplier_id']) ? (int) $data['supplier_id'] : null,
        loggedBy: $request->getAttribute('username') ?? 'Admin'
    );

    return $this->json($response, ['message' => 'Inventory log added.'], 201);
}
// GET /api/admin/analytics
// Params: period (daily|weekly|monthly), start, end, compare (true|false)
public function analytics(Request $request, Response $response): Response
{
    $params  = $request->getQueryParams();
    $db      = Database::getConnection();
    $period  = $params['period']  ?? 'monthly';
    $compare = !empty($params['compare']) && $params['compare'] === 'true';

    // ── Date range calculation ───────────────────────────────────────────────
    $end   = isset($params['end'])   ? $params['end']   : date('Y-m-d');
    $start = isset($params['start']) ? $params['start'] : match($period) {
        'daily'   => date('Y-m-d', strtotime('-7 days')),
        'weekly'  => date('Y-m-d', strtotime('-4 weeks')),
        'monthly' => date('Y-m-d', strtotime('-12 months')),
        default   => date('Y-m-d', strtotime('-30 days')),
    };

    // Previous period for comparison
    $daysDiff  = (strtotime($end) - strtotime($start)) / 86400;
    $prevEnd   = date('Y-m-d', strtotime($start . ' -1 day'));
    $prevStart = date('Y-m-d', strtotime($prevEnd . " -{$daysDiff} days"));

    // ── Online sales ─────────────────────────────────────────────────────────
    $onlineStmt = $db->prepare("
        SELECT
            COUNT(*)                                              AS order_count,
            COALESCE(SUM(total_amount), 0)                        AS revenue,
            COALESCE(SUM(delivery_fee), 0)                        AS delivery_revenue,
            COALESCE(SUM(total_amount - delivery_fee), 0)         AS product_revenue,
            COUNT(CASE WHEN delivery_type = 'delivery' THEN 1 END) AS delivery_count,
            COUNT(CASE WHEN delivery_type = 'pickup'   THEN 1 END) AS pickup_count,
            COUNT(CASE WHEN payment_method = 'gcash'   THEN 1 END) AS gcash_count,
            COUNT(CASE WHEN payment_method = 'cash'    THEN 1 END) AS cash_count
        FROM orders
        WHERE payment_status = 'paid'
          AND DATE(created_at) BETWEEN ? AND ?
    ");
    $onlineStmt->execute([$start, $end]);
    $online = $onlineStmt->fetch();

    // ── Walk-in sales ────────────────────────────────────────────────────────
    $walkinStmt = $db->prepare("
        SELECT
            COUNT(*)                    AS walkin_count,
            COALESCE(SUM(il.quantity * p.price), 0) AS walkin_revenue
        FROM inventory_logs il
        JOIN products p ON il.product_id = p.id
        WHERE il.transaction_type = 'walk_in_sale'
          AND DATE(il.created_at) BETWEEN ? AND ?
    ");
    $walkinStmt->execute([$start, $end]);
    $walkin = $walkinStmt->fetch();

    // ── New customers ────────────────────────────────────────────────────────
    $custStmt = $db->prepare("
        SELECT COUNT(*) AS new_customers
        FROM users
        WHERE DATE(created_at) BETWEEN ? AND ?
    ");
    $custStmt->execute([$start, $end]);
    $customers = $custStmt->fetch();

    // ── Items sold ───────────────────────────────────────────────────────────
    $itemsStmt = $db->prepare("
        SELECT COALESCE(SUM(oi.quantity), 0) AS items_sold
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        WHERE o.payment_status = 'paid'
          AND DATE(o.created_at) BETWEEN ? AND ?
    ");
    $itemsStmt->execute([$start, $end]);
    $items = $itemsStmt->fetch();

    // ── Stock movement ───────────────────────────────────────────────────────
    $stockStmt = $db->prepare("
        SELECT
            COALESCE(SUM(CASE WHEN change_type = 'IN'  THEN quantity END), 0) AS total_in,
            COALESCE(SUM(CASE WHEN change_type = 'OUT' THEN quantity END), 0) AS total_out
        FROM inventory_logs
        WHERE DATE(created_at) BETWEEN ? AND ?
    ");
    $stockStmt->execute([$start, $end]);
    $stock = $stockStmt->fetch();

    // ── Best sellers ─────────────────────────────────────────────────────────
    $bestStmt = $db->prepare("
        SELECT p.id, p.product_name, c.category_name,
               COALESCE(SUM(oi.quantity), 0) AS units_sold,
               COALESCE(SUM(oi.quantity * oi.price), 0) AS revenue
        FROM products p
        LEFT JOIN order_items oi ON oi.product_id = p.id
        LEFT JOIN orders o ON o.id = oi.order_id
            AND o.payment_status = 'paid'
            AND DATE(o.created_at) BETWEEN ? AND ?
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE p.is_archived = 0
        GROUP BY p.id
        ORDER BY units_sold DESC
        LIMIT 10
    ");
    $bestStmt->execute([$start, $end]);
    $bestSellers = $bestStmt->fetchAll();

    // ── Sales trend — grouped by period ─────────────────────────────────────
    $groupBy = match($period) {
        'daily'   => 'DATE(o.created_at)',
        'weekly'  => 'YEARWEEK(o.created_at, 1)',
        'monthly' => "DATE_FORMAT(o.created_at, '%Y-%m')",
        default   => 'DATE(o.created_at)',
    };

    $trendStmt = $db->prepare("
        SELECT {$groupBy} AS period_label,
               COUNT(*)   AS order_count,
               COALESCE(SUM(total_amount), 0) AS revenue
        FROM orders o
        WHERE payment_status = 'paid'
          AND DATE(created_at) BETWEEN ? AND ?
        GROUP BY period_label
        ORDER BY period_label ASC
    ");
    $trendStmt->execute([$start, $end]);
    $trend = $trendStmt->fetchAll();

    // ── Comparison period (if requested) ─────────────────────────────────────
    $comparison = null;
    if ($compare) {
        $prevOnline = $db->prepare("
            SELECT COUNT(*) AS order_count,
                   COALESCE(SUM(total_amount), 0) AS revenue
            FROM orders
            WHERE payment_status = 'paid'
              AND DATE(created_at) BETWEEN ? AND ?
        ");
        $prevOnline->execute([$prevStart, $prevEnd]);
        $comparison = $prevOnline->fetch();
        $comparison['period_start'] = $prevStart;
        $comparison['period_end']   = $prevEnd;
    }

    // ── Slow movers ───────────────────────────────────────────────────────────
    $slowStmt = $db->prepare("
        SELECT p.id, p.product_name, p.stock, c.category_name,
               COALESCE(SUM(oi.quantity), 0) AS units_sold
        FROM products p
        LEFT JOIN order_items oi ON oi.product_id = p.id
        LEFT JOIN orders o ON o.id = oi.order_id
            AND o.payment_status = 'paid'
            AND DATE(o.created_at) BETWEEN ? AND ?
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE p.is_archived = 0
        GROUP BY p.id
        HAVING units_sold = 0
        ORDER BY p.stock DESC
        LIMIT 10
    ");
    $slowStmt->execute([$start, $end]);
    $slowMovers = $slowStmt->fetchAll();

    return $this->json($response, [
        'period'       => ['start' => $start, 'end' => $end, 'type' => $period],
        'online'       => $online,
        'walkin'       => $walkin,
        'customers'    => $customers,
        'items'        => $items,
        'stock'        => $stock,
        'best_sellers' => $bestSellers,
        'slow_movers'  => $slowMovers,
        'trend'        => $trend,
        'comparison'   => $comparison,
        'summary'      => [
            'total_revenue'  => round((float)$online['revenue'] + (float)$walkin['walkin_revenue'], 2),
            'total_orders'   => (int)$online['order_count'] + (int)$walkin['walkin_count'],
            'total_items_sold' => (int)$items['items_sold'],
            'new_customers'  => (int)$customers['new_customers'],
        ],
    ]);
}

    // GET /api/admin/shop
    public function shop(Request $request, Response $response): Response
    {
        $row = Database::getConnection()->query('SELECT * FROM shop LIMIT 1')->fetch();
        return $this->json($response, $row ?: []);
    }

    // PUT /api/admin/shop
    public function updateShop(Request $request, Response $response): Response
    {
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();
        $fields = [];
        $values = [];

        foreach (['name', 'address', 'contact_number', 'email'] as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $existing = $db->query('SELECT id FROM shop LIMIT 1')->fetch();

        if ($existing) {
            $values[] = $existing['id'];
            $db->prepare('UPDATE shop SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($values);
        } else {
            $db->prepare('INSERT INTO shop (name, address, contact_number, email) VALUES (?, ?, ?, ?)')
               ->execute([$data['name'] ?? '', $data['address'] ?? '', $data['contact_number'] ?? '', $data['email'] ?? '']);
        }

        return $this->json($response, ['message' => 'Shop info updated.']);
    }

    // ─── helpers ────────────────────────────────────────────────────────────────



    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
