<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ARModelController
{
    // GET /api/products/{id}/ar-model
    // Returns the product-level AR model (used only when product has no variants)
    public function show(Request $request, Response $response, array $args): Response
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM ar_models WHERE product_id = ? AND variant_id IS NULL'
        );
        $stmt->execute([$args['id']]);
        $model = $stmt->fetch();

        if (!$model) {
            return $this->json($response, ['error' => 'AR model not found for this product.'], 404);
        }

        return $this->json($response, $model);
    }

    // GET /api/variants/{id}/ar-model
    public function showForVariant(Request $request, Response $response, array $args): Response
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM ar_models WHERE variant_id = ?'
        );
        $stmt->execute([$args['id']]);
        $model = $stmt->fetch();

        if (!$model) {
            return $this->json($response, ['error' => 'AR model not found for this variant.'], 404);
        }

        return $this->json($response, $model);
    }

    // POST /api/products/{id}/ar-model  [admin]
    // Assigns AR model directly to a product (only meaningful when product has no variants)
    public function store(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();

        if (empty($data['model_file'])) {
            return $this->json($response, ['error' => 'model_file is required.'], 422);
        }

        $db = Database::getConnection();

        $p = $db->prepare('SELECT id FROM products WHERE id = ?');
        $p->execute([$args['id']]);
        if (!$p->fetch()) {
            return $this->json($response, ['error' => 'Product not found.'], 404);
        }

        $existing = $db->prepare('SELECT id FROM ar_models WHERE product_id = ? AND variant_id IS NULL');
        $existing->execute([$args['id']]);
        if ($row = $existing->fetch()) {
            $db->prepare('UPDATE ar_models SET model_file = ?, scale = ? WHERE id = ?')
               ->execute([$data['model_file'], $data['scale'] ?? 1.0, $row['id']]);
            return $this->json($response, ['message' => 'AR model replaced.']);
        }

        $db->prepare('INSERT INTO ar_models (product_id, variant_id, model_file, scale) VALUES (?, NULL, ?, ?)')
           ->execute([$args['id'], $data['model_file'], $data['scale'] ?? 1.0]);

        return $this->json($response, [
            'message' => 'AR model created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // POST /api/variants/{id}/ar-model  [admin]
    public function storeForVariant(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();

        if (empty($data['model_file'])) {
            return $this->json($response, ['error' => 'model_file is required.'], 422);
        }

        $db = Database::getConnection();

        $v = $db->prepare('SELECT id, product_id FROM product_variants WHERE id = ?');
        $v->execute([$args['id']]);
        $variant = $v->fetch();
        if (!$variant) {
            return $this->json($response, ['error' => 'Variant not found.'], 404);
        }

        $existing = $db->prepare('SELECT id FROM ar_models WHERE variant_id = ?');
        $existing->execute([$args['id']]);
        if ($row = $existing->fetch()) {
            $db->prepare('UPDATE ar_models SET model_file = ?, scale = ? WHERE id = ?')
               ->execute([$data['model_file'], $data['scale'] ?? 1.0, $row['id']]);
            return $this->json($response, ['message' => 'AR model replaced.']);
        }

        $db->prepare('
            INSERT INTO ar_models (product_id, variant_id, model_file, scale)
            VALUES (?, ?, ?, ?)
        ')->execute([$variant['product_id'], $args['id'], $data['model_file'], $data['scale'] ?? 1.0]);

        return $this->json($response, [
            'message' => 'AR model created.',
            'id'      => (int) $db->lastInsertId(),
        ], 201);
    }

    // PUT /api/ar-models/{id}  [admin]
    public function update(Request $request, Response $response, array $args): Response
    {
        $data   = $request->getParsedBody();
        $fields = [];
        $values = [];

        foreach (['model_file', 'scale'] as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        Database::getConnection()->prepare('UPDATE ar_models SET ' . implode(', ', $fields) . ' WHERE id = ?')
            ->execute($values);

        return $this->json($response, ['message' => 'AR model updated.']);
    }

    // DELETE /api/ar-models/{id}  [admin]
    public function destroy(Request $request, Response $response, array $args): Response
    {
        Database::getConnection()->prepare('DELETE FROM ar_models WHERE id = ?')->execute([$args['id']]);
        return $this->json($response, ['message' => 'AR model deleted.']);
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}