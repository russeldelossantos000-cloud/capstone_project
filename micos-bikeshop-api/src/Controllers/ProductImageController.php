<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ProductImageController
{
    // GET /api/products/{id}/images
    public function index(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM product_images WHERE product_id = ? ORDER BY is_primary DESC, sort_order ASC');
        $stmt->execute([$args['id']]);
        return $this->json($response, $stmt->fetchAll());
    }

    // POST /api/products/{id}/images  [admin]
    public function store(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();
        $db   = Database::getConnection();

        if (empty($data['image_url'])) {
            return $this->json($response, ['error' => 'image_url is required.'], 422);
        }

        // Verify product exists
        $p = $db->prepare('SELECT id FROM products WHERE id = ?');
        $p->execute([$args['id']]);
        if (!$p->fetch()) return $this->json($response, ['error' => 'Product not found.'], 404);

        // If first image or explicitly marked primary, auto-set is_primary
    
        $ct    = $db->prepare('SELECT COUNT(*) FROM product_images WHERE product_id = ?');
        $ct->execute([$args['id']]);
        $count = (int) $ct->fetchColumn();

        $isPrimary = isset($data['is_primary']) ? (int) $data['is_primary'] : ($count === 0 ? 1 : 0);

        // If setting as primary, demote others
        if ($isPrimary) {
            $db->prepare('UPDATE product_images SET is_primary = 0 WHERE product_id = ?')->execute([$args['id']]);
        }

        // Get next sort_order
        $so = $db->prepare('SELECT COALESCE(MAX(sort_order), 0) + 1 FROM product_images WHERE product_id = ?');
        $so->execute([$args['id']]);
        $sortOrder = $data['sort_order'] ?? (int) $so->fetchColumn();

        $db->prepare('INSERT INTO product_images (product_id, image_url, is_primary, sort_order) VALUES (?, ?, ?, ?)')->execute([
            $args['id'], $data['image_url'], $isPrimary, $sortOrder,
        ]);

        return $this->json($response, ['message' => 'Image added.', 'id' => (int) $db->lastInsertId()], 201);
    }

    // POST /api/products/{id}/images/batch  [admin] — add up to 10 images at once
    public function storeBatch(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();
        $db   = Database::getConnection();

        if (empty($data['images']) || !is_array($data['images'])) {
            return $this->json($response, ['error' => 'images array is required.'], 422);
        }

        if (count($data['images']) > 10) {
            return $this->json($response, ['error' => 'Maximum 10 images per batch.'], 422);
        }

        $p = $db->prepare('SELECT id FROM products WHERE id = ?');
        $p->execute([$args['id']]);
        if (!$p->fetch()) return $this->json($response, ['error' => 'Product not found.'], 404);

        // Get current max sort_order
        $so = $db->prepare('SELECT COALESCE(MAX(sort_order), 0) FROM product_images WHERE product_id = ?');
        $so->execute([$args['id']]);
        $sortBase = (int) $so->fetchColumn();

        $hasPrimary = false;
        $inserted   = [];

        foreach ($data['images'] as $i => $img) {
            if (empty($img['image_url'])) continue;

            $isPrimary = !empty($img['is_primary']) && !$hasPrimary ? 1 : 0;
            if ($isPrimary) $hasPrimary = true;

            $db->prepare('INSERT INTO product_images (product_id, image_url, is_primary, sort_order) VALUES (?, ?, ?, ?)')->execute([
                $args['id'], $img['image_url'], $isPrimary, $sortBase + $i + 1,
            ]);
            $inserted[] = (int) $db->lastInsertId();
        }

        // If no primary was set and there are images, make first one primary
        if (!$hasPrimary && !empty($inserted)) {
            $db->prepare('UPDATE product_images SET is_primary = 1 WHERE id = ?')->execute([$inserted[0]]);
        }

        return $this->json($response, ['message' => count($inserted) . ' images added.', 'ids' => $inserted], 201);
    }

    // PUT /api/product-images/{id}/set-primary  [admin]
    public function setPrimary(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM product_images WHERE id = ?');
        $stmt->execute([$args['id']]);
        $image = $stmt->fetch();

        if (!$image) return $this->json($response, ['error' => 'Image not found.'], 404);

        // Demote all, then promote this one
        $db->prepare('UPDATE product_images SET is_primary = 0 WHERE product_id = ?')->execute([$image['product_id']]);
        $db->prepare('UPDATE product_images SET is_primary = 1 WHERE id = ?')->execute([$args['id']]);

        return $this->json($response, ['message' => 'Primary image updated.']);
    }

    // PUT /api/product-images/{id}  [admin] — update sort_order or url
    public function update(Request $request, Response $response, array $args): Response
    {
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();
        $fields = [];
        $values = [];

        foreach (['image_url', 'sort_order'] as $f) {
            if (isset($data[$f])) {
                $fields[] = "{$f} = ?";
                $values[] = $data[$f];
            }
        }

        if (empty($fields)) return $this->json($response, ['error' => 'No fields to update.'], 422);
        $values[] = $args['id'];
        $db->prepare('UPDATE product_images SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($values);

        return $this->json($response, ['message' => 'Image updated.']);
    }

    // DELETE /api/product-images/{id}  [admin]
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM product_images WHERE id = ?');
        $stmt->execute([$args['id']]);
        $image = $stmt->fetch();

        if (!$image) return $this->json($response, ['error' => 'Image not found.'], 404);

        $db->prepare('DELETE FROM product_images WHERE id = ?')->execute([$args['id']]);

        // If deleted image was primary, auto-promote next one
        if ($image['is_primary']) {
            $next = $db->prepare('SELECT id FROM product_images WHERE product_id = ? ORDER BY sort_order ASC LIMIT 1');
            $next->execute([$image['product_id']]);
            $nextImage = $next->fetch();
            if ($nextImage) {
                $db->prepare('UPDATE product_images SET is_primary = 1 WHERE id = ?')->execute([$nextImage['id']]);
            }
        }

        return $this->json($response, ['message' => 'Image deleted.']);
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
