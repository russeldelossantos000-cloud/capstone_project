<?php

namespace App\Controllers;

use App\Config\Database;
use App\Controllers\NotificationController;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class MessageController
{
    // GET /api/messages
    // Returns conversations for the logged-in user, or all messages for admin.
    public function index(Request $request, Response $response): Response
    {
        $userId  = (int) $request->getAttribute('user_id');
        $role    = $request->getAttribute('role');
        $isAdmin = $role === 'admin';
        $db      = Database::getConnection();

        // Admin sees ALL messages across all users.
        // User sees only their own conversations.
        if ($isAdmin) {
            $stmt = $db->prepare('
                SELECT m.*,
                       COALESCE(s.full_name, a_s.name, a_s.username) AS sender_name,
                       COALESCE(r.full_name, a_r.name, a_r.username) AS receiver_name
                FROM messages m
                LEFT JOIN users  s   ON m.sender_id   = s.id   AND m.sender_is_admin   = 0
                LEFT JOIN admins a_s ON m.sender_id   = a_s.id AND m.sender_is_admin   = 1
                LEFT JOIN users  r   ON m.receiver_id = r.id   AND m.receiver_is_admin = 0
                LEFT JOIN admins a_r ON m.receiver_id = a_r.id AND m.receiver_is_admin = 1
                ORDER BY m.created_at DESC
            ');
            $stmt->execute();
        } else {
            $stmt = $db->prepare('
                SELECT m.*,
                       COALESCE(s.full_name, a_s.name, a_s.username) AS sender_name,
                       COALESCE(r.full_name, a_r.name, a_r.username) AS receiver_name
                FROM messages m
                LEFT JOIN users  s   ON m.sender_id   = s.id   AND m.sender_is_admin   = 0
                LEFT JOIN admins a_s ON m.sender_id   = a_s.id AND m.sender_is_admin   = 1
                LEFT JOIN users  r   ON m.receiver_id = r.id   AND m.receiver_is_admin = 0
                LEFT JOIN admins a_r ON m.receiver_id = a_r.id AND m.receiver_is_admin = 1
                WHERE (m.sender_id = ?   AND m.sender_is_admin   = 0)
                   OR (m.receiver_id = ? AND m.receiver_is_admin = 0)
                ORDER BY m.created_at DESC
            ');
            $stmt->execute([$userId, $userId]);
        }

        return $this->json($response, $stmt->fetchAll());
    }

    // GET /api/messages/{userId}
    // Thread between the authenticated party and the given user ID.
    public function thread(Request $request, Response $response, array $args): Response
    {
        $myId    = (int) $request->getAttribute('user_id');
        $isAdmin = $request->getAttribute('role') === 'admin';
        $otherId = (int) $args['userId'];
        $db      = Database::getConnection();

        $myIsAdmin    = $isAdmin ? 1 : 0;
        $otherIsAdmin = 0; // The {userId} in the URL is always a regular user

        $stmt = $db->prepare('
            SELECT m.*,
                   COALESCE(s.full_name, a_s.name, a_s.username) AS sender_name,
                   COALESCE(r.full_name, a_r.name, a_r.username) AS receiver_name
            FROM messages m
            LEFT JOIN users  s   ON m.sender_id   = s.id   AND m.sender_is_admin   = 0
            LEFT JOIN admins a_s ON m.sender_id   = a_s.id AND m.sender_is_admin   = 1
            LEFT JOIN users  r   ON m.receiver_id = r.id   AND m.receiver_is_admin = 0
            LEFT JOIN admins a_r ON m.receiver_id = a_r.id AND m.receiver_is_admin = 1
            WHERE (m.sender_id = ?   AND m.sender_is_admin   = ?
                   AND m.receiver_id = ? AND m.receiver_is_admin = ?)
               OR (m.sender_id = ?   AND m.sender_is_admin   = ?
                   AND m.receiver_id = ? AND m.receiver_is_admin = ?)
            ORDER BY m.created_at ASC
        ');
        $stmt->execute([
            $myId,    $myIsAdmin,    $otherId, $otherIsAdmin,
            $otherId, $otherIsAdmin, $myId,    $myIsAdmin,
        ]);

        // Mark messages sent to me as read
        $db->prepare('
            UPDATE messages
            SET    is_read = 1
            WHERE  sender_id        = ? AND sender_is_admin   = ?
              AND  receiver_id      = ? AND receiver_is_admin = ?
              AND  is_read          = 0
        ')->execute([$otherId, $otherIsAdmin, $myId, $myIsAdmin]);

        return $this->json($response, $stmt->fetchAll());
    }

    // POST /api/messages
    // Works for user→user and admin→user.
    // Body: { receiver_id, message }
    public function store(Request $request, Response $response): Response
    {
        $senderId   = (int) $request->getAttribute('user_id');
        $isAdmin    = $request->getAttribute('role') === 'admin';
        $data       = $request->getParsedBody();
        $db         = Database::getConnection();

        // ── Validation ────────────────────────────────────────────────
        if (empty($data['receiver_id']) || empty($data['message'])) {
            return $this->json($response, ['error' => 'receiver_id and message are required.'], 422);
        }

        $receiverId = (int) $data['receiver_id'];

        if (!$isAdmin && $receiverId === $senderId) {
            return $this->json($response, ['error' => 'You cannot message yourself.'], 422);
        }

        if (mb_strlen($data['message']) > 2000) {
            return $this->json($response, ['error' => 'Message cannot exceed 2000 characters.'], 422);
        }

        // ── Verify receiver exists in users table ─────────────────────
        $r = $db->prepare('SELECT id FROM users WHERE id = ?');
        $r->execute([$receiverId]);
        if (!$r->fetch()) {
            return $this->json($response, ['error' => 'Receiver not found.'], 404);
        }

        // ── Insert with sender_is_admin flag ──────────────────────────
        // sender_id references admins.id when sender_is_admin = 1,
        // and users.id when sender_is_admin = 0.
        // The FK constraint only applies to the users table, so we use
        // sender_is_admin as a discriminator to avoid the FK violation.
        $db->prepare('
            INSERT INTO messages (sender_id, sender_is_admin, receiver_id, receiver_is_admin, message, is_read)
            VALUES (?, ?, ?, 0, ?, 0)
        ')->execute([$senderId, $isAdmin ? 1 : 0, $receiverId, $data['message']]);

        $newId = (int) $db->lastInsertId();

        // ── Notify receiver ───────────────────────────────────────────
        $senderName = 'Admin';
        if (!$isAdmin) {
            $s = $db->prepare('SELECT full_name FROM users WHERE id = ?');
            $s->execute([$senderId]);
            $senderName = $s->fetch()['full_name'] ?? 'User';
        }
        NotificationController::newMessage($receiverId, $senderName, $data['message']);

        return $this->json($response, ['message' => 'Message sent.', 'id' => $newId], 201);
    }

    // PUT /api/messages/{id}/read
    public function markRead(Request $request, Response $response, array $args): Response
    {
        $userId  = (int) $request->getAttribute('user_id');
        $isAdmin = $request->getAttribute('role') === 'admin';
        $db      = Database::getConnection();

        $db->prepare('
            UPDATE messages SET is_read = 1
            WHERE id = ? AND receiver_id = ? AND receiver_is_admin = ?
        ')->execute([$args['id'], $userId, $isAdmin ? 1 : 0]);

        return $this->json($response, ['message' => 'Message marked as read.']);
    }


    // ── Admin-specific message methods ───────────────────────────────────────
    // Route: /api/admin/messages — protected by AdminMiddleware (not AuthMiddleware).
    // These work with the ORIGINAL messages schema — no migration needed to READ.
    // Sending requires dropping the FK on sender_id (see migration_admin_messaging.sql).

    // GET /api/admin/messages — all conversations, visible to admin
    public function adminIndex(Request $request, Response $response): Response
    {
        $db = Database::getConnection();

        $stmt = $db->prepare('
            SELECT m.*,
                   COALESCE(s.full_name, "Admin") AS sender_name,
                   COALESCE(r.full_name, "Admin") AS receiver_name
            FROM messages m
            LEFT JOIN users s ON m.sender_id   = s.id
            LEFT JOIN users r ON m.receiver_id = r.id
            ORDER BY m.created_at DESC
        ');
        $stmt->execute();

        return $this->json($response, $stmt->fetchAll());
    }

    // GET /api/admin/messages/{userId} — full thread with a specific user
    public function adminThread(Request $request, Response $response, array $args): Response
    {
        $adminId = (int) $request->getAttribute('user_id'); // resolved from admin_id by AuthMiddleware
        $userId  = (int) $args['userId'];
        $db      = Database::getConnection();

        $stmt = $db->prepare('
            SELECT m.*,
                   COALESCE(s.full_name, "Admin") AS sender_name,
                   COALESCE(r.full_name, "Admin") AS receiver_name
            FROM messages m
            LEFT JOIN users s ON m.sender_id   = s.id
            LEFT JOIN users r ON m.receiver_id = r.id
            WHERE (m.sender_id = ? AND m.receiver_id = ?)
               OR (m.sender_id = ? AND m.receiver_id = ?)
            ORDER BY m.created_at ASC
        ');
        $stmt->execute([$adminId, $userId, $userId, $adminId]);

        // Mark unread messages from this user as read
        $db->prepare('
            UPDATE messages SET is_read = 1
            WHERE sender_id = ? AND receiver_id = ? AND is_read = 0
        ')->execute([$userId, $adminId]);

        return $this->json($response, $stmt->fetchAll());
    }

    // POST /api/admin/messages — admin replies to a user
    // Body: { receiver_id, message }
    public function adminSend(Request $request, Response $response): Response
    {
        $adminId = (int) $request->getAttribute('user_id');
        $data    = $request->getParsedBody();
        $db      = Database::getConnection();

        if (empty($data['receiver_id']) || empty($data['message'])) {
            return $this->json($response, ['error' => 'receiver_id and message are required.'], 422);
        }

        if (mb_strlen($data['message']) > 2000) {
            return $this->json($response, ['error' => 'Message cannot exceed 2000 characters.'], 422);
        }

        $receiverId = (int) $data['receiver_id'];

        $r = $db->prepare('SELECT id FROM users WHERE id = ?');
        $r->execute([$receiverId]);
        if (!$r->fetch()) {
            return $this->json($response, ['error' => 'Receiver not found.'], 404);
        }

        try {
            $db->prepare('
                INSERT INTO messages (sender_id, receiver_id, message, is_read)
                VALUES (?, ?, ?, 0)
            ')->execute([$adminId, $receiverId, $data['message']]);
        } catch (\PDOException $e) {
            if (str_contains($e->getMessage(), '23000')) {
                return $this->json($response, [
                    'error' => 'FK constraint: run database/migration_admin_messaging.sql to allow admin replies.',
                ], 500);
            }
            throw $e;
        }

        $newId = (int) $db->lastInsertId();
        NotificationController::newMessage($receiverId, 'Admin', $data['message']);

        return $this->json($response, ['message' => 'Message sent.', 'id' => $newId], 201);
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}