<?php

namespace App\Services;

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;
use App\Config\Env;
class EmailService
{
    private function mailer(): PHPMailer
    {
        $mail = new PHPMailer(true);
        $mail->isSMTP();
        $mail->Host       = Env::get('MAIL_HOST')     ?? 'smtp.gmail.com';
        $mail->SMTPAuth   = true;
        $mail->Username   = Env::get('MAIL_USERNAME')  ?? '';
        $mail->Password   = Env::get('MAIL_PASSWORD')  ?? '';
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = (int) (Env::get('MAIL_PORT') ?? 587);
        $mail->setFrom(
            Env::get('MAIL_FROM_ADDRESS') ?? 'noreply@example.com',
            Env::get('MAIL_FROM_NAME')    ?? "Mico's Bike Shop"
        );
        $mail->isHTML(true);
        $mail->CharSet = 'UTF-8';
        return $mail;
    }

    // ── Email Verification ────────────────────────────────────────────────────
   public function sendVerification(string $toEmail, string $toName, string $token): void
{
    $mail = $this->mailer();
    $mail->addAddress($toEmail, $toName);
    $mail->Subject = "Your Mico's Bike Shop verification code";
    $mail->Body    = $this->layout("Verify Your Email", "
        <p style='color:#94a3b8;font-size:15px;margin:0 0 20px'>
            Hi <strong style='color:#e2e8f0'>{$toName}</strong>, thanks for registering!
            Enter this code in the app to verify your account.
        </p>
        <div style='background:#0d1117;border:2px dashed #f97316;border-radius:12px;
             padding:24px;text-align:center;margin-bottom:20px'>
            <p style='color:#64748b;font-size:11px;letter-spacing:3px;margin:0 0 8px'>VERIFICATION CODE</p>
            <p style='color:#f97316;font-size:42px;font-weight:900;letter-spacing:12px;
               margin:0;font-family:monospace'>{$token}</p>
        </div>
        <p style='color:#64748b;font-size:12px;margin:0'>
            This code expires in <strong>24 hours</strong>.<br>
            If you didn't create an account, ignore this email.
        </p>
    ");
    $mail->send();
}
    // ── Password Reset ────────────────────────────────────────────────────────
    // Sends a 6-digit OTP code so the Flutter app handles the full reset
    // flow in-app — no browser redirect or APP_URL needed.
   public function sendPasswordReset(string $toEmail, string $toName, string $token): void
{
    $mail = $this->mailer();
    $mail->addAddress($toEmail, $toName);
    $mail->Subject = "Your Mico's Bike Shop password reset code";
    $mail->Body    = $this->layout("Reset Your Password", "
        <p style='color:#94a3b8;font-size:15px;margin:0 0 20px'>
            Hi <strong style='color:#e2e8f0'>{$toName}</strong>,<br>
            We received a request to reset your password.
            Enter this code in the app to continue.
        </p>
        <div style='background:#0d1117;border:2px dashed #f97316;border-radius:12px;
             padding:24px;text-align:center;margin-bottom:20px'>
            <p style='color:#64748b;font-size:11px;letter-spacing:3px;margin:0 0 8px'>RESET CODE</p>
            <p style='color:#f97316;font-size:42px;font-weight:900;letter-spacing:12px;
               margin:0;font-family:monospace'>{$token}</p>
        </div>
        <p style='color:#64748b;font-size:12px;margin:0'>
            This code expires in <strong>1 hour</strong>.<br>
            If you didn't request a password reset, ignore this email.
        </p>
    ");
    $mail->send();
}
    // ── Order Status Notification ─────────────────────────────────────────────
    public function sendOrderStatusUpdate(
        string $toEmail,
        string $toName,
        string $refNumber,
        string $status,
        string $paymentStatus
    ): void {
        $statusColors = [
            'pending'    => '#eab308',
            'processing' => '#3b82f6',
            'shipped'    => '#a78bfa',
            'delivered'  => '#22c55e',
            'cancelled'  => '#ef4444',
        ];
        $color = $statusColors[$status] ?? '#94a3b8';

        $mail = $this->mailer();
        $mail->addAddress($toEmail, $toName);
        $mail->Subject = "Order {$refNumber} — Status Updated";
        $mail->Body    = $this->layout("Order Update", "
            <p style='color:#94a3b8;font-size:15px;margin:0 0 20px'>
                Hi <strong style='color:#e2e8f0'>{$toName}</strong>, your order status has been updated.
            </p>
            <div style='background:#1c2435;border:1px solid #252d3d;border-radius:8px;padding:20px;margin-bottom:20px'>
                <p style='color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:1.5px;margin:0 0 6px'>Reference</p>
                <p style='color:#f97316;font-size:18px;font-weight:700;font-family:monospace;margin:0 0 16px'>{$refNumber}</p>
                <div style='display:flex;gap:12px;flex-wrap:wrap'>
                    <div>
                        <p style='color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:1.5px;margin:0 0 4px'>Order Status</p>
                        <span style='background:{$color}22;color:{$color};padding:3px 10px;border-radius:4px;
                              font-size:12px;font-weight:700;font-family:monospace;text-transform:uppercase'>
                            {$status}
                        </span>
                    </div>
                    <div>
                        <p style='color:#64748b;font-size:11px;text-transform:uppercase;letter-spacing:1.5px;margin:0 0 4px'>Payment</p>
                        <span style='background:#64748b22;color:#94a3b8;padding:3px 10px;border-radius:4px;
                              font-size:12px;font-weight:700;font-family:monospace;text-transform:uppercase'>
                            {$paymentStatus}
                        </span>
                    </div>
                </div>
            </div>
            <p style='color:#64748b;font-size:12px;margin:0'>
                Thank you for shopping at Mico's Bike Shop!
            </p>
        ");
        $mail->send();
    }

    // ── New Message Notification ───────────────────────────────────────────────
    public function sendNewMessageNotification(
        string $toEmail,
        string $toName,
        string $senderName,
        string $preview
    ): void {
        $mail = $this->mailer();
        $mail->addAddress($toEmail, $toName);
        $mail->Subject = "New message from {$senderName}";
        $mail->Body    = $this->layout("New Message", "
            <p style='color:#94a3b8;font-size:15px;margin:0 0 20px'>
                Hi <strong style='color:#e2e8f0'>{$toName}</strong>,
                you have a new message from <strong style='color:#f97316'>{$senderName}</strong>.
            </p>
            <div style='background:#1c2435;border-left:3px solid #f97316;border-radius:0 8px 8px 0;
                 padding:16px 20px;margin-bottom:20px'>
                <p style='color:#e2e8f0;font-size:14px;margin:0'>
                    " . htmlspecialchars(mb_substr($preview, 0, 120)) . "…
                </p>
            </div>
            <p style='color:#64748b;font-size:12px;margin:0'>
                Log in to reply to this message.
            </p>
        ");
        $mail->send();
    }

    // ── HTML Email Layout ─────────────────────────────────────────────────────
    private function layout(string $heading, string $body): string
    {
        $shopName = htmlspecialchars(Env::get('MAIL_FROM_NAME') ?? "Mico's Bike Shop");
        return <<<HTML
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#0d1117;font-family:'Segoe UI',sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:40px 20px">
      <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%">

        <!-- Header -->
        <tr><td style="background:#161b27;border:1px solid #252d3d;border-radius:12px 12px 0 0;
                        padding:28px 32px;border-bottom:none">
          <p style="margin:0;font-size:22px;font-weight:700;color:#e2e8f0;letter-spacing:2px">
            ⚙ {$shopName}
          </p>
        </td></tr>

        <!-- Body -->
        <tr><td style="background:#161b27;border:1px solid #252d3d;border-top:none;
                        border-bottom:none;padding:32px">
          <h2 style="margin:0 0 20px;font-size:20px;font-weight:700;color:#e2e8f0">{$heading}</h2>
          {$body}
        </td></tr>

        <!-- Footer -->
        <tr><td style="background:#0d1117;border:1px solid #252d3d;border-top:none;
                        border-radius:0 0 12px 12px;padding:18px 32px;text-align:center">
          <p style="margin:0;color:#475569;font-size:12px">
            © {$shopName} · All rights reserved
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>
HTML;
    }
}