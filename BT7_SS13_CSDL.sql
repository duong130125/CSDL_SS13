CREATE TABLE company_funds (
    fund_id INT PRIMARY KEY AUTO_INCREMENT,
    balance DECIMAL(15,2) NOT NULL -- Số dư quỹ công ty
);

CREATE TABLE employees (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_name VARCHAR(50) NOT NULL,   -- Tên nhân viên
    salary DECIMAL(10,2) NOT NULL    -- Lương nhân viên
);

CREATE TABLE payroll (
    payroll_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_id INT,                      -- ID nhân viên (FK)
    salary DECIMAL(10,2) NOT NULL,   -- Lương được nhận
    pay_date DATE NOT NULL,          -- Ngày nhận lương
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
);


INSERT INTO company_funds (balance) VALUES (50000.00);

INSERT INTO employees (emp_name, salary) VALUES
('Nguyễn Văn An', 5000.00),
('Trần Thị Bốn', 4000.00),
('Lê Văn Cường', 3500.00),
('Hoàng Thị Dung', 4500.00),
('Phạm Văn Em', 3800.00);

CREATE TABLE transaction_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT, 
    log_message TEXT NOT NULL,  
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP  
);

CREATE TABLE banks (
    bank_id INT PRIMARY KEY AUTO_INCREMENT,
    bank_name VARCHAR(255) NOT NULL,
    status ENUM('ACTIVE', 'ERROR') DEFAULT 'ACTIVE'
);

-- 3) Thêm dữ liệu vào bảng banks
INSERT INTO banks (bank_id, bank_name, status) VALUES 
(1, 'VietinBank', 'ACTIVE'),   
(2, 'Sacombank', 'ERROR'),    
(3, 'Agribank', 'ACTIVE');   

-- 4) Thêm khóa ngoại bank_id vào bảng company_funds để liên kết với bảng banks
ALTER TABLE company_funds 
ADD COLUMN bank_id INT,
ADD FOREIGN KEY (bank_id) REFERENCES banks(bank_id);

-- 5) Cập nhật dữ liệu trong bảng company_funds
UPDATE company_funds SET bank_id = 1 WHERE balance = 50000.00;
INSERT INTO company_funds (balance, bank_id) VALUES (45000.00, 2);

-- 6) Tạo trigger CheckBankStatus để kiểm tra trạng thái ngân hàng trước khi trả lương
DELIMITER //
CREATE TRIGGER CheckBankStatus
BEFORE INSERT ON payroll
FOR EACH ROW
BEGIN
    -- Khai báo biến để lưu trạng thái ngân hàng
    DECLARE bank_status VARCHAR(10);
    
    -- Lấy trạng thái của ngân hàng hiện tại từ bảng banks
    SELECT b.status INTO bank_status
    FROM banks b
    JOIN company_funds cf ON b.bank_id = cf.bank_id
    LIMIT 1;
    
    -- Kiểm tra nếu ngân hàng đang gặp sự cố
    IF bank_status = 'ERROR' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể xử lý thanh toán - Hệ thống ngân hàng đang gặp sự cố';
    END IF;
END//
DELIMITER ;

-- 7) Tạo stored procedure TransferSalary để xử lý việc chuyển lương
DELIMITER //
CREATE PROCEDURE TransferSalary(IN p_emp_id INT)
BEGIN
    -- Khai báo các biến cần thiết
    DECLARE v_salary DECIMAL(10,2);         -- Lưu lương của nhân viên
    DECLARE v_balance DECIMAL(15,2);        -- Lưu số dư quỹ công ty
    DECLARE v_employee_exists BOOLEAN;       -- Kiểm tra nhân viên tồn tại
    DECLARE exit_handler BOOLEAN DEFAULT FALSE;  -- Biến điều khiển rollback
    
    -- Bắt đầu transaction
    START TRANSACTION;
    
    -- Kiểm tra nhân viên có tồn tại không và lấy mức lương
    SELECT COUNT(*) > 0, salary INTO v_employee_exists, v_salary
    FROM employees 
    WHERE emp_id = p_emp_id;
    
    -- Nếu nhân viên không tồn tại
    IF NOT v_employee_exists THEN
        INSERT INTO transaction_log (log_message) 
        VALUES (CONCAT('Lỗi: Nhân viên có ID ', p_emp_id, ' không tồn tại'));
        SET exit_handler = TRUE;
    END IF;
    
    -- Lấy số dư quỹ công ty
    SELECT balance INTO v_balance
    FROM company_funds
    LIMIT 1;
    
    -- Kiểm tra số dư có đủ để trả lương không
    IF NOT exit_handler AND v_balance < v_salary THEN
        INSERT INTO transaction_log (log_message) 
        VALUES (CONCAT('Lỗi: Không đủ tiền để trả lương cho nhân viên ', p_emp_id));
        SET exit_handler = TRUE;
    END IF;
    
    -- Nếu không có lỗi, tiến hành xử lý thanh toán
    IF NOT exit_handler THEN
        BEGIN
            -- Xử lý các lỗi SQL có thể phát sinh
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            BEGIN
                INSERT INTO transaction_log (log_message) 
                VALUES (CONCAT('Lỗi: Hệ thống ngân hàng gặp sự cố khi xử lý thanh toán cho nhân viên ', p_emp_id));
                SET exit_handler = TRUE;
            END;
            
            -- Thêm bản ghi vào bảng payroll (sẽ kích hoạt trigger CheckBankStatus)
            INSERT INTO payroll (emp_id, salary, pay_date)
            VALUES (p_emp_id, v_salary, CURRENT_DATE());
            
            -- Cập nhật số dư quỹ công ty
            UPDATE company_funds 
            SET balance = balance - v_salary
            WHERE balance = v_balance;
            
            -- Ghi log giao dịch thành công
            INSERT INTO transaction_log (log_message)
            VALUES (CONCAT('Thành công: Đã thanh toán lương ', v_salary, ' cho nhân viên ', p_emp_id));
        END;
    END IF;
    
    -- Quyết định commit hay rollback dựa vào trạng thái xử lý
    IF exit_handler THEN
        ROLLBACK;
    ELSE
        COMMIT;
    END IF;
END//
DELIMITER ;

-- 8) Gọi stored procedure để test
-- Test với nhân viên ID 1
CALL TransferSalary(1); 
-- Test với nhân viên ID 2
CALL TransferSalary(2);