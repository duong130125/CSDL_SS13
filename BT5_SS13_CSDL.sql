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

ALTER TABLE employees ADD COLUMN last_pay_date DATE;

DELIMITER //
CREATE PROCEDURE PaySalary(IN p_emp_id INT)
BEGIN
    DECLARE v_salary DECIMAL(10,2);
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_employee_exists INT;

    -- Kiểm tra nhân viên có tồn tại hay không
    SELECT COUNT(*), salary INTO v_employee_exists, v_salary 
    FROM employees WHERE emp_id = p_emp_id;

    IF v_employee_exists = 0 THEN
        INSERT INTO transaction_log (log_message) VALUES ('Nhân viên không tồn tại');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nhân viên không tồn tại';
    END IF;

    -- Kiểm tra số dư quỹ công ty
    SELECT balance INTO v_balance FROM company_funds LIMIT 1;

    IF v_balance < v_salary THEN
        INSERT INTO transaction_log (log_message) VALUES ('Quỹ không đủ tiền');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quỹ không đủ tiền';
    END IF;

    -- Bắt đầu giao dịch
    START TRANSACTION;

    -- Trừ số tiền lương từ quỹ công ty
    UPDATE company_funds SET balance = balance - v_salary;

    -- Thêm bản ghi vào bảng payroll
    INSERT INTO payroll (emp_id, salary, pay_date) 
    VALUES (p_emp_id, v_salary, CURDATE());

    -- Cập nhật ngày trả lương cho nhân viên
    UPDATE employees SET last_pay_date = CURDATE() WHERE emp_id = p_emp_id;

    -- Ghi log giao dịch thành công
    INSERT INTO transaction_log (log_message) VALUES ('Chuyển lương cho nhân viên thành công');

    -- Xác nhận giao dịch
    COMMIT;
END //
DELIMITER ;

CALL PaySalary(5);
