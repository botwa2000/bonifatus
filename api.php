<?php
// Enable error handling configuration
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Disable error handling configuration
// error_reporting(0);
// ini_set('display_errors', 0);

// Buffer all output
ob_start();


// CORS handling
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Origin, Authorization');
header('Access-Control-Max-Age: 3600');

print_r($_POST); // Temporary debug

// Include the config and email management files
try {
    require_once __DIR__ . '/config.php';
    require_once __DIR__ . '/email_management.php';
} catch (Exception $e) {
    header('HTTP/1.1 200 OK'); // Send 200 instead of 500
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode([
        'success' => false,
        'message' => 'Failed to load configuration',
        'debug_info' => [
            'error_type' => 'config_load_error',
            'details' => $e->getMessage()
        ]
    ]);
    exit;
}

// DB connection check
$dbConnectionInfo = [];  // Store connection info for all responses

try {
    if (!isset($conn)) {
        echo json_encode([
            'success' => false,
            'message' => 'Database connection not established',
            'debug_info' => [
                'connection_status' => 'conn variable is not set',
                'included_files' => get_included_files(),
                'step' => 'initial_check'
            ]
        ]);
        exit;
    }

    if (!($conn instanceof PDO)) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid database connection type',
            'debug_info' => [
                'connection_type' => get_class($conn),
                'expected_type' => 'PDO',
                'step' => 'type_check'
            ]
        ]);
        exit;
    }

    // Test connection with a simple query and store result
    $testStmt = $conn->prepare('SELECT 1 as test');
    $testResult = $testStmt->execute();
    $row = $testStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($testResult && isset($row['test'])) {
        $dbConnectionInfo = [
            'connection_status' => 'Connected',
            'connection_test' => 'passed',
            'test_query_result' => $row['test'],
            'pdo_attributes' => [
                'server_version' => $conn->getAttribute(PDO::ATTR_SERVER_VERSION),
                'connection_status' => $conn->getAttribute(PDO::ATTR_CONNECTION_STATUS),
                'driver_name' => $conn->getAttribute(PDO::ATTR_DRIVER_NAME)
            ]
        ];
    } else {
        $dbConnectionInfo = [
            'connection_status' => 'Failed',
            'query_result' => $row,
            'execute_result' => $testResult
        ];
        throw new Exception('Database query test failed');
    }

} catch (PDOException $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database connection error',
        'debug_info' => [
            'error_type' => 'PDO Exception',
            'error_message' => $e->getMessage(),
            'error_code' => $e->getCode(),
            'connection_info' => $dbConnectionInfo
        ]
    ]);
    exit;
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'General error during database connection check',
        'debug_info' => [
            'error_type' => get_class($e),
            'error_message' => $e->getMessage(),
            'error_code' => $e->getCode(),
            'connection_info' => $dbConnectionInfo
        ]
    ]);
    exit;
}

function executeQuery($conn, $query, $params = [], $defaultReturn = []) {
    try {
        
        if (empty($params)) {
            $stmt = $conn->query($query);
        } else {
            $stmt = $conn->prepare($query);
            $stmt->execute($params);
        }
        
        if (!$stmt) {
            throw new PDOException("Query failed");
        }
        
        $result = $stmt->fetchAll(PDO::FETCH_ASSOC);
        return ['success' => true, 'data' => $result];
    } catch (PDOException $e) {
        return ['success' => true, 'data' => $defaultReturn];
    }
}

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// Define project root directory
define('PROJECT_ROOT', dirname(__DIR__));

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(PROJECT_ROOT);
$dotenv->load();

	
// Process POST request
$input = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $rawInput = file_get_contents('php://input');
        
        $input = json_decode($rawInput, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('JSON decode error: ' . json_last_error_msg());
        }
	} catch (Exception $e) {
			echo json_encode([
				'success' => false,
				'message' => 'Operation failed',
				'debug_info' => [
					'error' => $e->getMessage(),
					'file' => basename($e->getFile()),
					'line' => $e->getLine()
				]
			]);
			exit;
	}
}

	$response = null;

// Data type schemas - define at the top of the file
class DataSchemas {
    const SUBJECT = [
        'subject_id' => 'int',
        'subject_name' => 'string',
        'category_id' => 'int',
        'category_name' => 'string',
        'category_code' => 'string',
        'category_order' => 'int',
        'weight' => 'double'
    ];

    const GRADE_SYSTEM = [
        'system_id' => 'int',
        'system_name' => 'string',
        'calculation_type' => 'string',
        'max_grade' => 'double',
        'min_grade' => 'double',
        'passing_grade' => 'double'
    ];

    const LANGUAGE = [
        'language_id' => 'string',
        'language_name' => 'string',
        'country_code' => 'string',
        'display_order' => 'int',
        'is_active' => 'bool'
    ];

    const USER = [
        'user_id' => 'int',
        'email' => 'string',
        'first_name' => 'string',
        'last_name' => 'string',
        'role' => 'string',
        'status' => 'string',
        'is_verified' => 'bool',
        'failed_attempts' => 'int'
    ];
}

// Add after initial headers and before main code

class TypeConverter {
    public static function toInt($value, $default = 0) {
        return filter_var($value, FILTER_VALIDATE_INT) !== false 
            ? intval($value) 
            : $default;
    }

    public static function toFloat($value, $default = 0.0) {
        return filter_var($value, FILTER_VALIDATE_FLOAT) !== false 
            ? floatval($value) 
            : $default;
    }

    public static function toString($value, $default = '') {
        return $value !== null ? strval($value) : $default;
    }

    public static function toBoolean($value, $default = false) {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? $default;
    }

	public static function cleanSubject($subject) {
		return [
			'subject_id' => self::toInt($subject['subject_id']),
			'subject_name' => self::toString($subject['subject_name']),
			'category_name' => self::toString($subject['category_name']),
			'category_name_translated' => self::toString($subject['category_name_translated']),
			'category_order' => self::toInt($subject['category_order'], 999),
			'weight' => self::toFloat($subject['weight'], 1.0)
		];
	}

    public static function cleanGradeSystem($system) {
        return [
            'system_id' => self::toInt($system['system_id']),
            'system_name' => self::toString($system['system_name']),
            'calculation_type' => self::toString($system['calculation_type']),
            'max_grade' => self::toFloat($system['max_grade']),
            'min_grade' => self::toFloat($system['min_grade']),
            'passing_grade' => self::toFloat($system['passing_grade'])
        ];
    }
	
	public static function sanitizeNumericFields($data) {
		if (!is_array($data)) {
			return $data;
		}

		foreach ($data as $key => $value) {
			if (is_array($value)) {
				$data[$key] = self::sanitizeNumericFields($value);
				continue;
			}

			if (is_numeric($value)) {
				if (strpos($value, '.') !== false) {
					$data[$key] = (float)$value;
				} else {
					$data[$key] = (int)$value;
				}
			}
		}
		
		return $data;
	}	
}

function safeQuery($conn, $query, $params = []) {
    try {
        
        if (empty($params)) {
            $stmt = $conn->query($query);
        } else {
            $stmt = $conn->prepare($query);
            $stmt->execute($params);
        }
        
        $result = $stmt->fetchAll(PDO::FETCH_ASSOC);
        return $result;
    } catch (PDOException $e) {
        return [];
    }
}

// Function to fetch and return data from a specific table
function fetchData($conn, $tableName) {
    try {
        $validTables = [
            'bon_class_factors',
            'bon_default_factors',
            'bon_default_grades',
            'bon_grades',
            'bon_grade_details',
            'bon_grade_factors',
            'bon_grade_system',
            'bon_subjects',
            'bon_tests',
            'bon_students',
            'bon_users',
            'bon_student_requests'
        ];
        
        if (!in_array($tableName, $validTables)) {
            throw new Exception('Invalid table name: ' . $tableName);
        }

        // Test if table exists using a direct query
        $stmt = $conn->query("SHOW TABLES LIKE '$tableName'");
        if ($stmt->rowCount() === 0) {
            throw new Exception("Table $tableName does not exist");
        }

        $stmt = $conn->query("SELECT * FROM $tableName");
        if ($stmt === false) {
            throw new PDOException("Failed to execute query for $tableName");
        }
        
        $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
        // Only log row count
        return $data;
    } catch (PDOException $e) {
        throw new Exception("Database error while fetching from $tableName: " . $e->getMessage());
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function getBonusFactors($conn) {
    try {
        $result = [];

        // Fetch subjects with categories
        $stmt = $conn->prepare("
            SELECT 
                s.*,
                CAST(s.weight AS DECIMAL(10,2)) as weight,
                sc.category_name,
                sc.category_code,
                CAST(sc.display_order AS SIGNED) as category_order
            FROM bon_subjects s
            LEFT JOIN bon_subject_categories sc ON s.category_id = sc.category_id
            WHERE s.status = 'active'
            ORDER BY sc.display_order, s.subject_name
        ");
        $stmt->execute();
        $result['bon_subjects'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Sanitize subjects
        $result['bon_subjects'] = array_map(function($subject) {
            $subject['subject_id'] = (int)$subject['subject_id'];
            $subject['category_id'] = (int)$subject['category_id'];
            $subject['category_order'] = (int)$subject['category_order'];
            $subject['weight'] = (float)$subject['weight'];
            return $subject;
        }, $result['bon_subjects']);

        // Fetch grade details
        $stmt = $conn->prepare("
            SELECT gd.* 
            FROM bon_grade_details gd
            ORDER BY gd.system_id, gd.grade_value
        ");
        $stmt->execute();
        $result['bon_grade_details'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch grade systems
        $stmt = $conn->prepare("
            SELECT * FROM bon_grade_system 
            ORDER BY system_id
        ");
        $stmt->execute();
        $result['bon_grade_system'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch default grades
        $stmt = $conn->prepare("
            SELECT * FROM bon_default_grades 
            ORDER BY grade_id
        ");
        $stmt->execute();
        $result['bon_default_grades'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch default factors
        $stmt = $conn->prepare("
            SELECT * FROM bon_default_factors 
            ORDER BY factor_id
        ");
        $stmt->execute();
        $result['bon_default_factors'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch class factors
        $stmt = $conn->prepare("
            SELECT * FROM bon_class_factors 
            ORDER BY class_id
        ");
        $stmt->execute();
        $result['bon_class_factors'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $result = TypeConverter::sanitizeNumericFields($result);
		return [
			'success' => true,
			'message' => 'Bonus factors retrieved successfully',
			'data' => $result
		];
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleRegistration($conn, $data) {
    
    try {
        $email = $data['email'];
        $password = $data['password'];
        $userType = $data['user_type'];
        
        // Set default names based on email if not provided
        $emailParts = explode('@', $email);
        $firstName = $data['first_name'] ?? $emailParts[0];
        $lastName = $data['last_name'] ?? '';
        
        // Check if user already exists
        $stmt = $conn->prepare("SELECT user_id, is_verified FROM bon_users WHERE email = ?");
        $stmt->execute([$email]);
        $existingUser = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($existingUser) {
            if ($existingUser['is_verified']) {
                return ['success' => false, 'message' => 'User already exists', 'action' => 'login_or_reset'];
            } else {
                // User exists but is not verified, generate new code and update
                $code = str_pad(mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
                $expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));
                
                $updateStmt = $conn->prepare("UPDATE bon_users SET verification_code = ?, verification_expiry = ? WHERE user_id = ?");
                $updateResult = $updateStmt->execute([$code, $expiresAt, $existingUser['user_id']]);
                
                if ($updateResult) {
                    sendVerificationEmail($email, $code);
                    return ['success' => true, 'message' => 'Verification code resent. Check your email.', 'action' => 'verify', 'user_id' => $existingUser['user_id']];
                } else {
                    return ['success' => false, 'message' => 'Failed to resend verification code', 'action' => 'retry'];
                }
            }
        }
        
        // New user registration
        $code = str_pad(mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
        $expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        
        $stmt = $conn->prepare("INSERT INTO bon_users (
            email, 
            password_hash, 
            first_name, 
            last_name, 
            role, 
            verification_code, 
            verification_expiry, 
            is_verified,
            created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, NULL)");
        $result = $stmt->execute([$email, $hashedPassword, $firstName, $lastName, $userType, $code, $expiresAt]);
        
        if ($result) {
            $newUserId = $conn->lastInsertId();
            
            $emailResult = sendVerificationEmail($email, $code);
            return [
                'success' => true, 
                'message' => 'Registration successful. Check your email for verification code.', 
                'action' => 'verify', 
                'user_id' => $newUserId,
                'email_sent' => $emailResult
            ];
        } else {
            $errorInfo = $stmt->errorInfo();
            return ['success' => false, 'message' => 'Failed to register user: ' . $errorInfo[2], 'action' => 'retry'];
        }
		} catch (Exception $e) {
			return [
				'success' => false,
				'message' => 'Operation failed',
				'debug_info' => [
					'error' => $e->getMessage(),
					'file' => basename($e->getFile()),
					'line' => $e->getLine()
				]
			];
		}
}

// Handle email verification process
function handleVerification($conn, $data) {
    
    try {
        if (!isset($data['email']) || !isset($data['code'])) {
            return [
                'success' => false,
                'message' => 'Email and verification code are required'
            ];
        }

        $email = $data['email'];
        $code = $data['code'];
        
        // Get user details
        $stmt = $conn->prepare("
            SELECT user_id, verification_code, verification_expiry, failed_attempts 
            FROM bon_users 
            WHERE email = ? AND is_verified = 0
        ");
        $stmt->execute([$email]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        

        if (!$user) {
            return [
                'success' => false,
                'message' => 'No pending verification found for this email'
            ];
        }

        if ($user['verification_code'] !== $code) {
            
            $newFailedAttempts = ($user['failed_attempts'] ?? 0) + 1;
            $remainingAttempts = 3 - $newFailedAttempts;
            
            // Update failed attempts
            $updateStmt = $conn->prepare("
                UPDATE bon_users 
                SET failed_attempts = ? 
                WHERE user_id = ?
            ");
            $updateStmt->execute([$newFailedAttempts, $user['user_id']]);
            
            return [
                'success' => false,
                'message' => "Incorrect code. You have $remainingAttempts attempts remaining.",
                'remainingAttempts' => $remainingAttempts
            ];
        }

        if (strtotime($user['verification_expiry']) < time()) {
            return [
                'success' => false,
                'message' => 'Verification code has expired. Please request a new one.'
            ];
        }

        // Verification successful - update user
        $updateStmt = $conn->prepare("
            UPDATE bon_users 
            SET is_verified = 1,
                verification_code = NULL,
                verification_expiry = NULL,
                failed_attempts = 0
            WHERE user_id = ?
        ");
        
        $updateResult = $updateStmt->execute([$user['user_id']]);
        
        if ($updateResult) {
            return [
                'success' => true,
                'message' => 'Email verified successfully',
                'action' => 'login'
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to verify email. Please try again.'
        ];
        
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleGetUserProfile($conn, $data) {
    try {
        if (!isset($data['user_id'])) {
            return ['success' => false, 'message' => 'User ID is required'];
        }

        $stmt = $conn->prepare("
            SELECT user_id, email, first_name, last_name, role, status, creation_date, last_login 
            FROM bon_users 
            WHERE user_id = ? AND status = 'active'
        ");
        $stmt->execute([$data['user_id']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            return ['success' => false, 'message' => 'User not found'];
        }

        // Remove sensitive information
        unset($user['password_hash']);
        
        return [
            'success' => true,
            'data' => $user
        ];
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleUpdateUserProfile($conn, $data) {
    try {
        if (!isset($data['user_id'])) {
            return ['success' => false, 'message' => 'User ID is required'];
        }

        // Validate email uniqueness if email is being changed
        if (isset($data['email'])) {
            $stmt = $conn->prepare("SELECT user_id FROM bon_users WHERE email = ? AND user_id != ?");
            $stmt->execute([$data['email'], $data['user_id']]);
            if ($stmt->fetch()) {
                return ['success' => false, 'message' => 'Email already in use'];
            }
        }

        $updateFields = [];
        $params = [];
        
        // Only include fields that are provided
        if (isset($data['first_name'])) {
            $updateFields[] = "first_name = ?";
            $params[] = $data['first_name'];
        }
        if (isset($data['last_name'])) {
            $updateFields[] = "last_name = ?";
            $params[] = $data['last_name'];
        }
        if (isset($data['email'])) {
            $updateFields[] = "email = ?";
            $params[] = $data['email'];
        }

        if (empty($updateFields)) {
            return ['success' => false, 'message' => 'No fields to update'];
        }

        $params[] = $data['user_id']; // Add user_id for WHERE clause
        
        $stmt = $conn->prepare("
            UPDATE bon_users 
            SET " . implode(", ", $updateFields) . "
            WHERE user_id = ?
        ");
        
        $result = $stmt->execute($params);

        if ($result) {
            return ['success' => true, 'message' => 'Profile updated successfully'];
        } else {
            return ['success' => false, 'message' => 'Failed to update profile'];
        }
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleChangePassword($conn, $data) {
    try {
        if (!isset($data['user_id']) || !isset($data['current_password']) || !isset($data['new_password'])) {
            return ['success' => false, 'message' => 'Missing required fields'];
        }

        // Verify current password
        $stmt = $conn->prepare("SELECT password_hash FROM bon_users WHERE user_id = ?");
        $stmt->execute([$data['user_id']]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($data['current_password'], $user['password_hash'])) {
            return ['success' => false, 'message' => 'Current password is incorrect'];
        }

        // Update password
        $newPasswordHash = password_hash($data['new_password'], PASSWORD_DEFAULT);
        $stmt = $conn->prepare("UPDATE bon_users SET password_hash = ? WHERE user_id = ?");
        $result = $stmt->execute([$newPasswordHash, $data['user_id']]);

        if ($result) {
            return ['success' => true, 'message' => 'Password changed successfully'];
        } else {
            return ['success' => false, 'message' => 'Failed to change password'];
        }
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleDeleteAccount($conn, $data) {
    error_log('Delete account request received with data: ' . print_r($data, true));

    if (!isset($data['user_id']) || !isset($data['password'])) {
        return [
            'success' => false,
            'message' => 'Missing required fields'
        ];
    }

    try {
        $conn->beginTransaction();
        
        // First verify the user exists and get their password hash
        $stmt = $conn->prepare("SELECT password_hash FROM bon_users WHERE user_id = ? AND status = 'active'");
        $stmt->execute([$data['user_id']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            return [
                'success' => false,
                'message' => 'User not found or inactive'
            ];
        }

        // Verify password
        if (!password_verify($data['password'], $user['password_hash'])) {
            return [
                'success' => false,
                'message' => 'Invalid password'
            ];
        }

        // Delete records from bon_grades where the user is the creator
        $stmt = $conn->prepare("DELETE FROM bon_grades WHERE created_by = ?");
        $stmt->execute([$data['user_id']]);

        // Delete records from bon_tests where the user is the creator
        $stmt = $conn->prepare("DELETE FROM bon_tests WHERE created_by = ?");
        $stmt->execute([$data['user_id']]);

        // Delete records from bon_grade_factors where the user is the parent
        $stmt = $conn->prepare("DELETE FROM bon_grade_factors WHERE parent_id = ?");
        $stmt->execute([$data['user_id']]);

        // Delete records from bon_students where the user is either the student or parent
        $stmt = $conn->prepare("DELETE FROM bon_students WHERE student_user_id = ? OR parent_user_id = ?");
        $stmt->execute([$data['user_id'], $data['user_id']]);

        // Finally delete the user
        $stmt = $conn->prepare("DELETE FROM bon_users WHERE user_id = ?");
        $result = $stmt->execute([$data['user_id']]);
        
        if (!$result) {
            throw new Exception('Failed to delete user record');
        }
        
        // Commit the transaction
        $conn->commit();
        
        return [
            'success' => true,
            'message' => 'Account successfully deleted'
        ];
        
    } catch (PDOException $e) {
        $conn->rollBack();
        error_log('PDO Error in handleDeleteAccount: ' . $e->getMessage());
        return [
            'success' => false,
            'message' => 'Database error occurred',
            'debug_info' => $e->getMessage()
        ];
    } catch (Exception $e) {
        $conn->rollBack();
        error_log('General Error in handleDeleteAccount: ' . $e->getMessage());
        return [
            'success' => false,
            'message' => 'Failed to delete account',
            'debug_info' => $e->getMessage()
        ];
    }
}

function handleVerifyResetCode($conn, $data) {
    try {
        if (!isset($data['email']) || !isset($data['code'])) {
            return ['success' => false, 'message' => 'Email and code are required'];
        }

        $stmt = $conn->prepare("
            SELECT user_id 
            FROM bon_users 
            WHERE email = ? 
                AND reset_token = ? 
                AND reset_token_expiry > NOW()
        ");
        $stmt->execute([$data['email'], $data['code']]);

        if ($stmt->fetch()) {
            return ['success' => true, 'message' => 'Code verified successfully'];
        } else {
            return ['success' => false, 'message' => 'Invalid or expired code'];
        }
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleRequestPasswordReset($conn, $data) {
    
    try {
        if (!isset($data['email'])) {
            return ['success' => false, 'message' => 'Email is required'];
        }

        $email = filter_var($data['email'], FILTER_SANITIZE_EMAIL);
        
        // Check if user exists
        $stmt = $conn->prepare("SELECT user_id FROM bon_users WHERE email = ? AND is_verified = 1");
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if ($user) {
            // Generate reset code
            $code = str_pad(mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
            $expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));

            // Store reset code
            $stmt = $conn->prepare("
                UPDATE bon_users 
                SET reset_token = ?, 
                    reset_token_expiry = ? 
                WHERE email = ?
            ");
            $result = $stmt->execute([$code, $expiresAt, $email]);
            
            if ($result) {
                // Send email with reset code
                $emailResult = sendPasswordResetEmail($email, $code);
            } else {
                return [
                    'success' => false,
                    'message' => 'Failed to process reset request'
                ];
            }
        }

        // Always return success to prevent email enumeration
        return [
            'success' => true, 
            'message' => 'If an account exists with this email address, you will receive password reset instructions shortly.'
        ];
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleLogin($conn, $data) {
    try {
        if (!isset($data['email']) || !isset($data['password'])) {
            return ['success' => false, 'message' => 'Email and password are required'];
        }

        $stmt = $conn->prepare("
            SELECT user_id, password_hash, is_verified, first_name, last_name, email, role, status
            FROM bon_users 
            WHERE email = ? 
            AND status = 'active'
        ");
        $stmt->execute([$data['email']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            return ['success' => false, 'message' => 'Invalid credentials'];
        }

        if (!$user['is_verified']) {
            return ['success' => false, 'message' => 'Please verify your email first'];
        }

        if (password_verify($data['password'], $user['password_hash'])) {
            // Update last login timestamp
            $updateStmt = $conn->prepare("
                UPDATE bon_users 
                SET last_login = NOW() 
                WHERE user_id = ?
            ");
            $updateStmt->execute([$user['user_id']]);

            // Remove sensitive data
            unset($user['password_hash']);
            
            // Generate a token
            $token = generateAuthToken($user['user_id']);

            return [
                'success' => true,
                'message' => 'Login successful',
                'data' => [
                    'user_id' => $user['user_id'],
                    'token' => $token,
                    'first_name' => $user['first_name'],
                    'last_name' => $user['last_name'],
                    'email' => $user['email'],
                    'role' => $user['role']
                ]
            ];
        }
        return ['success' => false, 'message' => 'Invalid credentials'];
    } catch (Exception $e) {
        return [
            'success' => false,
            'message' => 'Operation failed',
            'debug_info' => [
                'error' => $e->getMessage(),
                'file' => basename($e->getFile()),
                'line' => $e->getLine()
            ]
        ];
    }
}

// Helper function to generate auth token
function generateAuthToken($userId) {
    // Simple token generation - you might want to use JWT or something more secure
    return hash('sha256', $userId . time() . rand());
}

function handleResetPassword($conn, $data) {
    try {
        if (!isset($data['email']) || !isset($data['code']) || !isset($data['new_password'])) {
            return ['success' => false, 'message' => 'Missing required fields'];
        }

        $stmt = $conn->prepare("
            SELECT user_id 
            FROM bon_users 
            WHERE email = ? 
                AND reset_token = ? 
                AND reset_token_expiry > NOW()
        ");
        $stmt->execute([$data['email'], $data['code']]);
        
        if ($user = $stmt->fetch()) {
            $newPasswordHash = password_hash($data['new_password'], PASSWORD_DEFAULT);
            
            $updateStmt = $conn->prepare("
                UPDATE bon_users 
                SET password_hash = ?,
                    reset_token = NULL,
                    reset_token_expiry = NULL
                WHERE user_id = ?
            ");
            
            if ($updateStmt->execute([$newPasswordHash, $user['user_id']])) {
                return ['success' => true, 'message' => 'Password reset successfully'];
            } else {
                return ['success' => false, 'message' => 'Failed to update password'];
            }
        } else {
            return ['success' => false, 'message' => 'Invalid or expired code'];
        }
	} catch (Exception $e) {
		return [
			'success' => false,
			'message' => 'Operation failed',
			'debug_info' => [
				'error' => $e->getMessage(),
				'file' => basename($e->getFile()),
				'line' => $e->getLine()
			]
		];
	}
}

function handleGetTranslations($conn, $data) {
    try {
		error_log("handleGetTranslations called with data: " . print_r($data, true));

        $languageId = $data['language_id'];
        
        // Get translations
        $stmt = $conn->prepare("
            SELECT translation_key, translation_value 
            FROM bon_translations 
            WHERE language_id = ?
        ");
		
		if (!$stmt) {
			throw new Exception('Failed to prepare translation query: ' . print_r($conn->errorInfo(), true));
		}

		$result = $stmt->execute([$languageId]);
		if (!$result) {
			throw new Exception('Failed to execute translation query: ' . print_r($stmt->errorInfo(), true));
		}
		
        $translations = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $translations[$row['translation_key']] = $row['translation_value'];
        }

        // Get languages
        $stmt = $conn->prepare("
            SELECT language_id, language_name, country_code, display_order, is_active 
            FROM bon_languages 
            WHERE is_active = 1 
            ORDER BY display_order
        ");
        $stmt->execute();
        $languages = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            'success' => true,
            'data' => [
                'translations' => $translations,
                'languages' => $languages
            ]
        ];
	} catch (Exception $e) {
			return [
				'success' => true,
				'data' => [
					'translations' => $translations,
					'languages' => $languages
				],
				'debug_info' => [
					'db_connection' => $dbConnectionInfo
				]
			];
	}
}

function handleGetSubjectsTranslated($conn, $data) {
    try {
        $languageId = TypeConverter::toString($data['language_id'], 'en');
        
        $stmt = $conn->prepare("
            SELECT 
                s.subject_id,
                COALESCE(st.subject_name, s.subject_name) as subject_name,
                sc.category_name,
                COALESCE(ct.name, sc.category_name) as category_name_translated,
                sc.display_order as category_order,
                s.weight
            FROM bon_subjects s
            LEFT JOIN bon_subject_translations st 
                ON s.subject_id = st.subject_id 
                AND st.language_id = ?
            LEFT JOIN bon_subject_categories sc 
                ON s.category_id = sc.category_id
            LEFT JOIN bon_category_translations ct
                ON sc.category_id = ct.category_id
                AND ct.language_id = ?
            WHERE s.status = 'active'
            ORDER BY sc.display_order, s.subject_name
        ");
        $stmt->execute([$languageId, $languageId]);
        $subjects = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            'success' => true,
            'data' => [
                'subjects' => array_map([TypeConverter::class, 'cleanSubject'], $subjects)
            ]
        ];
    } catch (Exception $e) {
        return [
            'success' => false,
            'message' => $e->getMessage()
        ];
    }
}

function handleGetGradeSystemsTranslated($conn, $data) {
    try {
        $languageId = TypeConverter::toString($data['language_id'], 'en');
        
        $stmt = $conn->prepare("
            SELECT 
                gs.*,
                COALESCE(gst.system_name, gs.system_name) as system_name
            FROM bon_grade_system gs
            LEFT JOIN bon_grade_system_translations gst 
                ON gs.system_id = gst.system_id 
                AND gst.language_id = ?
            ORDER BY gs.system_id
        ");
        $stmt->execute([$languageId]);
        $systems = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            'success' => true,
            'data' => [
                'grade_systems' => array_map([TypeConverter::class, 'cleanGradeSystem'], $systems)
            ]
        ];
	} catch (Exception $e) {
		return [
			'success' => true,
			'data' => [
				'translations' => $translations,
				'languages' => $languages
			],
			'debug_info' => [
				'db_connection' => $dbConnectionInfo
			]
		];
	}
}

function handleAddStudent($conn, $data) {
    try {
        error_log("Starting handleAddStudent with data: " . print_r($data, true));

        $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        $requiredFields = ['parent_id', 'first_name', 'last_name', 'login_code'];
        foreach ($requiredFields as $field) {
            if (!isset($data[$field])) {
                return [
                    'success' => false, 
                    'message' => "Missing required field: $field"
                ];
            }
        }

        $conn->beginTransaction();

        // Generate student email
        $studentEmail = "student_{$data['parent_id']}_{$data['login_code']}@parent.bonifatus.com";

        // Verify login code isn't already in use
        $stmt = $conn->prepare("SELECT user_id FROM bon_users WHERE login_code = ?");
        $stmt->execute([$data['login_code']]);
        if ($stmt->fetch()) {
            throw new Exception("Login code already in use");
        }

        // Insert student user
        $stmt = $conn->prepare("
            INSERT INTO bon_users (
                email,
                first_name, 
                last_name,
                role,
                parent_id,
                login_code,
                status,
                is_verified,
                creation_date
            ) VALUES (?, ?, ?, 'student', ?, ?, 'active', 1, NOW())
        ");

        $stmt->execute([
            $studentEmail,
            $data['first_name'],
            $data['last_name'],
            $data['parent_id'],
            $data['login_code']
        ]);

        $studentId = $conn->lastInsertId();

        // Create parent-student relationship
        $stmt = $conn->prepare("
            INSERT INTO bon_parent_student_relationships (
                parent_id,
                student_id,
                status,
                created_at
            ) VALUES (?, ?, 'active', NOW())
        ");

        $stmt->execute([
            $data['parent_id'],
            $studentId
        ]);

        $conn->commit();
        error_log("Transaction committed successfully");

        return [
            'success' => true,
            'message' => 'Student added successfully',
            'data' => [
                'student_id' => $studentId,
                'email' => $studentEmail,
                'login_code' => $data['login_code']
            ]
        ];

    } catch (Exception $e) {
        if ($conn->inTransaction()) {
            $conn->rollBack();
        }
        error_log("Error in handleAddStudent: " . $e->getMessage());
        return [
            'success' => false,
            'message' => $e->getMessage()
        ];
    }
}

function handleCodeLogin($conn, $data) {
    try {
        if (!isset($data['email']) || !isset($data['code'])) {
            return [
                'success' => false,
                'message' => 'Email and code are required'
            ];
        }

        error_log("Code login attempt with email: {$data['email']} and code: {$data['code']}");

        // Get parent user first
        $stmt = $conn->prepare("
            SELECT u.user_id, u.email, u.first_name, u.last_name
            FROM bon_users u
            WHERE u.email = ?
            AND u.role = 'parent'
            AND u.status = 'active'
        ");
        $stmt->execute([$data['email']]);
        $parent = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$parent) {
            error_log("Parent not found for email: {$data['email']}");
            return [
                'success' => false,
                'message' => 'Invalid credentials'
            ];
        }

        // Find student with matching code
        $stmt = $conn->prepare("
            SELECT u.user_id as student_id, u.first_name, u.last_name,
                   u.email, u.login_code, u.parent_id
            FROM bon_users u
            WHERE u.parent_id = ?
            AND u.login_code = ?
            AND u.status = 'active'
            AND u.role = 'student'
        ");
        $stmt->execute([$parent['user_id'], $data['code']]);
        $student = $stmt->fetch(PDO::FETCH_ASSOC);

        error_log("Student lookup result: " . print_r($student, true));

        if ($student) {
            // Generate auth token
            $token = bin2hex(random_bytes(32));

            // Update last login
            $updateStmt = $conn->prepare("
                UPDATE bon_users 
                SET last_login = NOW() 
                WHERE user_id = ?
            ");
            $updateStmt->execute([$student['student_id']]);

            return [
                'success' => true,
                'message' => 'Login successful',
                'data' => [
                    'student_id' => $student['student_id'],
                    'token' => $token,
                    'first_name' => $student['first_name'],
                    'last_name' => $student['last_name'],
                    'email' => $student['email'],
                    'role' => 'student',
                    'uses_parent_email' => true
                ]
            ];
        }

        return [
            'success' => false,
            'message' => 'Invalid credentials'
        ];
    } catch (Exception $e) {
        error_log("Error in handleCodeLogin: " . $e->getMessage());
        return [
            'success' => false,
            'message' => 'Login failed. Please try again.'
        ];
    }
}

function handleGetParentStudents($conn, $data) {
    try {
        if (!isset($data['parent_id'])) {
            return ['success' => false, 'message' => 'Parent ID is required'];
        }

        $stmt = $conn->prepare("
            SELECT 
                u.user_id as student_id,
                u.first_name,
                u.last_name,
                u.email,
                u.login_code,
                CASE WHEN u.parent_id IS NOT NULL THEN 1 ELSE 0 END as uses_parent_email,
                u.creation_date as created_at
            FROM bon_users u
            INNER JOIN bon_parent_student_relationships r 
                ON u.user_id = r.student_id
            WHERE r.parent_id = ?
            AND r.status = 'active'
            AND u.status = 'active'
            ORDER BY u.creation_date DESC
        ");
        
        $stmt->execute([$data['parent_id']]);
        $students = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            'success' => true,
            'data' => $students
        ];
    } catch (Exception $e) {
        error_log("Error in handleGetParentStudents: " . $e->getMessage());
        return [
            'success' => false,
            'message' => 'Failed to get students: ' . $e->getMessage()
        ];
    }
}

function handleStudentUpdate($conn, $data) {
    try {
        $conn->beginTransaction();

        // Validate required fields
        if (!isset($data['student_id'])) {
            throw new Exception('Student ID is required');
        }

        // Verify student exists
        $stmt = $conn->prepare("SELECT * FROM bon_users WHERE user_id = ?");
        $stmt->execute([$data['student_id']]);
        $student = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$student) {
            throw new Exception('Student not found');
        }

        // Update the user record
        $updateFields = [];
        $params = [];

        if (isset($data['first_name'])) {
            $updateFields[] = "first_name = ?";
            $params[] = $data['first_name'];
        }
        
        if (isset($data['last_name'])) {
            $updateFields[] = "last_name = ?";
            $params[] = $data['last_name'];
        }

        // Handle login code and email update
        if (isset($data['login_code'])) {
            // Verify code is not already in use by another student
            $stmt = $conn->prepare("SELECT user_id FROM bon_users WHERE login_code = ? AND user_id != ?");
            $stmt->execute([$data['login_code'], $data['student_id']]);
            if ($stmt->fetch()) {
                throw new Exception('Login code is already in use');
            }

            $updateFields[] = "login_code = ?";
            $params[] = $data['login_code'];
            
            if (isset($data['email'])) {
                $updateFields[] = "email = ?";
                $params[] = $data['email'];
            }
        }

        if (!empty($updateFields)) {
            $params[] = $data['student_id'];
            $query = "UPDATE bon_users SET " . implode(", ", $updateFields) . " WHERE user_id = ?";
            
            $stmt = $conn->prepare($query);
            if (!$stmt->execute($params)) {
                throw new Exception('Failed to update student record');
            }
        }

        // Fetch updated record
        $stmt = $conn->prepare("SELECT * FROM bon_users WHERE user_id = ?");
        $stmt->execute([$data['student_id']]);
        $updatedStudent = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$updatedStudent) {
            throw new Exception('Failed to fetch updated student data');
        }

        $conn->commit();

        return [
            'success' => true,
            'message' => 'Student updated successfully',
            'data' => $updatedStudent
        ];

    } catch (Exception $e) {
        if ($conn->inTransaction()) {
            $conn->rollBack();
        }
        error_log("Error in handleStudentUpdate: " . $e->getMessage());
        return [
            'success' => false,
            'message' => $e->getMessage()
        ];
    }
}

function handleGetParentInfo($conn, $data) {
    try {
        if (!isset($data['student_id'])) {
            return [
                'success' => false,
                'message' => 'Student ID is required'
            ];
        }

        $stmt = $conn->prepare("
            SELECT 
                u.user_id,
                u.email,
                u.first_name,
                u.last_name,
                r.created_at as relationship_since
            FROM bon_users u
            INNER JOIN bon_parent_student_relationships r ON u.user_id = r.parent_id
            WHERE r.student_id = ?
            AND r.status = 'active'
            AND u.status = 'active'
            AND u.role = 'parent'
            LIMIT 1
        ");
        
        $stmt->execute([$data['student_id']]);
        $parent = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($parent) {
            return [
                'success' => true,
                'data' => $parent
            ];
        }

        return [
            'success' => false,
            'message' => 'No parent found'
        ];
    } catch (Exception $e) {
        return [
            'success' => false,
            'message' => 'Failed to get parent information',
            'debug_info' => [
                'error' => $e->getMessage(),
                'file' => basename($e->getFile()),
                'line' => $e->getLine()
            ]
        ];
    }
}

function getSummaryCount($arr, $name) {
    if (!is_array($arr)) return '';
    $count = count($arr);
    return "$name: $count records";
}

function logDataSummary($response) {
    if (!is_array($response) || !isset($response['data'])) return;
    
    $summaries = [];
    foreach ($response['data'] as $key => $value) {
        if (is_array($value)) {
            $summaries[] = "$key: " . count($value) . " records";
        }
    }
    if (!empty($summaries)) {
        error_log("Data retrieved: " . implode(", ", $summaries));
    }
}

function handleTermResults($conn, $data) {
    try {
        // Validate basic requirements
        if (!isset($data['student_id']) || !isset($data['action_type'])) {
            return [
                'success' => false,
                'message' => 'Missing required fields',
                'data' => null
            ];
        }

        $conn->beginTransaction();

        try {
            $testId = null;
            
            // Handle test record
            if ($data['action_type'] === 'create') {
                $testSql = "INSERT INTO bon_tests (
                    student_id, school_year, term, total_score,
                    average_score, bonus_points, grade_system_id,
                    status, created_by, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'final', ?, NOW())";

                $stmt = $conn->prepare($testSql);
                $success = $stmt->execute([
                    $data['student_id'],
                    $data['school_year'],
                    $data['term'],
                    $data['total_score'],
                    $data['average_score'],
                    $data['bonus_points'],
                    $data['grade_system_id'],
                    $data['created_by']
                ]);

                if (!$success) {
                    throw new Exception('Failed to create test record');
                }

                $testId = $conn->lastInsertId();

            } elseif ($data['action_type'] === 'update') {
                $testId = $data['test_id'];
                
                // First verify test exists and belongs to student
                $checkStmt = $conn->prepare(
                    "SELECT test_id FROM bon_tests WHERE test_id = ? AND student_id = ?"
                );
                $checkStmt->execute([$testId, $data['student_id']]);
                
                if (!$checkStmt->fetch()) {
                    throw new Exception('Test record not found or unauthorized');
                }

                // Delete existing grades
                $deleteStmt = $conn->prepare("DELETE FROM bon_grades WHERE test_id = ?");
                $deleteStmt->execute([$testId]);
            }

            // Insert grades
            if (!empty($data['grades'])) {
                $gradeSql = "INSERT INTO bon_grades (
                    test_id, student_id, subject_id, subject, grade,
                    grade_name, percentage_equivalent, term_type,
                    school_year, created_by, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";

                $gradeStmt = $conn->prepare($gradeSql);

                foreach ($data['grades'] as $grade) {
                    $success = $gradeStmt->execute([
                        $testId,
                        $data['student_id'],
                        $grade['subject_id'],
                        $grade['subject'],
                        $grade['grade'],
                        $grade['grade_name'],
                        $grade['percentage_equivalent'],
                        $data['term'],
                        $data['school_year'],
                        $data['created_by']
                    ]);

                    if (!$success) {
                        throw new Exception('Failed to save grade record');
                    }
                }
            }

            $conn->commit();

            return [
                'success' => true,
                'message' => 'Results saved successfully',
                'data' => [
                    'test_id' => $testId,
                    'action' => $data['action_type'],
                    'grades_saved' => count($data['grades'])
                ]
            ];

        } catch (Exception $e) {
            $conn->rollBack();
            throw $e;
        }
    } catch (Exception $e) {
        return [
            'success' => false,
            'message' => $e->getMessage(),
            'data' => null
        ];
    }
}

function handleGetTermResults($conn, $data) {
    try {
        if (!isset($data['student_id'])) {
            return [
                'success' => false,
                'message' => 'Student ID required',
                'data' => null
            ];
        }

        // First get tests
        $stmt = $conn->prepare("
            SELECT * FROM bon_tests 
            WHERE student_id = ? 
            ORDER BY school_year DESC, term DESC
        ");
        $stmt->execute([$data['student_id']]);
        $tests = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $results = [];
        foreach ($tests as $test) {
            // Get grades for each test
            $gradeStmt = $conn->prepare("
                SELECT * FROM bon_grades 
                WHERE test_id = ?
            ");
            $gradeStmt->execute([$test['test_id']]);
            $grades = $gradeStmt->fetchAll(PDO::FETCH_ASSOC);
            
            $test['grades'] = $grades;
            $results[] = $test;
        }

        return [
            'success' => true,
            'message' => 'Results retrieved successfully',
            'data' => $results
        ];

    } catch (Exception $e) {
        return [
            'success' => false,
            'message' => $e->getMessage(),
            'data' => null
        ];
    }
}

function sanitizeNumericFields($data) {
    $numericFields = [
        'subject_id', 'category_id', 'system_id', 'grade_id',
        'category_order', 'display_order', 'user_id', 'parent_id',
        'grade_level', 'school_id'
    ];
    
    if (is_array($data)) {
        foreach ($data as $key => $value) {
            if (in_array($key, $numericFields)) {
                $data[$key] = (int)$value;
            } else if (is_array($value)) {
                $data[$key] = sanitizeNumericFields($value);
            }
        }
    }
    return $data;
}

// Main execution
try {
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        header('HTTP/1.1 200 OK');
        echo json_encode(['success' => true, 'message' => 'OK']);
        exit;
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method. Only POST requests are allowed.');
    }

    if (!$input || !isset($input['action'])) {
        throw new Exception('Missing or invalid action');
    }

    $result = match($input['action']) {
		'add_student' => handleAddStudent($conn, $input),
        'change_password' => handleChangePassword($conn, $input),
        'delete_account' => handleDeleteAccount($conn, $input),
        'get_bonus_factors' => getBonusFactors($conn),
        'get_grade_systems_translated' => handleGetGradeSystemsTranslated($conn, $input),
		'get_parent_info' => handleGetParentInfo($conn, $input),
		'get_parent_students' => handleGetParentStudents($conn, $input),
        'get_subjects_translated' => handleGetSubjectsTranslated($conn, $input),
		'get_term_results' => handleGetTermResults($conn, $input),
        'get_translations' => handleGetTranslations($conn, $input),
        'get_user_profile' => handleGetUserProfile($conn, $input),
        'login' => handleLogin($conn, $input),
		'login_with_code' => handleCodeLogin($conn, $input),
        'register' => handleRegistration($conn, $input),
        'request_password_reset' => handleRequestPasswordReset($conn, $input),
        'reset_password' => handleResetPassword($conn, $input),
        'save_term_results' => handleTermResults($conn, $input),
        'verify' => handleVerification($conn, [
            'email' => $input['email'] ?? '',
            'code' => $input['code'] ?? ''
        ]),
        'verify_reset_code' => handleVerifyResetCode($conn, $input),
		'update_student' => handleStudentUpdate($conn, $input),
        'update_user_profile' => handleUpdateUserProfile($conn, $input),
        default => throw new Exception('Invalid action: ' . $input['action'])
    };

} catch (Exception $e) {
    $result = [
        'success' => false,
        'message' => $e->getMessage(),
        'debug_info' => [
            'error' => $e->getMessage(),
            'file' => basename($e->getFile()),
            'line' => $e->getLine()
        ]
    ];
}

// Clear any buffered output before sending JSON
ob_end_clean();

header('Content-Type: application/json; charset=UTF-8');
echo json_encode($result);
exit;