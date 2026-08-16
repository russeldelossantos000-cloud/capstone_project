<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class BrandController
{
    // GET /api/brands
    public function index(Request $request, Response $response): Response
    {
       $rows = Database::getConnection()
    ->query("
        SELECT b.*, COUNT(p.id) AS product_count
        FROM brands b
        LEFT JOIN products p ON p.brand_id = b.id AND p.is_archived = 0
        GROUP BY b.id
        ORDER BY b.brand_name
    ")->fetchAll();

        return $this->json($response, $rows);
    }

    // GET /api/brands/{id}
    public function show(Request $request, Response $response, array $args): Response
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM brands WHERE id = ?');
        $stmt->execute([$args['id']]);
        $row = $stmt->fetch();

        return $row
            ? $this->json($response, $row)
            : $this->json($response, ['error' => 'Brand not found.'], 404);
    }

    // POST /api/brands  [admin]
    public function store(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();

        if (empty($data['brand_name'])) {
            return $this->json($response, ['error' => 'brand_name is required.'], 422);
        }

        $db = Database::getConnection();
        $db->prepare('INSERT INTO brands (brand_name, logo) VALUES (?, ?)')
           ->execute([$data['brand_name'], $data['logo'] ?? null]);

        return $this->json($response, [
            'message' => 'Brand created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // PUT /api/brands/{id}  [admin]
    public function update(Request $request, Response $response, array $args): Response
    {
        $db = Database::getConnection();

        // Check brand exists first
        $check = $db->prepare('SELECT id FROM brands WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Brand not found.'], 404);
        }

        $data   = $request->getParsedBody();
        $fields = [];
        $values = [];

        foreach (['brand_name', 'logo'] as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        $db->prepare('UPDATE brands SET ' . implode(', ', $fields) . ' WHERE id = ?')
           ->execute($values);

        return $this->json($response, ['message' => 'Brand updated.']);
    }

    // DELETE /api/brands/{id}  [admin]
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $db = Database::getConnection();

        // ── 1. Check the brand actually exists ───────────────────────
        $check = $db->prepare('SELECT id FROM brands WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Brand not found.'], 404);
        }

        // ── 2. Check if any products are still linked to this brand ──
        // Deleting a brand that products reference will throw a MySQL
        // foreign key constraint error (SQLSTATE 23000).
        // We catch this here and return a clear 409 Conflict instead
        // of letting it crash into Slim's generic error handler.
        $linked = $db->prepare('SELECT COUNT(*) FROM products WHERE brand_id = ?');
        $linked->execute([$args['id']]);
        $count = (int) $linked->fetchColumn();

        if ($count > 0) {
            return $this->json($response, [
                'error'   => "Cannot delete this brand. It is linked to {$count} product(s).",
                'hint'    => 'Reassign or delete those products first, then try again.',
                'count'   => $count,
            ], 409);
        }

        // ── 3. Safe to delete ────────────────────────────────────────
        try {
            $db->prepare('DELETE FROM brands WHERE id = ?')->execute([$args['id']]);
            return $this->json($response, ['message' => 'Brand deleted.']);

        } catch (\PDOException $e) {
            // Fallback catch for any unexpected FK violation at the DB level
            if (str_contains($e->getMessage(), '23000')) {
                return $this->json($response, [
                    'error' => 'Cannot delete this brand because it is still referenced by other records.',
                ], 409);
            }

            return $this->json($response, ['error' => 'Unexpected error: ' . $e->getMessage()], 500);
        }
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}