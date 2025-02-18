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
CREATE PROCEDURE enroll_student(
    IN p_student_name VARCHAR(50),    -- Tham số đầu vào: tên sinh viên
    IN p_course_name VARCHAR(100)     -- Tham số đầu vào: tên môn học
)
BEGIN
    -- Khai báo các biến cần dùng
    DECLARE v_student_id INT;         -- Lưu ID của sinh viên
    DECLARE v_course_id INT;          -- Lưu ID của môn học
    DECLARE v_enrollment_id INT;      -- Lưu ID của bản ghi đăng ký
    DECLARE v_student_status VARCHAR(20);  -- Lưu trạng thái của sinh viên
    DECLARE v_available_seats INT;     -- Lưu số chỗ còn trống
    
    -- Bắt đầu transaction
    START TRANSACTION;
    
    -- Lấy ID của sinh viên dựa vào tên
    SELECT student_id INTO v_student_id 
    FROM students 
    WHERE student_name = p_student_name;
    
    -- Kiểm tra sinh viên có tồn tại không
    IF v_student_id IS NULL THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type)
        VALUES (NULL, NULL, 'FAILED: Student does not exist');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sinh viên không tồn tại';
        ROLLBACK;
    END IF;
    
    -- Lấy thông tin môn học
    SELECT course_id, available_seats 
    INTO v_course_id, v_available_seats
    FROM courses 
    WHERE course_name = p_course_name;
    
    -- Kiểm tra môn học có tồn tại không
    IF v_course_id IS NULL THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type)
        VALUES (v_student_id, NULL, 'FAILED: Course does not exist');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Môn học không tồn tại';
        ROLLBACK;
    END IF;
    
    -- Kiểm tra sinh viên đã đăng ký môn học này chưa
    IF EXISTS (SELECT 1 FROM enrollments 
               WHERE student_id = v_student_id AND course_id = v_course_id) THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type)
        VALUES (v_student_id, v_course_id, 'FAILED: Already enrolled');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sinh viên đã đăng ký môn học này';
        ROLLBACK;
    END IF;
    
    -- Kiểm tra trạng thái của sinh viên
    SELECT status INTO v_student_status 
    FROM student_status 
    WHERE student_id = v_student_id;
    
    -- Kiểm tra sinh viên có đủ điều kiện đăng ký không
    IF v_student_status IN ('GRADUATED', 'SUSPENDED') THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type)
        VALUES (v_student_id, v_course_id, 'FAILED: Student not eligible');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sinh viên không đủ điều kiện đăng ký';
        ROLLBACK;
    END IF;
    
    -- Kiểm tra còn chỗ trống không
    IF v_available_seats <= 0 THEN
        INSERT INTO enrollment_history (student_id, course_id, action_type)
        VALUES (v_student_id, v_course_id, 'FAILED: No available seats');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Môn học đã hết chỗ';
        ROLLBACK;
    END IF;
    
    -- Thực hiện đăng ký
    INSERT INTO enrollments (student_id, course_id)
    VALUES (v_student_id, v_course_id);
    
    SET v_enrollment_id = LAST_INSERT_ID();
    
    -- Cập nhật số chỗ trống
    UPDATE courses 
    SET available_seats = available_seats - 1
    WHERE course_id = v_course_id;
    
    -- Ghi lại lịch sử đăng ký thành công
    INSERT INTO enrollment_history (enrollment_id, student_id, course_id, action_type)
    VALUES (v_enrollment_id, v_student_id, v_course_id, 'REGISTERED');
    
    COMMIT;
    
END //
DELIMITER ;

-- Thử đăng ký thành công cho sinh viên đang học
CALL enroll_student('Nguyễn Văn An', 'Lập trình C');

-- Thử đăng ký cho sinh viên đã tốt nghiệp (sẽ thất bại)
CALL enroll_student('Trần Thị Ba', 'Cơ sở dữ liệu');

-- Kiểm tra kết quả trong các bảng
SELECT * FROM enrollments;      -- Xem danh sách đăng ký
SELECT * FROM courses;          -- Xem số chỗ còn lại của các môn học
SELECT * FROM enrollment_history;  -- Xem lịch sử đăng ký

