CREATE TABLE students (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    student_name VARCHAR(50)
);

CREATE TABLE courses (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    course_name VARCHAR(100),
    available_seats INT NOT NULL
);

CREATE TABLE enrollments (
    enrollment_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT,
    course_id INT,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
);
INSERT INTO students (student_name) VALUES ('Nguyễn Văn An'), ('Trần Thị Ba');

INSERT INTO courses (course_name, available_seats) VALUES 
('Lập trình C', 25), 
('Cơ sở dữ liệu', 22);

CREATE TABLE enrollment_history (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    enrollment_id INT,
    student_id INT,
    course_id INT,
    action_type VARCHAR(20),
    action_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE student_status (
    student_id INT PRIMARY KEY,
    status ENUM('ACTIVE', 'GRADUATED', 'SUSPENDED'),
    FOREIGN KEY (student_id) REFERENCES students(student_id)
);

INSERT INTO student_status (student_id, status) VALUES
(1, 'ACTIVE'),
(2, 'GRADUATED');

DELIMITER //
CREATE PROCEDURE RegisterCourse (
    IN p_student_name VARCHAR(50),
    IN p_course_name VARCHAR(100)
)
BEGIN
    DECLARE v_student_id INT;
    DECLARE v_course_id INT;
    DECLARE v_available_seats INT;
    DECLARE v_balance DECIMAL(10,2);
    DECLARE v_fee DECIMAL(10,2);
    DECLARE v_enrollment_id INT;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Kiểm tra sinh viên có tồn tại không
    SELECT student_id INTO v_student_id FROM students WHERE student_name = p_student_name;
    IF v_student_id IS NULL THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type) 
        VALUES (NULL, NULL, 'FAILED: Student does not exist');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Học sinh không tồn tại';
    END IF;
    
    -- Kiểm tra môn học có tồn tại không
    SELECT course_id, available_seats INTO v_course_id, v_available_seats FROM courses WHERE course_name = p_course_name;
    IF v_course_id IS NULL THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type) 
        VALUES (v_student_id, NULL, 'FAILED: Course does not exist');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khóa học không tồn tại';
    END IF;
    
    -- Kiểm tra sinh viên đã đăng ký môn học chưa
    SELECT enrollment_id INTO v_enrollment_id FROM enrollments WHERE student_id = v_student_id AND course_id = v_course_id;
    IF v_enrollment_id IS NOT NULL THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type) 
        VALUES (v_student_id, v_course_id, 'FAILED: Already enrolled');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Đã đăng ký';
    END IF;
    
    -- Kiểm tra số lượng chỗ trống
    IF v_available_seats <= 0 THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type) 
        VALUES (v_student_id, v_course_id, 'FAILED: No available seats');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không có chỗ ngồi nào';
    END IF;
    
    -- Kiểm tra số dư tài khoản của sinh viên
    SELECT balance INTO v_balance FROM student_wallets WHERE student_id = v_student_id;
    SELECT fee INTO v_fee FROM course_fees WHERE course_id = v_course_id;
    
    IF v_balance < v_fee THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type) 
        VALUES (v_student_id, v_course_id, 'FAILED: Insufficient balance');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Số dư không đủ';
    END IF;
    
    -- Thực hiện đăng ký môn học
    INSERT INTO enrollments (student_id, course_id) VALUES (v_student_id, v_course_id);
    
    -- Trừ tiền từ tài khoản sinh viên
    UPDATE student_wallets SET balance = balance - v_fee WHERE student_id = v_student_id;
    
    -- Giảm số lượng chỗ trống của môn học
    UPDATE courses SET available_seats = available_seats - 1 WHERE course_id = v_course_id;
    
    -- Ghi vào lịch sử đăng ký
    INSERT INTO enrollment_history (student_id, course_id, action_type) 
    VALUES (v_student_id, v_course_id, 'REGISTERED');
    
    -- Commit transaction
    COMMIT;
END //
DELIMITER ;

CALL RegisterCourse('Nguyễn Văn An', 'Lập trình C');
CALL RegisterCourse('Trần Thị Ba', 'Cơ sở dữ liệu');

SELECT * FROM student_wallets;
