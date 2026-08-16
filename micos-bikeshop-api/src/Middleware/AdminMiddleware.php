<?php

namespace App\Middleware;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;
use Slim\Psr7\Response;
use App\Config\Env;
class AdminMiddleware implements MiddlewareInterface
{
    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
{
    $authHeader = $request->getHeaderLine('Authorization');

    if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
        return $this->error('Missing or invalid Authorization header.', 401);
    }

    $token = substr($authHeader, 7);

    try {
        $decoded = JWT::decode($token, new Key(Env::get('JWT_SECRET'), 'HS256'));
    } catch (\Exception $e) {
        return $this->error('Token invalid or expired.', 401);
    }

    if (!isset($decoded->admin_id) || ($decoded->role ?? '') !== 'admin') {
        return $this->error('Admin access required.', 403);
    }

    $request = $request
        ->withAttribute('admin_id', $decoded->admin_id)
        ->withAttribute('user_id',  $decoded->admin_id)
        ->withAttribute('role',     'admin')
        ->withAttribute('username', $decoded->username ?? null);

    // Now outside the try/catch — a controller exception surfaces as its real error, not a fake 401
    return $handler->handle($request);
}
    

    private function error(string $message, int $status): ResponseInterface
    {
        $response = new Response();
        $response->getBody()->write(json_encode(['error' => $message]));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($status);
    }
}