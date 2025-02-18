CREATE DATABASE ss13_1;

USE ss13_1;

-- 1
CREATE TABLE accounts(
	account_id INT PRIMARY KEY AUTO_INCREMENT,
    account_name VARCHAR(50) NOT NULL,
    balance DECIMAL(10, 2)
);

-- 2
INSERT INTO accounts (account_name, balance) VALUES 
('Nguyễn Văn An', 1000.00),
('Trần Thị Bảy', 500.00);

-- 3
DELIMITER //
CREATE PROCEDURE pro_transferMoney(IN from_account INT, IN to_account INT, IN amount DECIMAL(10, 2))
BEGIN
	START TRANSACTION;
    IF(SELECT COUNT(account_id) FROM accounts WHERE account_id = from_account) = 0
		OR (SELECT COUNT(account_id) FROM accounts WHERE account_id = to_account) = 0 THEN
        ROLLBACK;
	ELSE
		UPDATE accounts
			SET balance = balance - amount WHERE account_id = from_account;
		IF (SELECT balance FROM accounts WHERE account_id = from_account) < amount THEN
			ROLLBACK;
		ELSE
			UPDATE accounts
				SET balance = balance + amount WHERE account_id = to_account;
			COMMIT;
		END IF;
	END IF;
END;
// DELIMITER ;

-- 4
CALL pro_transferMoney(1, 2, 500);
SELECT * FROM accounts;