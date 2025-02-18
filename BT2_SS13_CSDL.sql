CREATE DATABASE ss13_2;

USE ss13_2;

CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(50),
    price DECIMAL(10,2),
    stock INT NOT NULL
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    quantity INT NOT NULL,
    total_price DECIMAL(10,2),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO products (product_name, price, stock) VALUES
('Laptop Dell', 1500.00, 10),
('iPhone 13', 1200.00, 8),
('Samsung TV', 800.00, 5),
('AirPods Pro', 250.00, 20),
('MacBook Air', 1300.00, 7);

-- 2
DELIMITER //
CREATE PROCEDURE pro_transferOrder(IN p_product_id INT, IN p_quantity INT)
BEGIN
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_stock INT;
    START TRANSACTION;
    SELECT price, stock INTO v_price, v_stock 
    FROM products 
    WHERE product_id = p_product_id;
    IF v_stock IS NULL OR v_stock < p_quantity THEN
        ROLLBACK;
    ELSE
        INSERT INTO orders(product_id, quantity, total_price) 
        VALUES (p_product_id, p_quantity, v_price * p_quantity);
        UPDATE products 
        SET stock = stock - p_quantity 
        WHERE product_id = p_product_id;
        COMMIT;
    END IF;
END;
// DELIMITER ;

CALL pro_transferOrder(1, 5);

SELECT * FROM products;
SELECT * FROM orders;