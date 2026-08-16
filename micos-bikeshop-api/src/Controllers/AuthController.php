<?php

namespace App\Controllers;

use App\Config\Database;
use App\Services\EmailService;
use Firebase\JWT\JWT;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Config\Env;

class AuthController
{
    public function register(Request $request, Response $response): Response
    {
        $data     = $request->getParsedBody();
       $required = ['email', 'password', 'first_name', 'last_name'];
        foreach ($required as $field) {
            if (empty($data[$field])) {
                return $this->json($response, ['error' => "Field '{$field}' is required."], 422);
            }
        }
        if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            return $this->json($response, ['error' => 'Invalid email address.'], 422);
        }

        if (empty($data['privacy_accepted']) || !$data['privacy_accepted']) {
    return $this->json($response, [
        'error' => 'You must accept the Privacy Policy to register.'
         ], 422);
        }

        $db   = Database::getConnection();
        $chk  = $db->prepare('SELECT id FROM users WHERE email = ?');
        $chk->execute([$data['email']]);
        if ($chk->fetch()) {
            return $this->json($response, ['error' => 'Email is already registered.'], 409);
        }

        $hash = password_hash($data['password'], PASSWORD_BCRYPT);

       $db->prepare('
    INSERT INTO users (email, password, first_name, last_name, phone, address, privacy_accepted, privacy_accepted_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
')->execute([
    $data['email'],
    $hash,
    $data['first_name'],
    $data['last_name'],
    $data['phone']   ?? null,
    $data['address'] ?? null,
    1,
]);
        $userId = (int) $db->lastInsertId();

        $token = (string) random_int(100000, 999999);
        $expiresAt = date('Y-m-d H:i:s', strtotime('+24 hours'));
        $db->prepare('INSERT INTO email_verifications (user_id, token, expires_at) VALUES (?, ?, ?)')->execute([$userId, $token, $expiresAt]);
        try {(new EmailService())->sendVerification($data['email'], $data['first_name'] . ' ' . $data['last_name'], $token); } catch (\Exception $e) {}

        return $this->json($response, [
            'message' => 'Registration successful. Please check your email to verify your account.',
            'user' => ['id' => $userId, 'email' => $data['email'], 'first_name' => $data['first_name'], 'last_name' => $data['last_name']],
        ], 201);
    }

    public function verifyEmail(Request $request, Response $response): Response
    {
        $token = $request->getQueryParams()['token'] ?? '';
        if (!$token) return $this->json($response, ['error' => 'Token is required.'], 422);

        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM email_verifications WHERE token = ? AND used_at IS NULL AND expires_at > NOW()');
        $stmt->execute([$token]);
        $ev = $stmt->fetch();
        if (!$ev) return $this->json($response, ['error' => 'Invalid or expired verification link.'], 400);

        $db->prepare('UPDATE email_verifications SET used_at = NOW() WHERE id = ?')->execute([$ev['id']]);
        $db->prepare('UPDATE users SET is_verified = 1, verified_at = NOW() WHERE id = ?')->execute([$ev['user_id']]);

        $u = $db->prepare('SELECT id, email, first_name, last_name FROM users WHERE id = ?');
        $u->execute([$ev['user_id']]);
        $user = $u->fetch();

        return $this->json($response, [
            'message' => 'Email verified successfully.',
            'token'   => $this->generateUserToken($user['id'], $user['email']),
            'user'    => $user,
        ]);
    }

    public function resendVerification(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();
        if (empty($data['email'])) return $this->json($response, ['error' => 'Email is required.'], 422);

        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id, first_name, last_name, is_verified FROM users WHERE email = ?');
        $stmt->execute([$data['email']]);
        $user = $stmt->fetch();

        if ($user && !$user['is_verified']) {
            $db->prepare('UPDATE email_verifications SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL')->execute([$user['id']]);
           $token = $this->makeOtp();
            $db->prepare('INSERT INTO email_verifications (user_id, token, expires_at) VALUES (?, ?, ?)')->execute([$user['id'], $token, date('Y-m-d H:i:s', strtotime('+24 hours'))]);
            try { (new EmailService())->sendVerification($data['email'], $user['first_name'] . ' ' . $user['last_name'], $token); } catch (\Exception $e) {}
        }

        return $this->json($response, ['message' => 'If the email exists and is unverified, a new link has been sent.']);
    }

    public function login(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();
        if (empty($data['email']) || empty($data['password'])) {
            return $this->json($response, ['error' => 'Email and password are required.'], 422);
        }

        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id, email, password, first_name, last_name, is_verified FROM users WHERE email = ?');
        $stmt->execute([$data['email']]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($data['password'], $user['password'])) {
            return $this->json($response, ['error' => 'Invalid credentials.'], 401);
        }
        if (!$user['is_verified']) {
            return $this->json($response, ['error' => 'Please verify your email before logging in.', 'code' => 'EMAIL_UNVERIFIED'], 403);
        }

        return $this->json($response, [
            'message' => 'Login successful.',
            'token'   => $this->generateUserToken($user['id'], $user['email']),
            'user' => ['id' => $user['id'], 'email' => $user['email'], 'first_name' => $user['first_name'], 'last_name' => $user['last_name']],
        ]);
    }

    public function forgotPassword(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();
        if (empty($data['email'])) return $this->json($response, ['error' => 'Email is required.'], 422);

        $db   = Database::getConnection();
       $stmt = $db->prepare('SELECT id, first_name, last_name FROM users WHERE email = ? AND is_verified = 1');
        $stmt->execute([$data['email']]);
        $user = $stmt->fetch();

        if (!$user) {
            return $this->json($response, ['error' => 'No account found with that email address.'], 404);
        }

        $db->prepare('UPDATE password_resets SET used_at = NOW() WHERE email = ? AND used_at IS NULL')->execute([$data['email']]);
        $token = $this->makeOtp();
        $db->prepare('INSERT INTO password_resets (email, token, expires_at) VALUES (?, ?, ?)')->execute([$data['email'], $token, date('Y-m-d H:i:s', strtotime('+1 hour'))]);
        try { (new EmailService())->sendPasswordReset($data['email'], $user['first_name'] . ' ' . $user['last_name'], $token); } catch (\Exception $e) {}

        return $this->json($response, ['message' => 'Verification code sent to your email.']);
    }

 public function verifyResetOtp(Request $request, Response $response): Response
{
    $data = $request->getParsedBody();

    if (empty($data['token'])) {
        return $this->json($response, ['error' => 'Code is required.'], 422);
    }

    $db   = Database::getConnection();

    // Fetch by token only — no SQL-side expiry check.
    // expires_at is stored by PHP in UTC, but MySQL NOW() runs in
    // Asia/Manila (UTC+8), making every token appear expired immediately.
    // The expiry check is done in PHP below where the timezone matches.
    $stmt = $db->prepare(
        'SELECT id, expires_at, used_at FROM password_resets WHERE token = ? ORDER BY id DESC LIMIT 1'
    );
    $stmt->execute([$data['token']]);
    $pr = $stmt->fetch();

    if (!$pr) {
        return $this->json($response, ['error' => 'Invalid code. Please request a new one.'], 400);
    }

    $usedAt = $pr['used_at'] ?? null;
    if (!empty($usedAt) && $usedAt !== '0000-00-00 00:00:00') {
        return $this->json($response, ['error' => 'This code has already been used. Please request a new one.'], 400);
    }

    // PHP strtotime uses the same UTC runtime as when expires_at was stored.
    if (strtotime($pr['expires_at']) < time()) {
        return $this->json($response, ['error' => 'Code has expired. Please request a new one.'], 400);
    }

    return $this->json($response, ['message' => 'Code verified successfully.']);
}

    public function resetPassword(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();
        if (empty($data['token']) || empty($data['password'])) {
            return $this->json($response, ['error' => 'Token and new password are required.'], 422);
        }
        if (strlen($data['password']) < 8) {
            return $this->json($response, ['error' => 'Password must be at least 8 characters.'], 422);
        }

        $db   = Database::getConnection();
       $stmt = $db->prepare('SELECT * FROM password_resets WHERE token = ? ORDER BY id DESC LIMIT 1');
       $stmt->execute([$data['token']]);
       $pr = $stmt->fetch();
     if (!$pr) return $this->json($response, ['error' => 'Invalid reset code. Please request a new one.'], 400);

      $usedAt = $pr['used_at'] ?? null;
     if (!empty($usedAt) && $usedAt !== '0000-00-00 00:00:00') {
        return $this->json($response, ['error' => 'This code has already been used.'], 400);
    }
     if (strtotime($pr['expires_at']) < time()) {
        return $this->json($response, ['error' => 'Code has expired. Please request a new one.'], 400);
    }
        $db->prepare('UPDATE users SET password = ? WHERE email = ?')->execute([password_hash($data['password'], PASSWORD_BCRYPT), $pr['email']]);
        $db->prepare('UPDATE password_resets SET used_at = NOW() WHERE id = ?')->execute([$pr['id']]);

        return $this->json($response, ['message' => 'Password reset successfully. You can now log in.']);
    }

    public function adminLogin(Request $request, Response $response): Response
    {
        $data = $request->getParsedBody();
        if (empty($data['username']) || empty($data['password'])) {
            return $this->json($response, ['error' => 'Username and password are required.'], 422);
        }

        $db   = Database::getConnection();
        $stmt = $db->prepare('SELECT id, username, password, name FROM admins WHERE username = ?');
        $stmt->execute([$data['username']]);
        $admin = $stmt->fetch();

        if (!$admin || !password_verify($data['password'], $admin['password'])) {
            return $this->json($response, ['error' => 'Invalid admin credentials.'], 401);
        }

        $token = JWT::encode([
            'admin_id' => $admin['id'], 'username' => $admin['username'],
            'role' => 'admin', 'iat' => time(), 'exp' => time() + (int) (Env::get('JWT_EXPIRY', '86400')),
             ], Env::get('JWT_SECRET'), 'HS256');

        return $this->json($response, [
            'message' => 'Admin login successful.',
            'token'   => $token,
            'admin'   => ['id' => $admin['id'], 'username' => $admin['username'], 'name' => $admin['name']],
        ]);
    }

    private function generateUserToken(int $userId, string $email): string
    {
        return JWT::encode(['user_id' => $userId, 'email' => $email, 'role' => 'user', 'iat' => time(), 'exp' => time() + (int) (Env::get('JWT_EXPIRY', '86400')), ], Env::get('JWT_SECRET'), 'HS256');
    }

   private function makeOtp(): string
   {
    return (string) random_int(100000, 999999);
   }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}