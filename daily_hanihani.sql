
CREATE TABLE daily_hanihani (
       id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
       server CHAR(16) NOT NULL,
       board CHAR(16) NOT NULL,
       thread INT UNSIGNED NOT NULL,
       date DATETIME NOT NULL,
       creator VARCHAR(80) NOT NULL,
       title VARCHAR(255) NOT NULL,
       last_checked DATETIME NOT NULL,

       UNIQUE(server, board, thread)
) DEFAULT CHARACTER SET utf8, AUTO_INCREMENT = 1;
