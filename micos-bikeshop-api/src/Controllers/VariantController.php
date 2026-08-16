<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class VariantController
{
    // GET /api/products/{id}/variants
    public function index(Request $request, Response $response, array $args): Response
    {
        $db     = Database::getConnection();
        $params = $request->getQueryParams();

        $archivedFilter = !empty($params['archived']) && $params['archived'] === 'true'
            ? 'is_archived = 1'
            : 'is_archived = 0';

        $stmt = $db->prepare("
            SELECT * FROM product_variants
            WHERE product_id = ? AND {$archivedFilter}
            ORDER BY variant_type ASC, variant_value ASC
        ");
        $stmt->execute([$args['id']]);

        return $this->json($response, $stmt->fetchAll());
    }

    // GET /api/variants/{id}
    public function show(Request $request, Response $response, array $args): Response
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM product_variants WHERE id = ?');
        $stmt->execute([$args['id']]);
        $row = $stmt->fetch();

        return $row
            ? $this->json($response, $row)
            : $this->json($response, ['error' => 'Variant not found.'], 404);
    }

    // POST /api/products/{id}/variants  [admin]
    public function store(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();

        if (empty($data['variant_type']) || empty($data['variant_value'])) {
            return $this->json($response, ['error' => 'variant_type and variant_value are required.'], 422);
        }

        $db = Database::getConnection();

        $p = $db->prepare('SELECT id FROM products WHERE id = ?');
        $p->execute([$args['id']]);
        if (!$p->fetch()) {
            return $this->json($response, ['error' => 'Product not found.'], 404);
        }

        $db->prepare('
            INSERT INTO product_variants
                (product_id, variant_type, variant_value, price_adjustment, stock, image)
            VALUES (?, ?, ?, ?, ?, ?)
        ')->execute([
            $args['id'],
            $data['variant_type'],
            $data['variant_value'],
            $data['price_adjustment'] ?? 0.00,
            $data['stock']            ?? 0,
            $data['image']            ?? null,
        ]);

        return $this->json($response, [
            'message' => 'Variant created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // PUT /api/variants/{id}  [admin]
    public function update(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $data = $request->getParsedBody();

        $check = $db->prepare('SELECT id FROM product_variants WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Variant not found.'], 404);
        }

        $fields = [];
        $values = [];

        foreach (['variant_type', 'variant_value', 'price_adjustment', 'stock', 'image'] as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        $db->prepare('UPDATE product_variants SET ' . implode(', ', $fields) . ' WHERE id = ?')
           ->execute($values);

        return $this->json($response, ['message' => 'Variant updated.']);
    }

    // DELETE /api/variants/{id}  [admin] — soft delete
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id FROM product_variants WHERE id = ? AND is_archived = 0');
        $stmt->execute([$args['id']]);

        if (!$stmt->fetch()) {
            return $this->json($response, ['error' => 'Variant not found or already archived.'], 404);
        }

        $db->prepare('UPDATE product_variants SET is_archived = 1 WHERE id = ?')
           ->execute([$args['id']]);

        return $this->json($response, ['message' => 'Variant archived.']);
    }

    // PUT /api/variants/{id}/restore  [admin]
    public function restore(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id FROM product_variants WHERE id = ? AND is_archived = 1');
        $stmt->execute([$args['id']]);

        if (!$stmt->fetch()) {
            return $this->json($response, ['error' => 'Variant not found or not archived.'], 404);
        }

        $db->prepare('UPDATE product_variants SET is_archived = 0 WHERE id = ?')
           ->execute([$args['id']]);

        return $this->json($response, ['message' => 'Variant restored.']);
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}