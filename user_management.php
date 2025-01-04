<?php
require_once 'config.php';
require_once 'email_management.php';

global $conn;

function handleRegistration($data) {
    global $conn;
    
    error_log("Registration attempt: " . print_r($data, true));
    
    try {
        $email = $data['email'];
        $password = $data['password'];
        $userType = $data['user_type'];
        
        // Check if user already exists
        $stmt = $conn->prepare("SELECT user_id FROM bon_users WHERE email = ?");
        $stmt->execute([$email]);
        if ($stmt->fetch()) {
            error_log("User already exists: $email");
            return ['success' => false, 'message' => 'User already exists', 'action' => 'login_or_reset'];
        }
        
        // Generate verification code
        $code = generateVerificationCode();
        $expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));
        
        // Insert new user
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        $stmt = $conn->prepare("INSERT INTO bon_users (email, password_hash, name, role, verification_code, verification_expiry, is_verified) VALUES (?, ?, ?, ?, ?, ?, 0)");
        $name = explode('@', $email)[0]; // Use part before @ as the initial name
        
        error_log("Attempting to insert user with data: " . print_r([$email, $hashedPassword, $name, $userType, $code, $expiresAt], true));
        
        $result = $stmt->execute([$email, $hashedPassword, $name, $userType, $code, $expiresAt]);
        
        if ($result) {
            $newUserId = $conn->lastInsertId();
            error_log("User inserted successfully. User ID: $newUserId");
            return ['success' => true, 'message' => 'Registration successful', 'user_id' => $newUserId];
        } else {
            $errorInfo = $stmt->errorInfo();
            error_log("Failed to insert user. Error info: " . print_r($errorInfo, true));
            return ['success' => false, 'message' => 'Failed to register user: ' . $errorInfo[2], 'action' => 'retry'];
        }
    } catch (Exception $e) {
        error_log("Registration error: " . $e->getMessage() . "\n" . $e->getTraceAsString());
        return ['success' => false, 'message' => 'Registration failed: ' . $e->getMessage(), 'action' => 'retry'];
    }
}

function handleVerification($data, $conn) {
    try {
        $email = $data['email'];
        $code = $data['code'];
        
        $user = getUserByEmailAndCode($email, $code);
        
        if (!$user || strtotime($user['verification_expiry']) < time()) {
            incrementFailedAttempts($email);
            $failedAttempts = getFailedAttempts($email);
            
            if ($failedAttempts >= 3) {
                deleteUser($user['user_id']);
                return ['success' => false, 'message' => 'Verification failed. Please register again.'];
            }
            
            return ['success' => false, 'message' => 'Invalid or expired code'];
        }
        
        // Mark user as verified
        if (verifyUser($user['user_id'])) {
            sendWelcomeEmail($email);
            return ['success' => true, 'message' => 'User verified successfully'];
        } else {
            return ['success' => false, 'message' => 'Failed to verify user'];
        }
    } catch (Exception $e) {
        return ['success' => false, 'message' => 'Verification failed: ' . $e->getMessage()];
    }
}

function handleLogin($data, $conn) {
    // Implement login logic here
    // For now, we'll just return a success message
    return ['success' => true, 'message' => 'Login successful'];
}

function generateVerificationCode() {
    return str_pad(mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
}

// Database operations
function getUserByEmail($email) {
    global $conn;
    $stmt = $conn->prepare("SELECT * FROM bon_users WHERE email = ?");
    $stmt->execute([$email]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

function insertUser($email, $hashedPassword, $userType, $code, $expiresAt) {
    global $conn;
    $stmt = $conn->prepare("INSERT INTO bon_users (email, password_hash, name, role, verification_code, verification_expiry, is_verified) VALUES (?, ?, ?, ?, ?, ?, 0)");
    $name = explode('@', $email)[0]; // Use part before @ as the initial name
    $stmt->execute([$email, $hashedPassword, $name, $userType, $code, $expiresAt]);
    return $conn->lastInsertId();
}

function deleteUser($userId) {
    global $conn;
    $stmt = $conn->prepare("DELETE FROM bon_users WHERE user_id = ?");
    $stmt->execute([$userId]);
}

function getUserByEmailAndCode($email, $code) {
    global $conn;
    $stmt = $conn->prepare("SELECT * FROM bon_users WHERE email = ? AND verification_code = ? AND verification_expiry > NOW() AND is_verified = 0");
    $stmt->execute([$email, $code]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

function incrementFailedAttempts($email) {
    global $conn;
    $stmt = $conn->prepare("UPDATE bon_users SET failed_attempts = failed_attempts + 1 WHERE email = ?");
    $stmt->execute([$email]);
}

function getFailedAttempts($email) {
    global $conn;
    $stmt = $conn->prepare("SELECT failed_attempts FROM bon_users WHERE email = ?");
    $stmt->execute([$email]);
    return $stmt->fetchColumn();
}

function verifyUser($userId) {
    global $conn;
    $stmt = $conn->prepare("UPDATE bon_users SET is_verified = 1, verification_code = NULL, verification_expiry = NULL, failed_attempts = 0 WHERE user_id = ?");
    return $stmt->execute([$userId]);
}

function logError($message) {
    error_log(date('[Y-m-d H:i:s] ') . $message . "\n", 3, 'api_error.log');
}