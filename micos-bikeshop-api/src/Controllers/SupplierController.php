<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class SupplierController
{
    // GET /api/admin/suppliers
    public function index(Request $request, Response $response): Response
    {
        $db   = Database::getConnection();
        $rows = $db->query("
            SELECT s.*,
                   COUNT(DISTINCT il.id) AS total_deliveries,
                   MAX(il.created_at)    AS last_delivery,
                   COUNT(DISTINCT il.product_id) AS products_supplied
            FROM suppliers s
            LEFT JOIN inventory_logs il ON il.supplier_id = s.id
                AND il.transaction_type = 'restock'
            GROUP BY s.id
            ORDER BY s.supplier_name ASC
        ")->fetchAll();

        return $this->json($response, $rows);
    }

    // GET /api/admin/suppliers/{id}
    public function show(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM suppliers WHERE id = ?');
        $stmt->execute([$args['id']]);
        $supplier = $stmt->fetch();

        if (!$supplier) {
            return $this->json($response, ['error' => 'Supplier not found.'], 404);
        }

        // Get all restock logs from this supplier
        $logs = $db->prepare("
            SELECT il.*, p.product_name
            FROM inventory_logs il
            JOIN products p ON il.product_id = p.id
            WHERE il.supplier_id = ?
            AND il.transaction_type = 'restock'
            ORDER BY il.created_at DESC
        ");
        $logs->execute([$args['id']]);
        $supplier['restock_history'] = $logs->fetchAll();

        return $this->json($response, $supplier);
    }

    // POST /api/admin/suppliers
    public function store(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();

        if (empty($data['supplier_name'])) {
            return $this->json($response, ['error' => 'supplier_name is required.'], 422);
        }

        $db = Database::getConnection();
        $db->prepare('
            INSERT INTO suppliers (supplier_name, contact_person, phone, email, address, notes)
            VALUES (?, ?, ?, ?, ?, ?)
        ')->execute([
            $data['supplier_name'],
            $data['contact_person'] ?? null,
            $data['phone']          ?? null,
            $data['email']          ?? null,
            $data['address']        ?? null,
            $data['notes']          ?? null,
        ]);

        return $this->json($response, [
            'message' => 'Supplier created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // PUT /api/admin/suppliers/{id}
    public function update(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $data = $request->getParsedBody();

        $check = $db->prepare('SELECT id FROM suppliers WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Supplier not found.'], 404);
        }

        $fields = [];
        $values = [];

        foreach (['supplier_name', 'contact_person', 'phone', 'email', 'address', 'notes'] as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        $db->prepare('UPDATE suppliers SET ' . implode(', ', $fields) . ' WHERE id = ?')
           ->execute($values);

        return $this->json($response, ['message' => 'Supplier updated.']);
    }

    // DELETE /api/admin/suppliers/{id}
    // Soft delete — sets is_active = 0
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id FROM suppliers WHERE id = ? AND is_active = 1');
        $stmt->execute([$args['id']]);

        if (!$stmt->fetch()) {
            return $this->json($response, ['error' => 'Supplier not found or already inactive.'], 404);
        }

        $db->prepare('UPDATE suppliers SET is_active = 0 WHERE id = ?')
           ->execute([$args['id']]);

        return $this->json($response, ['message' => 'Supplier deactivated.']);
    }

    // PUT /api/admin/suppliers/{id}/restore
    public function restore(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id FROM suppliers WHERE id = ? AND is_active = 0');
        $stmt->execute([$args['id']]);

        if (!$stmt->fetch()) {
            return $this->json($response, ['error' => 'Supplier not found or already active.'], 404);
        }

        $db->prepare('UPDATE suppliers SET is_active = 1 WHERE id = ?')
           ->execute([$args['id']]);

        return $this->json($response, ['message' => 'Supplier restored.']);
    }

    // ── helpers ─────────────────────────────────────────────────────────────────

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}