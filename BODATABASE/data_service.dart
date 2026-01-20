-- 1. ลบตารางเก่าทิ้ง (เรียงลำดับให้ถูกเพื่อไม่ให้ติด Foreign Key)
DROP TABLE IF EXISTS check_logs;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS users;

-- =============================================
-- 2. ตารางผู้ใช้งาน (Users)
-- ใช้สำหรับ: เก็บข้อมูลคนล็อกอิน แบ่งยศ (Admin/Checker/User) และคุมการอนุมัติ
-- =============================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,    -- ชื่อเข้าใช้งาน
    password VARCHAR(255) NOT NULL,          -- รหัสผ่าน
    email VARCHAR(100) UNIQUE NOT NULL,      -- อีเมล (ไว้เช็กว่าเป็นคนใน ม. หรือคนนอก)
    fullname VARCHAR(100),                   -- ชื่อ-นามสกุลจริง
    role ENUM('admin', 'checker', 'user') DEFAULT 'user', -- ยศ (แอดมิน/คนตรวจ/อาจารย์)
    is_approved TINYINT(1) DEFAULT 0,        -- สถานะอนุมัติ (0=รอโบกดรับ, 1=เข้าใช้ได้)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP -- วันที่สมัครสมาชิก
);

-- =============================================
-- 3. ตารางสถานที่ (Locations)
-- ใช้สำหรับ: เก็บข้อมูลห้องและชั้น เพื่อให้ระบุที่ตั้งของครุภัณฑ์ได้ชัดเจน
-- =============================================
CREATE TABLE locations (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    floor VARCHAR(50) NOT NULL,              -- ชั้นที่ตั้ง
    room_name VARCHAR(100) NOT NULL          -- ชื่อห้อง (เช่น Room 1951)
);

-- =============================================
-- 4. ตารางครุภัณฑ์ (Assets)
-- ใช้สำหรับ: "ตารางหลัก" เก็บข้อมูลปัจจุบันของของชิ้นนั้นๆ (หน้ากระจก)
-- =============================================
CREATE TABLE assets (
    asset_id VARCHAR(50) PRIMARY KEY,        -- รหัสครุภัณฑ์ (เช่น KUYKRIS) ห้ามซ้ำ!
    asset_type VARCHAR(100),                 -- ประเภท (เช่น คอมพิวเตอร์, แอร์)
    brand_model VARCHAR(100),                -- ยี่ห้อ/รุ่น
    location_id INT,                         -- เชื่อมไปตาราง Locations (อยู่ห้องไหน)
    status VARCHAR(50) DEFAULT 'ปกติ',        -- สถานะปัจจุบัน (ปกติ/ชำรุด/รอซ่อม)
    reporter_name VARCHAR(100),              -- ชื่อคนแจ้งเสีย "คนล่าสุด"
    issue_detail TEXT,                       -- อาการเสีย "ล่าสุด"
    report_date DATETIME,                   -- วันที่แจ้งเสีย "ล่าสุด"
    last_check_date DATETIME,               -- วันที่ Checker เดินมาตรวจสภาพ "ล่าสุด"
    image_url TEXT,                          -- ลิงก์รูปภาพครุภัณฑ์
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

-- =============================================
-- 5. ตารางประวัติการแจ้งซ่อม (Reports)
-- ใช้สำหรับ: เก็บประวัติ "ทุกครั้ง" ที่มีการแจ้งเสีย (ดูย้อนหลังได้ว่าเครื่องนี้เคยพังวันไหนบ้าง)
-- =============================================
CREATE TABLE reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    asset_id VARCHAR(50),                    -- เชื่อมไปตาราง Assets ว่าเครื่องไหนเสีย
    reporter_name VARCHAR(100),              -- ชื่อคนแจ้งเสีย
    issue_detail TEXT,                       -- อาการที่พบ
    report_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- วันที่แจ้ง (ลงอัตโนมัติ)
    status VARCHAR(50) DEFAULT 'รอดำเนินการ',  -- สถานะการซ่อมของรายการนั้นๆ
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id)
);

-- =============================================
-- 6. ตารางประวัติการตรวจสอบ (Check_Logs)
-- ใช้สำหรับ: เก็บประวัติการเดินตรวจสภาพของ Checker (ไว้เช็กการทำงานของเจ้าหน้าที่)
-- =============================================
CREATE TABLE check_logs (
    check_id INT AUTO_INCREMENT PRIMARY KEY,
    asset_id VARCHAR(50),                    -- เชื่อมไปตาราง Assets ว่าตรวจเครื่องไหน
    checker_id INT,                         -- เชื่อมไปตาราง Users ว่าใครเป็นคนตรวจ
    check_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- วันที่ตรวจ (ลงอัตโนมัติ)
    result_status VARCHAR(50) DEFAULT 'ปกติ', -- ผลการตรวจครั้งนั้น
    remark TEXT,                            -- หมายเหตุเพิ่มเติม (เช่น ฝุ่นเยอะ, ปลั๊กหลวม)
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    FOREIGN KEY (checker_id) REFERENCES users(user_id)
);

-- =============================================
-- 7. ข้อมูลเริ่มต้น (ตัวอย่าง)
-- =============================================
INSERT INTO users (username, password, email, fullname, role, is_approved) VALUES 
('admin_bo', '123456', 'bo@u.ac.th', 'โบ ผู้ดูแลระบบ', 'admin', 1),
('checker_rak', '123456', 'rak@u.ac.th', 'รัก ผู้ตรวจสอบ', 'checker', 1);

INSERT INTO locations (floor, room_name) VALUES 
('ชั้น 1', 'Room 1951'),
('ชั้น 1', 'Lab 1');
