<?php

namespace App\Controllers;

use App\Config\Database;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class UserController
{
    // GET /api/users/me
    public function me(Request $request, Response $response): Response
{
    $userId = $request->getAttribute('user_id');
    $db     = Database::getConnection();

    $stmt = $db->prepare('
        SELECT id, email, first_name, last_name, phone, address,
               address_street, address_barangay, address_city, address_province,
               address_zipcode, address_landmark, latitude, longitude, created_at
        FROM users WHERE id = ?
    ');
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    if (!$user) {
        return $this->json($response, ['error' => 'User not found.'], 404);
    }

    return $this->json($response, $user);
}

    // PUT /api/users/me
    public function update(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $data   = $request->getParsedBody();
        $db     = Database::getConnection();

        $fields = [];
        $values = [];

        foreach (['first_name', 'last_name', 'phone'] as $field) {
    if (isset($data[$field])) {
        $fields[] = "{$field} = ?";
        $values[] = $data[$field];
    }
  }

// Structured address fields
   $addressFields = [
    'address_street', 'address_barangay', 'address_city',
    'address_province', 'address_zipcode', 'address_landmark',
 ];
   $hasAddress = false;
  foreach ($addressFields as $field) {
    if (isset($data[$field])) {
        $fields[] = "{$field} = ?";
        $values[] = $data[$field];
        $hasAddress = true;
    }
  }

// GPS coordinates
   foreach (['latitude', 'longitude'] as $field) {
    if (isset($data[$field])) {
        $fields[] = "{$field} = ?";
        $values[] = (float) $data[$field];
    }
   }

// Auto-generate address summary from structured fields
    if ($hasAddress) {
    $parts = array_filter([
        $data['address_street']   ?? null,
        $data['address_barangay'] ?? null,
        $data['address_city']     ?? null,
        $data['address_province'] ?? null,
        $data['address_zipcode']  ?? null,
    ]);
    if (!empty($parts)) {
        $fields[] = 'address = ?';
        $values[] = implode(', ', $parts);
    }
   }

        if (!empty($data['password'])) {
            $fields[] = 'password = ?';
            $values[] = password_hash($data['password'], PASSWORD_BCRYPT);
        }

        if (empty($fields)) {
            return $this->json($response, ['error' => 'No fields provided for update.'], 422);
        }

        $values[] = $userId;
        $db->prepare('UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = ?')
           ->execute($values);

        return $this->json($response, ['message' => 'Profile updated successfully.']);
    }

    // DELETE /api/users/me
    public function delete(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();

        $db->prepare('DELETE FROM users WHERE id = ?')->execute([$userId]);

        return $this->json($response, ['message' => 'Account deleted.']);
    }

    // ─── helpers ────────────────────────────────────────────────────────────────

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
