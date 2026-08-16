<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ReviewController
{
    // GET /api/products/{id}/reviews
    public function index(Request $request, Response $response, array $args): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare("
            SELECT pr.*, CONCAT(u.first_name, ' ', u.last_name) AS reviewer_name
            FROM product_reviews pr
            JOIN users u ON pr.user_id = u.id
            WHERE pr.product_id = ?
            ORDER BY pr.created_at DESC
        ");
        $stmt->execute([$args['id']]);
        $reviews = $stmt->fetchAll();

        // Aggregate stats
        $stats = $db->prepare("
            SELECT COUNT(*) AS total, ROUND(AVG(rating), 1) AS average,
                   SUM(rating = 5) AS s5, SUM(rating = 4) AS s4,
                   SUM(rating = 3) AS s3, SUM(rating = 2) AS s2, SUM(rating = 1) AS s1
            FROM product_reviews WHERE product_id = ?
        ");
        $stats->execute([$args['id']]);

        return $this->json($response, [
            'stats'   => $stats->fetch(),
            'reviews' => $reviews,
        ]);
    }

    // POST /api/products/{id}/reviews  [user]
    public function store(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();

        if (empty($data['rating']) || !in_array((int) $data['rating'], [1,2,3,4,5], true)) {
            return $this->json($response, ['error' => 'Rating must be 1–5.'], 422);
        }

        // Verify product exists
        $p = $db->prepare('SELECT id FROM products WHERE id = ?');
        $p->execute([$args['id']]);
        if (!$p->fetch()) return $this->json($response, ['error' => 'Product not found.'], 404);

        // Optional: ensure user actually ordered this product
        if (!empty($data['order_id'])) {
            $chk = $db->prepare("
                SELECT oi.id FROM order_items oi
                JOIN orders o ON oi.order_id = o.id
                WHERE oi.product_id = ? AND o.user_id = ? AND o.id = ? AND o.status = 'delivered'
            ");
            $chk->execute([$args['id'], $userId, $data['order_id']]);
            if (!$chk->fetch()) {
                return $this->json($response, ['error' => 'You can only review products from delivered orders.'], 403);
            }
        }

        // Check for existing review
        $existing = $db->prepare('SELECT id FROM product_reviews WHERE product_id = ? AND user_id = ?');
        $existing->execute([$args['id'], $userId]);
        if ($existing->fetch()) {
            return $this->json($response, ['error' => 'You have already reviewed this product.'], 409);
        }

        $db->prepare('
            INSERT INTO product_reviews (product_id, user_id, order_id, rating, comment)
            VALUES (?, ?, ?, ?, ?)
        ')->execute([
            $args['id'], $userId,
            !empty($data['order_id']) ? $data['order_id'] : null,
            (int) $data['rating'],
            $data['comment'] ?? null,
        ]);

        return $this->json($response, ['message' => 'Review submitted.', 'id' => (int) $db->lastInsertId()], 201);
    }

    // PUT /api/reviews/{id}  [user — own review only]
    public function update(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();

        $stmt = $db->prepare('SELECT * FROM product_reviews WHERE id = ? AND user_id = ?');
        $stmt->execute([$args['id'], $userId]);
        if (!$stmt->fetch()) return $this->json($response, ['error' => 'Review not found.'], 404);

        $fields = [];
        $values = [];

        if (isset($data['rating'])) {
            if (!in_array((int) $data['rating'], [1,2,3,4,5], true)) {
                return $this->json($response, ['error' => 'Rating must be 1–5.'], 422);
            }
            $fields[] = 'rating = ?';
            $values[] = (int) $data['rating'];
        }

        if (isset($data['comment'])) {
            $fields[] = 'comment = ?';
            $values[] = $data['comment'];
        }

        if (empty($fields)) return $this->json($response, ['error' => 'No fields to update.'], 422);

        $values[] = $args['id'];
        $db->prepare('UPDATE product_reviews SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($values);

        return $this->json($response, ['message' => 'Review updated.']);
    }

    // DELETE /api/reviews/{id}  [user — own review only, or admin]
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $role   = $request->getAttribute('role');
        $db     = Database::getConnection();

        $where = $role === 'admin' ? 'id = ?' : 'id = ? AND user_id = ?';
        $params = $role === 'admin' ? [$args['id']] : [$args['id'], $userId];

        $stmt = $db->prepare("SELECT id FROM product_reviews WHERE {$where}");
        $stmt->execute($params);
        if (!$stmt->fetch()) return $this->json($response, ['error' => 'Review not found.'], 404);

        $db->prepare('DELETE FROM product_reviews WHERE id = ?')->execute([$args['id']]);
        return $this->json($response, ['message' => 'Review deleted.']);
    }

    // GET /api/admin/reviews  [admin]
    public function adminIndex(Request $request, Response $response): Response
    {
        $db   = Database::getConnection();
        $stmt = $db->prepare("
            SELECT pr.*, CONCAT(u.first_name, ' ', u.last_name) AS reviewer_name, p.product_name
            FROM product_reviews pr
            JOIN users u    ON pr.user_id    = u.id
            JOIN products p ON pr.product_id = p.id
            ORDER BY pr.created_at DESC
            LIMIT 100
        ");
        $stmt->execute();
        return $this->json($response, $stmt->fetchAll());
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
