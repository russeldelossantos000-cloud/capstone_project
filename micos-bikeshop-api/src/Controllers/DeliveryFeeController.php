<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class DeliveryFeeController
{
    // GET /api/admin/delivery-fees
    // Returns all cities grouped by zone
    public function index(Request $request, Response $response): Response
    {
        $db   = Database::getConnection();
        $rows = $db->query("
            SELECT * FROM delivery_fees
            ORDER BY zone ASC, city ASC
        ")->fetchAll();

        // Group by zone for easier frontend rendering
        $grouped = [];
        foreach ($rows as $row) {
            $zone = (int) $row['zone'];
            if (!isset($grouped[$zone])) {
                $grouped[$zone] = [];
            }
            $grouped[$zone][] = $row;
        }

        return $this->json($response, [
            'fees'   => $rows,
            'grouped' => $grouped,
        ]);
    }

    // GET /api/delivery-fees/city?city=Balanga+City
    // Public endpoint — Flutter app calls this to get fee for selected city
    public function getByCity(Request $request, Response $response): Response
    {
        $city = $request->getQueryParams()['city'] ?? '';

        if (empty($city)) {
            return $this->json($response, ['error' => 'city parameter is required.'], 422);
        }

        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM delivery_fees WHERE city = ? AND is_active = 1');
        $stmt->execute([$city]);
        $row = $stmt->fetch();

        if (!$row) {
            return $this->json($response, ['error' => 'City not found.', 'fee' => 150.00], 404);
        }

        return $this->json($response, $row);
    }

    // PUT /api/admin/delivery-fees/{id}
    // Update fee for a specific city
    public function update(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();
        $db   = Database::getConnection();

        $check = $db->prepare('SELECT id FROM delivery_fees WHERE id = ?');
        $check->execute([$args['id']]);
        if (!$check->fetch()) {
            return $this->json($response, ['error' => 'Delivery fee entry not found.'], 404);
        }

        $fields = [];
        $values = [];

        if (isset($data['fee'])) {
            if ((float) $data['fee'] < 0) {
                return $this->json($response, ['error' => 'Fee cannot be negative.'], 422);
            }
            $fields[] = 'fee = ?';
            $values[] = (float) $data['fee'];
        }

        if (isset($data['zone'])) {
            $fields[] = 'zone = ?';
            $values[] = (int) $data['zone'];
        }

        if (isset($data['is_active'])) {
            $fields[] = 'is_active = ?';
            $values[] = $data['is_active'] ? 1 : 0;
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields to update.'], 422);
        }

        $values[] = $args['id'];
        $db->prepare('UPDATE delivery_fees SET ' . implode(', ', $fields) . ' WHERE id = ?')
           ->execute($values);

        return $this->json($response, ['message' => 'Delivery fee updated.']);
    }

    // PUT /api/admin/delivery-fees/zone/{zone}
    // Update all cities in a zone at once
    public function updateZone(Request $request, Response $response, array $args): Response
    {
        $data = $request->getParsedBody();
        $db   = Database::getConnection();

        if (!isset($data['fee'])) {
            return $this->json($response, ['error' => 'fee is required.'], 422);
        }

        if ((float) $data['fee'] < 0) {
            return $this->json($response, ['error' => 'Fee cannot be negative.'], 422);
        }

        $db->prepare('UPDATE delivery_fees SET fee = ? WHERE zone = ?')
           ->execute([(float) $data['fee'], (int) $args['zone']]);

        return $this->json($response, [
            'message' => "All Zone {$args['zone']} cities updated to ₱{$data['fee']}.",
        ]);
    }

    // ── helpers ─────────────────────────────────────────────────────────────────

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}