<?php

namespace App\Services;

use App\Config\Database;

class InventoryService
{
    /**
     * Centralized stock adjustment — used by ALL controllers.
     * Handles stock update, log insertion, low stock check, and notification.
     */
    public static function adjustStock(
    int $productId,
    string $changeType,
    int $quantity,
    string $transactionType,
    ?string $reason = null,
    ?string $reference = null,
    ?int $supplierId = null,
    ?string $loggedBy = 'System',
    ?int $variantId = null
): void {
    $db = Database::getConnection();
    $qty = abs($quantity);
    $delta = $changeType === 'IN' ? $qty : -$qty;

    if ($variantId !== null) {
        $db->prepare('UPDATE product_variants SET stock = stock + ? WHERE id = ?')
           ->execute([$delta, $variantId]);
    } else {
        $db->prepare('UPDATE products SET stock = stock + ? WHERE id = ?')
           ->execute([$delta, $productId]);
    }

    $db->prepare('
        INSERT INTO inventory_logs
            (product_id, variant_id, change_type, transaction_type, quantity, reason, reference, supplier_id, logged_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ')->execute([
        $productId, $variantId, $changeType, $transactionType, $qty,
        $reason, $reference, $supplierId, $loggedBy,
    ]);

    if ($changeType === 'OUT') {
        self::checkLowStock($db, $productId, $variantId);
    }
}
    private static function checkLowStock(\PDO $db, int $productId, ?int $variantId): void
{
    if ($variantId !== null) {
        $stmt = $db->prepare("
            SELECT pv.stock, pv.variant_type, pv.variant_value, p.product_name, p.stock_threshold
            FROM product_variants pv
            JOIN products p ON p.id = pv.product_id
            WHERE pv.id = ?
        ");
        $stmt->execute([$variantId]);
        $row = $stmt->fetch();
        if (!$row) return;

        if ((int) $row['stock'] <= (int) $row['stock_threshold']) {
            self::writeFirestoreNotification([
                'type'       => 'low_stock',
                'category'   => 'inventory',
                'message'    => "{$row['product_name']} ({$row['variant_type']}: {$row['variant_value']}) is low — {$row['stock']} units remaining",
                'product_id' => $productId,
                'variant_id' => $variantId,
                'stock'      => (int) $row['stock'],
                'read'       => false,
            ]);
        }
        return;
    }

    $stmt = $db->prepare('SELECT product_name, stock, stock_threshold FROM products WHERE id = ?');
    $stmt->execute([$productId]);
    $product = $stmt->fetch();

    if (!$product) return;

    if ((int) $product['stock'] <= (int) $product['stock_threshold']) {
        self::writeFirestoreNotification([
            'type'       => 'low_stock',
            'category'   => 'inventory',
            'message'    => "{$product['product_name']} is low — {$product['stock']} units remaining",
            'product_id' => $productId,
            'stock'      => (int) $product['stock'],
            'read'       => false,
        ]);
    }
}

    public static function writeFirestoreNotification(array $data): void
    {
        try {
            $projectId = 'my-micos-bikeshop';
            $url       = "https://firestore.googleapis.com/v1/projects/{$projectId}/databases/(default)/documents/admin_notifications";

            $fields = [];
            foreach ($data as $key => $value) {
                if (is_bool($value)) {
                    $fields[$key] = ['booleanValue' => $value];
                } elseif (is_int($value)) {
                    $fields[$key] = ['integerValue' => (string) $value];
                } else {
                    $fields[$key] = ['stringValue' => (string) $value];
                }
            }
            $fields['created_at'] = ['stringValue' => date('c')];

            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST           => true,
                CURLOPT_POSTFIELDS     => json_encode(['fields' => $fields]),
                CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
                CURLOPT_TIMEOUT        => 5,
            ]);
            curl_exec($ch);
            curl_close($ch);
        } catch (\Exception $e) {
            // Never break core flow for a notification failure
        }
    }
}