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
class AuthMiddleware implements MiddlewareInterface
{
    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
{
    $authHeader = $request->getHeaderLine('Authorization');

    if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
        return $this->unauthorized('Missing or invalid Authorization header.');
    }

    $token = substr($authHeader, 7);

    try {
        $decoded = JWT::decode($token, new Key((string) Env::get('JWT_SECRET'), 'HS256'));
    } catch (\Exception $e) {
        return $this->unauthorized('Token invalid or expired.');
    }

    $userId = isset($decoded->user_id)  ? $decoded->user_id
            : (isset($decoded->id)      ? $decoded->id
            : (isset($decoded->admin_id)? $decoded->admin_id
            : null));

    if ($userId === null) {
        return $this->unauthorized('Invalid token payload: no user identifier found.');
    }

    $request = $request
        ->withAttribute('user_id', $userId)
        ->withAttribute('role',    $decoded->role ?? 'user')
        ->withAttribute('username',$decoded->username ?? null)
        ->withAttribute('email',   $decoded->email ?? null);

    return $handler->handle($request);
}
    private function unauthorized(string $message): ResponseInterface
    {
        $response = new Response();
        $response->getBody()->write(json_encode(['error' => $message]));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus(401);
    }
}