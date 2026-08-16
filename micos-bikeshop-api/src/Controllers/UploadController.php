<?php

namespace App\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class UploadController
{
    private const UPLOAD_DIR  = __DIR__ . '/../../public/uploads/products/';
    private const MAX_SIZE    = 5 * 1024 * 1024; // 5 MB
    private const ALLOWED     = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    private const ALLOWED_EXT = ['jpg', 'jpeg', 'png', 'webp', 'gif'];

    // POST /api/upload/product-image  [admin]
    public function productImage(Request $request, Response $response): Response
    {
        $uploadedFiles = $request->getUploadedFiles();
        $file          = $uploadedFiles['image'] ?? null;

        if (!$file) {
            return $this->json($response, ['error' => 'No image file provided. Field name must be "image".'], 422);
        }

        // Check upload error
        if ($file->getError() !== UPLOAD_ERR_OK) {
            return $this->json($response, ['error' => 'File upload error: ' . $this->uploadErrorMsg($file->getError())], 422);
        }

        // Validate size
        if ($file->getSize() > self::MAX_SIZE) {
            return $this->json($response, ['error' => 'File too large. Maximum size is 5 MB.'], 422);
        }

        // Validate MIME type
        $mime = $file->getClientMediaType();
        if (!in_array($mime, self::ALLOWED, true)) {
            return $this->json($response, ['error' => 'Invalid file type. Only JPG, PNG, WebP and GIF are allowed.'], 422);
        }

        // Validate extension
        $originalName = $file->getClientFilename() ?? 'upload';
        $ext          = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
        if (!in_array($ext, self::ALLOWED_EXT, true)) {
            return $this->json($response, ['error' => 'Invalid file extension.'], 422);
        }

        // Create upload directory if it doesn't exist
        if (!is_dir(self::UPLOAD_DIR)) {
            mkdir(self::UPLOAD_DIR, 0755, true);
        }

        // Generate unique filename to prevent overwrites
        $filename    = uniqid('bike_', true) . '.' . $ext;
        $destination = self::UPLOAD_DIR . $filename;

        // Move the uploaded file
        try {
            $file->moveTo($destination);
        } catch (\Exception $e) {
            return $this->json($response, ['error' => 'Failed to save file: ' . $e->getMessage()], 500);
        }

        // Build public URL
        // ✅ Store only the relative path — device-agnostic
         $imageUrl = "uploads/products/{$filename}";

        return $this->json($response, [
    'message'   => 'Image uploaded successfully.',
    'filename'  => $filename,
    'image_url' => "uploads/products/{$filename}",
], 201);
    }

    // DELETE /api/upload/product-image  [admin]
    // Body: { "filename": "bike_xxx.jpg" }
    public function deleteImage(Request $request, Response $response): Response
    {
        $data     = $request->getParsedBody();
        $filename = basename($data['filename'] ?? ''); // basename prevents path traversal

        if (!$filename) {
            return $this->json($response, ['error' => 'filename is required.'], 422);
        }

        $path = self::UPLOAD_DIR . $filename;

        if (!file_exists($path)) {
            return $this->json($response, ['error' => 'File not found.'], 404);
        }

        unlink($path);

        return $this->json($response, ['message' => 'Image deleted.']);
    }

    // POST /api/upload/chat-image  [admin]
public function chatImage(Request $request, Response $response): Response
{
    $uploadedFiles = $request->getUploadedFiles();
    $file          = $uploadedFiles['image'] ?? null;

    if (!$file) {
        return $this->json($response, ['error' => 'No image file provided.'], 422);
    }

    if ($file->getError() !== UPLOAD_ERR_OK) {
        return $this->json($response, ['error' => 'Upload error: ' . $this->uploadErrorMsg($file->getError())], 422);
    }

    if ($file->getSize() > self::MAX_SIZE) {
        return $this->json($response, ['error' => 'File too large. Maximum 5 MB.'], 422);
    }

    $mime = $file->getClientMediaType();
    if (!in_array($mime, self::ALLOWED, true)) {
        return $this->json($response, ['error' => 'Only JPG, PNG, WebP and GIF allowed.'], 422);
    }

    $ext         = strtolower(pathinfo($file->getClientFilename() ?? 'upload', PATHINFO_EXTENSION));
    $chatDir     = __DIR__ . '/../../public/uploads/chat_images/';

    if (!is_dir($chatDir)) {
        mkdir($chatDir, 0755, true);
    }

    $filename    = uniqid('chat_', true) . '.' . $ext;
    $destination = $chatDir . $filename;

    try {
        $file->moveTo($destination);
    } catch (\Exception $e) {
        return $this->json($response, ['error' => 'Failed to save file: ' . $e->getMessage()], 500);
    }

    return $this->json($response, [
        'message'   => 'Image uploaded successfully.',
        'image_url' => "uploads/chat_images/{$filename}",
    ], 201);
}

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function uploadErrorMsg(int $code): string
    {
        return match ($code) {
            UPLOAD_ERR_INI_SIZE   => 'File exceeds server upload limit.',
            UPLOAD_ERR_FORM_SIZE  => 'File exceeds form upload limit.',
            UPLOAD_ERR_PARTIAL    => 'File was only partially uploaded.',
            UPLOAD_ERR_NO_FILE    => 'No file was uploaded.',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder.',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk.',
            default               => "Unknown error (code $code).",
        };
    }

    private function json(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}
