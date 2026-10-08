#!/bin/bash
hostnamectl set-hostname br-srv.au-team.irpo

apt-get update && apt-get install -y chrony tzdata


        
# Настрока часового пояса
timedatectl set-timezone Asia/Krasnoyarsk


systemctl enable --now chronyd
        systemctl restart chronyd
echo "Настройка SSH"

# Создание пользователя sshuser с UID 2027 (МЕНЯЙТЕ ИМЯ И Т.Д В ЗАВИСИМОСТИ ОТ ЗАДАНИЯ)
useradd -u 2027 -m sshuser

# Установка пароля P@ssw0rd без подтверждения
echo "sshuser:P@ssw0rd" | chpasswd

# Добавление в группу wheel
gpasswd -a sshuser wheel

# Настройка sudo без пароля
echo "sshuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Настройка SSH
sed -i 's/#Port 22/Port 2027/' /etc/openssh/sshd_config
sed -i 's/#PermitRootLogin without-password/PermitRootLogin no/' /etc/openssh/sshd_config
echo "AllowUsers sshuser" >> /etc/openssh/sshd_config
echo "MaxAuthTries 2" >> /etc/openssh/sshd_config
echo "Banner /etc/openssh/banner" >> /etc/openssh/sshd_config

# Создание баннера
echo "Authorized access only" > /etc/openssh/banner

# Перезапуск SSH
systemctl restart sshd

echo "Настройка завершена:"
echo "- Пользователь: sshuser (пароль: P@ssw0rd)"
echo "- SSH порт: 2027"
echo "- Root-логин запрещен"
echo "- Баннер создан"


echo "- Скачиваем файл инвентаря"
apt-get update && apt-get install -y ansible sshpass 
cd /etc/ansible
wget raw.githubusercontent.com/19zammik86-source/DEMO/refs/heads/main/inventory.yml

ansible -m ping all

apt-get install -y docker-engine docker-compose-v2

systemctl enable --now docker.service

mount /dev/sr0 /mnt/

docker load < /mnt/docker/site_latest.tar

docker load < /mnt/docker/mariadb_latest.tar

cat > compose.yaml <<EOF
services:
  database:
    container_name: db
    image: mariadb:10.11
    restart: always
    ports:
      - "3306:3306"
    environment:
      MARIADB_DATABASE: "testdb"
      MARIADB_USER: "testc"
      MARIADB_PASSWORD: "P@ssw0rd"
      MARIADB_ROOT_PASSWORD: "toor"

  app:
    container_name: testapp
    image: site:latest
    restart: always
    ports:
      - "8080:8000"
    environment:
      DB_TYPE: "maria"
      DB_HOST: "database"
      DB_PORT: "3306"
      DB_NAME: "testdb"
      DB_USER: "testc"
      DB_PASS: "P@ssw0rd"
    depends_on:
      - database
EOF

docker compose up -d

docker compose ps

cd /etc/ansible
wget raw.githubusercontent.com/19zammik86-source/DEMO/refs/heads/main/get.yml
