-- MariaDB schema for IPv6 literal virtual mail hosting
CREATE DATABASE IF NOT EXISTS mailserver CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mailserver;

CREATE TABLE IF NOT EXISTS virtual_domains (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS virtual_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS virtual_aliases (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT NOT NULL,
  source VARCHAR(255) NOT NULL,
  destination VARCHAR(255) NOT NULL,
  UNIQUE KEY unique_alias (domain_id, source),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO virtual_domains (name) VALUES ('internal.invalid');

INSERT INTO virtual_users (domain_id, email, password)
SELECT id, 'alice+IPv6-af49--10@internal.invalid', '$6$18/uO23BxoAif3pT$hnAFXLAYlG.Kwv/tPglWOH91qy/Nap3U1FRhi2AR7sSvsmAJo6k7IxPQUerxPvZCZ1.CGkxaRBZDnr81Hf3gq0'
FROM virtual_domains
WHERE name = 'internal.invalid'
ON DUPLICATE KEY UPDATE password = VALUES(password);

INSERT IGNORE INTO virtual_aliases (domain_id, source, destination)
SELECT id,
       'alice+IPv6-af49--10@internal.invalid',
       'alice+IPv6-af49--10@internal.invalid'
FROM virtual_domains
WHERE name = 'internal.invalid';
