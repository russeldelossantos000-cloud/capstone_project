<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class CategoryController
{
    // GET /api/categories
    public function index(Request $request, Response $response): Response
    {
        $rows = Database::getConnection()
    ->query("
        SELECT c.*, COUNT(p.id) AS product_count
        FROM categories c
        LEFT JOIN products p ON p.category_id = c.id AND p.is_archived = 0
        GROUP BY c.id
        ORDER BY c.category_name
    ")->fetchAll();

        return $this->json($response, $rows);
    }

    // GET /api/categories/{id}
    public function show(Request $request, Response $response, array $args): Response
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM categories WHERE id = ?');
        $stmt->execute([$args['id']]);
        $row = $stmt->fetch();

        return $row
            ? $this->json($response, $row)
            : $this->json($response, ['error' => 'Category not found.'], 404);
    }

    // POST /api/categories  [admin]
    public function store(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();

        if (empty($data['category_name'])) {
            return $this->json($response, ['error' => 'category_name is required.'], 422);
        }

        $db = Database::getConnection();
        $db->prepare('INSERT INTO categories (category_name) VALUES (?)')->execute([$data['category_name']]);

        return $this->json($response, [
            'message' => 'Category created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // PUT /api/categories/{id}  [admin]
    public function update(Request $request, Response $response, array $args): Response
    {
        $db = Database::getConnection();

        // Check category exists first
        $check = $db->prepare('SELECT id FROM categories WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Category not found.'], 404);
        }

        $data = $request->getParsedBody();

        if (empty($data['category_name'])) {
            return $this->json($response, ['error' => 'category_name is required.'], 422);
        }

        $db->prepare('UPDATE categories SET category_name = ? WHERE id = ?')
           ->execute([$data['category_name'], $args['id']]);

        return $this->json($response, ['message' => 'Category updated.']);
    }

    // DELETE /api/categories/{id}  [admin]
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $db = Database::getConnection();

        // ── 1. Check the category actually exists ────────────────────
        $check = $db->prepare('SELECT id FROM categories WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Category not found.'], 404);
        }

        // ── 2. Check if any products are still using this category ───
        // A MySQL FK constraint violation (SQLSTATE 23000) would be
        // thrown otherwise, crashing into Slim's generic error handler.
        $linked = $db->prepare('SELECT COUNT(*) FROM products WHERE category_id = ?');
        $linked->execute([$args['id']]);
        $count = (int) $linked->fetchColumn();

        if ($count > 0) {
            return $this->json($response, [
                'error' => "Cannot delete this category. It is linked to {$count} product(s).",
                'hint'  => 'Reassign or delete those products first, then try again.',
                'count' => $count,
            ], 409);
        }

        // ── 3. Safe to delete ────────────────────────────────────────
        try {
            $db->prepare('DELETE FROM categories WHERE id = ?')->execute([$args['id']]);
            return $this->json($response, ['message' => 'Category deleted.']);

        } catch (\PDOException $e) {
            // Fallback catch for any unexpected FK violation at the DB level
            if (str_contains($e->getMessage(), '23000')) {
                return $this->json($response, [
                    'error' => 'Cannot delete this category because it is still referenced by other records.',
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