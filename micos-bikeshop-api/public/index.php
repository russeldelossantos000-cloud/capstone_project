<?php
declare(strict_types=1);

// ─── CORS: fire immediately before anything else ───────────────────────────
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight — respond and stop immediately
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}
// ──────────────────────────────────────────────────────────────────────────

use Slim\Factory\AppFactory;
use Dotenv\Dotenv;

require __DIR__ . '/../vendor/autoload.php';

$dotenv = Dotenv::createImmutable(__DIR__ . '/../');
$dotenv->SafeLoad();

$basePath = $_ENV['APP_BASE_PATH'] ?? $_SERVER['APP_BASE_PATH'] ?? getenv('APP_BASE_PATH') ?: '';

$app = AppFactory::create();
$app->setBasePath($basePath);
$app->addRoutingMiddleware();
$app->addBodyParsingMiddleware();
$app->addErrorMiddleware(true, true, true);

require __DIR__ . '/../src/Routes/routes.php';

$app->run();
