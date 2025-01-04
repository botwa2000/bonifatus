<?php
require_once 'config.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

function getConfiguredMailer() {
    global $email_config;
    
    $mail = new PHPMailer(true);
    try {
        // Server settings
        $mail->isSMTP();
        $mail->Host = $email_config['host'];
        $mail->SMTPAuth = true;
        $mail->Username = $email_config['username'];
        $mail->Password = $email_config['password'];
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        $mail->Port = $email_config['port'];
        
        // Add debug logging
        $mail->SMTPDebug = 2;
        $mail->Debugoutput = function($str, $level) {
            error_log("PHPMailer Debug: $str");
        };
        
        $mail->setFrom($email_config['username'], 'Bonifatus');
        
        return $mail;
    } catch (Exception $e) {
        error_log("PHPMailer configuration failed: " . $e->getMessage());
        throw new Exception('Email configuration failed. Please contact support.');
    }
}

function sendVerificationEmail($email, $code) {
    try {
        $mail = getConfiguredMailer();
        $mail->addAddress($email);
        $mail->Subject = 'Verify your Bonifatus account';
        $mail->isHTML(true);
        
        $mail->Body = "
            <html>
            <body>
                <h2>Welcome to Bonifatus!</h2>
                <p>Your verification code is: <strong>$code</strong></p>
                <p>This code will expire in 15 minutes.</p>
            </body>
            </html>
        ";
        $mail->AltBody = "Welcome to Bonifatus! Your verification code is: $code\nThis code will expire in 15 minutes.";
        
        $result = $mail->send();
        error_log("Email send attempt to $email completed. Result: " . ($result ? "Success" : "Failed"));
        return $result;
    } catch (Exception $e) {
        error_log("Failed to send verification email to $email. Error: " . $e->getMessage());
        return false;
    }
}

function sendPasswordResetEmail($email, $code) {
    try {
        $mail = getConfiguredMailer();
        $mail->addAddress($email);
        $mail->Subject = 'Password Reset Instructions';
        $mail->isHTML(true);
        
        $mail->Body = "
            <html>
            <body>
                <h2>Password Reset Request</h2>
                <p>We received a request to reset your password for your Bonifatus account.</p>
                <p>Your verification code is: <strong>$code</strong></p>
                <p>This code will expire in 15 minutes.</p>
                <p>If you didn't request this password reset, you can safely ignore this email.</p>
                <br>
                <p>Best regards,<br>The Bonifatus Team</p>
            </body>
            </html>
        ";
        
        $mail->AltBody = "
            Password Reset Request
            
            We received a request to reset your password for your Bonifatus account.
            Your verification code is: $code
            This code will expire in 15 minutes.
            
            If you didn't request this password reset, you can safely ignore this email.
            
            Best regards,
            The Bonifatus Team
        ";
        
        $result = $mail->send();
        error_log("Password reset email send attempt completed. Result: " . ($result ? "Success" : "Failed"));
        return $result;
    } catch (Exception $e) {
        error_log("Failed to send password reset email to $email: " . $e->getMessage());
        error_log("PHPMailer error info: " . $mail->ErrorInfo);
        return false;
    }
}

// If needed in future, add other email-related functions here, such as:
// - sendWelcomeEmail
// - sendAccountDeletionEmail
// - sendPasswordChangeConfirmationEmail
// etc.