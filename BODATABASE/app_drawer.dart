แก้ปัญหารูปภาพการแจ้งปัญหาไม่แสดง
ปัญหา
เมื่อแจ้งปัญหา (Report Problem) และอัปโหลดรูป รูปภาพไม่แสดงในหน้ารายละเอียดครุภัณฑ์

สาเหตุ
Backend บันทึก image_url ใน table reports เท่านั้น
ไม่ได้อัปเดต table assets ด้วย
Frontend ดึงข้อมูลจาก assets แต่ไม่มีฟิลด์ report_images
วิธีแก้ (ต้องทำตามลำดับ)
ขั้นที่ 1: เพิ่มฟิลด์ใหม่ในฐานข้อมูล (โบทำ)
เปิด MySQL และรันคำสั่งนี้:

ALTER TABLE assets 
ADD COLUMN report_images TEXT AFTER image_url;
ขั้นที่ 2: อัปเดต Backend Code (โบทำ)
ในไฟล์ index.js หาบรรทัดที่มี app.post('/api/reports' (ประมาณบรรทัด 270-283)

เปลี่ยนจาก:

const sqlUpdateAsset = "UPDATE assets SET status = 'ชำรุด', reporter_name = ?, issue_detail = ?, report_date = NOW() WHERE asset_id = ?";
db.query(sqlUpdateAsset, [reporter_name, issue_detail, asset_id], (err2) => {
    ...
});
เป็น:

const sqlUpdateAsset = `
    UPDATE assets 
    SET status = 'ชำรุด', 
        reporter_name = ?, 
        issue_detail = ?, 
        report_images = ?,
        report_date = NOW() 
    WHERE asset_id = ?
`;
db.query(sqlUpdateAsset, [reporter_name, issue_detail, image_url, asset_id], (err2) => {
    ...
});
ขั้นที่ 3: Restart Backend (โบทำ)
# หยุด server (Ctrl+C)
# เริ่มใหม่
node index.js
ขั้นที่ 4: ทดสอบ (รักทำ)
Hot Reload แอพ Flutter หรือปิด-เปิดใหม่
กดแจ้งปัญหาครุภัณฑ์ใดก็ได้
เลือกรูปภาพ
บันทึก
เข้าไปดูในหน้ารายละเอียดครุภัณฑ์
ตอนนี้รูปภาพการแจ้งปัญหาควรจะขึ้นแล้ว! ✅
ไฟล์ที่เกี่ยวข้อง
Frontend: 
equipment_detail_screen.dart
 (แก้แล้ว ✅)
Backend: index.js (ต้องแก้ตามขั้นที่ 2)
Database: assets table (ต้องเพิ่มคอลัมน์ตามขั้นที่ 1)
หมายเหตุ
โค้ด Frontend รองรับทั้ง report_images (ใหม่) และ reportImages (เก่า) เพื่อความเข้ากันได้ย้อนหลัง
ถ้ามีข้อมูลเก่าที่แจ้งปัญหาไว้แล้ว ต้องแจ้งใหม่ถึงจะมีรูปขึ้น (เพราะตอนนั้นยังไม่ได้บันทึก report_images)
