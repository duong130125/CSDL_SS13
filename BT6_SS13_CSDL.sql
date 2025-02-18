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

DELIMITER //
CREATE PROCEDURE EnrollStudent(
    IN p_student_id INT,
    IN p_course_id INT,
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_available_seats INT;
    DECLARE v_enrollment_id INT;
    
    START TRANSACTION;
    
    SELECT available_seats INTO v_available_seats
    FROM courses 
    WHERE course_id = p_course_id 
    FOR UPDATE;
    
    IF EXISTS (
        SELECT 1 FROM enrollments 
        WHERE student_id = p_student_id 
        AND course_id = p_course_id
    ) THEN
        SET p_status = 'Sinh viên đã đăng ký khóa học này';
        ROLLBACK;
    ELSEIF v_available_seats <= 0 THEN
        SET p_status = 'Không có chỗ trống trong khóa học này';
        ROLLBACK;
    ELSE
        INSERT INTO enrollments (student_id, course_id)
        VALUES (p_student_id, p_course_id);
        
        SET v_enrollment_id = LAST_INSERT_ID();
        
        UPDATE courses 
        SET available_seats = available_seats - 1
        WHERE course_id = p_course_id;
        
        INSERT INTO enrollment_history 
            (enrollment_id, student_id, course_id, action_type)
        VALUES 
            (v_enrollment_id, p_student_id, p_course_id, 'Tham gia');
        
        SET p_status = 'Đăng ký thành công';
        COMMIT;
    END IF;
END //
DELIMITER ;

CALL EnrollStudent(1, 1, @status);
SELECT @status;

SELECT * FROM courses;

SELECT * FROM enrollment_history;