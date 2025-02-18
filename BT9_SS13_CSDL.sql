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

-- Thêm dữ liệu vào bảng banks
INSERT INTO banks (bank_id, bank_name, status) VALUES 
(1, 'VietinBank', 'ACTIVE'),   
(2, 'Sacombank', 'ERROR'),    
(3, 'Agribank', 'ACTIVE');   

CREATE TABLE account (
    acc_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_id INT,
    bank_id INT,
    amount_added DECIMAL(15,2),  -- Số tiền vừa được thêm vào
    total_amount DECIMAL(15,2),  -- Tổng số tiền đã nhận
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id),
    FOREIGN KEY (bank_id) REFERENCES banks(bank_id)
);

INSERT INTO account (emp_id, bank_id, amount_added, total_amount) VALUES
(1, 1, 0.00, 12500.00),  
(2, 1, 0.00, 8900.00),   
(3, 1, 0.00, 10200.00),  
(4, 1, 0.00, 15000.00),  
(5, 1, 0.00, 7600.00);

DELIMITER //
CREATE PROCEDURE TransferSalaryAll()
BEGIN
    -- Khai báo biến
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_emp_id INT;
    DECLARE v_salary DECIMAL(10,2);
    DECLARE v_total_salary DECIMAL(15,2);
    DECLARE v_company_balance DECIMAL(15,2);
    DECLARE v_success_count INT DEFAULT 0;
    DECLARE v_bank_id INT;
    
    -- Khai báo con trỏ để duyệt qua tất cả nhân viên
    DECLARE cur_employees CURSOR FOR 
        SELECT e.emp_id, e.salary, a.bank_id
        FROM employees e 
        JOIN account a ON e.emp_id = a.emp_id;
    
    -- Khai báo handler cho cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND 
        SET v_done = TRUE;
        
    -- Khai báo handler cho lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Ghi log lỗi
        INSERT INTO transaction_log (log_message)
        VALUES ('Đã xảy ra lỗi trong quá trình chuyển lương - Giao dịch đã bị hủy bỏ');
        -- Rollback transaction
        ROLLBACK;
        -- Ném lại lỗi
        RESIGNAL;
    END;
    
    -- Bắt đầu transaction
    START TRANSACTION;
    
    -- Tính tổng lương cần trả
    SELECT SUM(salary) INTO v_total_salary 
    FROM employees;
    
    -- Lấy số dư quỹ công ty
    SELECT balance INTO v_company_balance 
    FROM company_funds 
    WHERE fund_id = 1;
    
    -- Kiểm tra quỹ công ty có đủ tiền không
    IF v_company_balance < v_total_salary THEN
        INSERT INTO transaction_log (log_message)
        VALUES (CONCAT('Không đủ tiền. Yêu cầu: ', v_total_salary, ', Có sẵn: ', v_company_balance));
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quỹ công ty không đủ';
    END IF;
    
    -- Mở con trỏ
    OPEN cur_employees;
    
    -- Vòng lặp xử lý từng nhân viên
    salary_loop: LOOP
        -- Lấy dữ liệu nhân viên tiếp theo
        FETCH cur_employees INTO v_emp_id, v_salary, v_bank_id;
        
        -- Kiểm tra điều kiện dừng
        IF v_done THEN
            LEAVE salary_loop;
        END IF;
        
        -- Thêm bản ghi vào payroll (trigger sẽ kiểm tra trạng thái ngân hàng)
        INSERT INTO payroll (emp_id, salary, pay_date)
        VALUES (v_emp_id, v_salary, CURRENT_DATE());
        
        -- Cập nhật tài khoản nhân viên
        UPDATE account 
        SET amount_added = v_salary,
            total_amount = total_amount + v_salary
        WHERE emp_id = v_emp_id;
        
        -- Cập nhật ngày trả lương cho nhân viên
        UPDATE employees 
        SET last_pay_date = CURRENT_DATE()
        WHERE emp_id = v_emp_id;
        
        -- Tăng số lượng nhân viên đã nhận lương
        SET v_success_count = v_success_count + 1;
        
    END LOOP salary_loop;
    
    -- Đóng con trỏ
    CLOSE cur_employees;
    
    -- Trừ tổng tiền lương khỏi quỹ công ty
    UPDATE company_funds 
    SET balance = balance - v_total_salary
    WHERE fund_id = 1;
    
    -- Ghi log thành công
    INSERT INTO transaction_log (log_message)
    VALUES (CONCAT('Đã chuyển lương thành công ', v_success_count, 
           ' nhân viên. Tổng số tiền chuyển: ', v_total_salary));
    
    -- Commit transaction nếu mọi thứ OK
    COMMIT;
    
END //
DELIMITER ;

-- Gọi thủ tục
CALL TransferSalaryAll();

-- Kiểm tra kết quả
SELECT * FROM company_funds;
SELECT * FROM payroll;
SELECT * FROM account;
SELECT * FROM transaction_log;