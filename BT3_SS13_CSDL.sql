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

DELIMITER //
CREATE PROCEDURE PaySalary(IN p_emp_id INT)
BEGIN
    DECLARE v_salary DECIMAL(10,2);
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_bank_status INT;
    
    -- Lấy mức lương của nhân viên
    SELECT salary INTO v_salary FROM employees WHERE emp_id = p_emp_id;
    
    -- Lấy số dư quỹ công ty
    SELECT balance INTO v_balance FROM company_funds WHERE fund_id = 1;
    
    -- Kiểm tra nếu quỹ không đủ tiền để trả lương
    IF v_balance < v_salary THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Số dư quỹ không đủ để trả lương';
    END IF;
    
    -- Bắt đầu giao dịch
    START TRANSACTION;
    
    -- Trừ lương khỏi quỹ công ty
    UPDATE company_funds SET balance = balance - v_salary WHERE fund_id = 1;
    
    -- Thêm bản ghi vào bảng payroll
    INSERT INTO payroll (emp_id, salary, pay_date) VALUES (p_emp_id, v_salary, CURDATE());
    
    -- Giả lập kiểm tra trạng thái hệ thống ngân hàng
    SET v_bank_status = FLOOR(RAND() * 2); -- Sinh ngẫu nhiên 0 hoặc 1 (giả lập trạng thái hệ thống)
    
    IF v_bank_status = 0 THEN
        -- Nếu hệ thống ngân hàng gặp lỗi, rollback giao dịch
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi hệ thống ngân hàng, giao dịch bị hủy';
    ELSE
        -- Nếu không có lỗi, commit giao dịch
        COMMIT;
    END IF;
END //
DELIMITER ;

CALL PaySalary(1);

SELECT *FROM company_funds;
SELECT *FROM employees;
SELECT *FROM payroll;