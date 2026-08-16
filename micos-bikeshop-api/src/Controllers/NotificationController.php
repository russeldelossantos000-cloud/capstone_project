<?php

namespace App\Controllers;

use App\Config\Database;
use App\Services\EmailService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class NotificationController
{
    // GET /api/notifications  [user]
    public function index(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();

        $stmt = $db->prepare('
            SELECT * FROM notifications
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT 50
        ');
        $stmt->execute([$userId]);
        $notifs = $stmt->fetchAll();

        // Decode JSON data field
        foreach ($notifs as &$n) {
            $n['data'] = $n['data'] ? json_decode($n['data'], true) : null;
        }

        $unread = $db->prepare('SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0');
        $unread->execute([$userId]);

        return $this->json($response, [
            'unread_count'  => (int) $unread->fetchColumn(),
            'notifications' => $notifs,
        ]);
    }

    // PUT /api/notifications/{id}/read  [user]
    public function markRead(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        $db     = Database::getConnection();

        $db->prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?')->execute([$args['id'], $userId]);
        return $this->json($response, ['message' => 'Marked as read.']);
    }

    // PUT /api/notifications/read-all  [user]
    public function markAllRead(Request $request, Response $response): Response
    {
        $userId = $request->getAttribute('user_id');
        Database::getConnection()->prepare('UPDATE notifications SET is_read = 1 WHERE user_id = ?')->execute([$userId]);
        return $this->json($response, ['message' => 'All notifications marked as read.']);
    }

    // DELETE /api/notifications/{id}  [user]
    public function destroy(Request $request, Response $response, array $args): Response
    {
        $userId = $request->getAttribute('user_id');
        Database::getConnection()->prepare('DELETE FROM notifications WHERE id = ? AND user_id = ?')->execute([$args['id'], $userId]);
        return $this->json($response, ['message' => 'Notification deleted.']);
    }

    // ── Static helpers used by other controllers ──────────────────────────────

    /**
     * Create an in-app notification.
     */
    public static function create(int $userId, string $type, string $title, string $message, ?array $data = null): void
    {
        try {
            $db = Database::getConnection();
            $db->prepare('
                INSERT INTO notifications (user_id, type, title, message, data)
                VALUES (?, ?, ?, ?, ?)
            ')->execute([$userId, $type, $title, $message, $data ? json_encode($data) : null]);
        } catch (\Exception $e) {
            // Swallow — notification failure should never break core flow
        }
    }

    /**
     * Notify user of order status change (in-app + email).
     */
    public static function orderStatusChanged(int $userId, int $orderId, string $refNumber, string $status, string $paymentStatus): void
    {
        $labels = [
            'pending'    => 'received',
            'processing' => 'being processed',
            'shipped'    => 'on the way',
            'delivered'  => 'delivered',
            'cancelled'  => 'cancelled',
        ];
        $label = $labels[$status] ?? $status;

        self::create(
            $userId,
            'order_status',
            "Order {$refNumber} is {$label}",
            "Your order status has been updated to {$status}. Payment: {$paymentStatus}.",
            ['order_id' => $orderId, 'reference_number' => $refNumber, 'status' => $status]
        );

        // Send email notification
     
        
    }

    /**
     * Notify user of a new message.
     */
    public static function newMessage(int $receiverId, string $senderName, string $messagePreview): void
    {
        self::create(
            $receiverId,
            'new_message',
            "New message from {$senderName}",
            mb_substr($messagePreview, 0, 100),
            ['sender_name' => $senderName]
        );

        // Send email notification
        try {
            $db   = Database::getConnection();
            $stmt = $db->prepare('SELECT email, first_name, last_name FROM users WHERE id = ?');
            $stmt->execute([$receiverId]);
            $user = $stmt->fetch();

            if ($user) {
                (new EmailService())->sendNewMessageNotification(
                    $user['email'], $user['first_name'] . ' ' . $user['last_name'], $senderName, $messagePreview
                );
            }
        } catch (\Exception $e) {}
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
