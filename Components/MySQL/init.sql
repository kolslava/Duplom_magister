-- components/mysql/init.sql
CREATE DATABASE IF NOT EXISTS fleetdm;
-- ## ЗМІНА ТУТ: Використовуємо 'nac_user' замість змінної ##
GRANT ALL PRIVILEGES ON fleetdm.* TO 'nac_user'@'%';
FLUSH PRIVILEGES;