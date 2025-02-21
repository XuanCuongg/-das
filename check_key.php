<?php
header('Content-Type: application/json');

class ApiKeyManager {
    private $db;
    private $config = [
        'hostname' => 'localhost',
        'username' => 'xuancuo3_apikey',
        'password' => 'xuancuo3_apikey',
        'database' => 'xuancuo3_apikey'
    ];

    public function __construct() {
        $this->connectDatabase();
    }

    private function connectDatabase() {
        try {
            $this->db = new mysqli(
                $this->config['hostname'],
                $this->config['username'],
                $this->config['password'],
                $this->config['database']
            );

            if ($this->db->connect_error) {
                throw new Exception('Database connection failed: ' . $this->db->connect_error);
            }

            $this->db->set_charset('utf8mb4');
        } catch (Exception $e) {
            $this->jsonResponse('error', $e->getMessage());
            exit;
        }
    }

    private function jsonResponse($status, $message, $data = []) {
        $response = array_merge(
            ['status' => $status, 'msg' => $message],
            $data
        );
        echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    }

    private function validateInput($key, $uuid) {
        if (empty($key)) {
            $this->jsonResponse('error', 'Vui lòng nhập key !');
            return false;
        }

        if (empty($uuid)) {
            $this->jsonResponse('error', 'Vui lòng nhập UUID !');
            return false;
        }

        return true;
    }

    private function getKeyInfo($key) {
        $stmt = $this->db->prepare("SELECT * FROM `key_server` WHERE `name_key` = ?");
        $stmt->bind_param("s", $key);
        $stmt->execute();
        $result = $stmt->get_result();
        $keyInfo = $result->fetch_assoc();
        $stmt->close();

        if (!$keyInfo) {
            $this->jsonResponse('error', 'Key không tồn tại trên hệ thống.');
            return false;
        }

        return $keyInfo;
    }

    private function checkKeyExpiration($keyInfo) {
        $currentTime = time();
        $endTime = strtotime($keyInfo['expired_date']);

        if ($keyInfo['status'] === 'off' || $currentTime >= $endTime) {
            if ($currentTime >= $endTime) {
                $stmt = $this->db->prepare("UPDATE `key_server` SET `status` = 'off' WHERE `name_key` = ?");
                $stmt->bind_param("s", $keyInfo['name_key']);
                $stmt->execute();
                $stmt->close();
            }

            $this->jsonResponse('error', 'Key đã hết hạn, hãy mua key mới !', [
                'created_at' => $keyInfo['created_at'],
                'expired_date' => $keyInfo['expired_date']
            ]);
            return false;
        }

        return $endTime;
    }

    private function handleDevices($keyInfo, $uuid) {
        $deviceList = array_filter(explode(',', $keyInfo['devices']));
        
        if (!in_array($uuid, $deviceList)) {
            if (count($deviceList) >= $keyInfo['amount']) {
                $this->jsonResponse('error', 'Số lượng thiết bị sử dụng key đã đạt giới hạn !');
                return false;
            }
            $deviceList[] = $uuid;
        }

        return implode(',', $deviceList);
    }

    private function updateKeyInfo($key, $devices, $remainTime) {
        $stmt = $this->db->prepare("UPDATE `key_server` SET `devices` = ?, `remaintime` = ? WHERE `name_key` = ?");
        $stmt->bind_param("sis", $devices, $remainTime, $key);
        $stmt->execute();
        $stmt->close();
    }

    public function processRequest() {
        try {
            $key = filter_input(INPUT_GET, 'key', FILTER_SANITIZE_STRING);
            $uuid = filter_input(INPUT_GET, 'uuid', FILTER_SANITIZE_STRING);

            if (!$this->validateInput($key, $uuid)) {
                return;
            }

            $keyInfo = $this->getKeyInfo($key);
            if (!$keyInfo) {
                return;
            }

            $endTime = $this->checkKeyExpiration($keyInfo);
            if (!$endTime) {
                return;
            }

            $newDevices = $this->handleDevices($keyInfo, $uuid);
            if (!$newDevices) {
                return;
            }

            $remainTime = $endTime - time();
            $this->updateKeyInfo($key, $newDevices, $remainTime);

            $this->jsonResponse('success', '', [
                'name_key' => $keyInfo['name_key'],
                'devices' => $newDevices,
                'created_at' => $keyInfo['created_at'],
                'expired_date' => $keyInfo['expired_date'],
                'time' => date('Y-m-d H:i:s'),
                'remaintime' => $remainTime
            ]);

        } catch (Exception $e) {
            $this->jsonResponse('error', 'An unexpected error occurred: ' . $e->getMessage());
        }
    }

    public function __destruct() {
        if ($this->db) {
            $this->db->close();
        }
    }
}

// Initialize and run the application
try {
    $apiManager = new ApiKeyManager();
    $apiManager->processRequest();
} catch (Exception $e) {
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'msg' => 'Critical system error: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
