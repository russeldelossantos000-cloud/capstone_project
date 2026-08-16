<?php

namespace App\Controllers;

use App\Config\Database;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Config\Env;

class SSEController
{
    /**
     * GET /api/messages/stream?token=<jwt>&last_id=<int>
     *
     * Server-Sent Events endpoint for real-time messaging.
     * Works on XAMPP — no Redis, no WebSocket server needed.
     *
     * Client usage (JavaScript):
     *   const es = new EventSource(`/api/messages/stream?token=${jwt}&last_id=0`);
     *   es.addEventListener('new_message', e => console.log(JSON.parse(e.data)));
     *   es.addEventListener('ping', () => {});  // keep-alive
     */
    public function stream(Request $request, Response $response): Response
    {
        $params = $request->getQueryParams();
        $token  = $params['token'] ?? '';
        $lastId = (int) ($params['last_id'] ?? 0);

        // ── Authenticate via query param (EventSource can't set headers) ───────
        if (!$token) {
            return $this->sseError($response, 'Missing token.');
        }

        try {
            $decoded = JWT::decode($token, new Key(Env::get('JWT_SECRET'), 'HS256'));
            $userId  = (int) ($decoded->user_id ?? 0);
            if (!$userId) throw new \Exception('Invalid payload');
        } catch (\Exception $e) {
            return $this->sseError($response, 'Invalid or expired token.');
        }

        // ── SSE headers ───────────────────────────────────────────────────────
        // Slim returns a response — for SSE we need direct output.
        // We flush headers then stream, then exit.
        if (ob_get_level()) ob_end_clean();

        header('Content-Type: text/event-stream');
        header('Cache-Control: no-cache');
        header('X-Accel-Buffering: no'); // Disable nginx buffering
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Headers: Content-Type, Authorization');

        set_time_limit(0);
        ignore_user_abort(false);

        $db        = Database::getConnection();
        $pingEvery = 20;   // seconds between pings
        $maxAge    = 120;  // close connection after 2 min (client will reconnect)
        $startTime = time();
        $lastPing  = time();

        while (true) {
            // Close if client disconnected or max age reached
            if (connection_aborted() || (time() - $startTime) > $maxAge) {
                break;
            }

            // ── Poll for new messages ──────────────────────────────────────
            $stmt = $db->prepare("
                SELECT m.id, m.sender_id, m.receiver_id, m.message, m.is_read, m.created_at,
                      CONCAT(u.first_name, ' ', u.last_name) AS sender_name
                FROM messages m
                JOIN users u ON m.sender_id = u.id
                WHERE m.receiver_id = ? AND m.id > ?
                ORDER BY m.id ASC
                LIMIT 20
            ");
            $stmt->execute([$userId, $lastId]);
            $messages = $stmt->fetchAll();

            foreach ($messages as $msg) {
                $lastId = max($lastId, (int) $msg['id']);
                $this->sseEvent('new_message', $msg);
            }

            // ── Poll for new notifications ────────────────────────────────
            $notifStmt = $db->prepare("
                SELECT id, type, title, message, data, created_at
                FROM notifications
                WHERE user_id = ? AND is_read = 0 AND id > ?
                ORDER BY id ASC LIMIT 10
            ");
            // Track last notification id in session or use a separate last_notif_id param
            $lastNotifId = (int) ($params['last_notif_id'] ?? 0);
            $notifStmt->execute([$userId, $lastNotifId]);
            $notifs = $notifStmt->fetchAll();

            foreach ($notifs as $notif) {
                $notif['data'] = $notif['data'] ? json_decode($notif['data'], true) : null;
                $this->sseEvent('notification', $notif);
            }

            // ── Send ping to keep connection alive ────────────────────────
            if ((time() - $lastPing) >= $pingEvery) {
                $this->sseEvent('ping', ['time' => time(), 'last_id' => $lastId]);
                $lastPing = time();
            }

            // Flush output buffer to client
            if (function_exists('fastcgi_finish_request')) {
                fastcgi_finish_request();
            } else {
                flush();
            }

            sleep(2); // poll every 2 seconds
        }

        exit;
    }

    // ── GET /api/messages/poll?last_id=<int>  [user]  ─────────────────────────
    // Fallback for environments where SSE is blocked (some shared hosting).
    // Flutter apps should use this if SSE doesn't work.
    public function poll(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $lastId = (int) ($request->getQueryParams()['last_id'] ?? 0);
        $db     = Database::getConnection();

        $stmt = $db->prepare("
            SELECT m.id, m.sender_id, m.receiver_id, m.message, m.is_read, m.created_at,
                   CONCAT(u.first_name, ' ', u.last_name) AS sender_name
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            WHERE m.receiver_id = ? AND m.id > ?
            ORDER BY m.id ASC
            LIMIT 50
        ");
        $stmt->execute([$userId, $lastId]);
        $messages = $stmt->fetchAll();

        // Also return unread notification count
        $unread = $db->prepare('SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0');
        $unread->execute([$userId]);

        return $this->json($response, [
            'messages'      => $messages,
            'last_id'       => empty($messages) ? $lastId : (int) end($messages)['id'],
            'unread_notifs' => (int) $unread->fetchColumn(),
        ]);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function sseEvent(string $event, array $data): void
    {
        echo "event: {$event}\n";
        echo 'data: ' . json_encode($data) . "\n\n";
    }

    private function sseError(Response $response, string $message): Response
    {
        $response->getBody()->write("event: error\ndata: " . json_encode(['error' => $message]) . "\n\n");
        return $response->withHeader('Content-Type', 'text/event-stream')->withStatus(401);
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
