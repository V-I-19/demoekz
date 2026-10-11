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
apt-get update

apt-get install -y task-samba-dc

for service in smb nmb krb5kdc slapd bind;
do
  systemctl disable $service --now;
done

rm -f /etc/samba/smb.conf

rm -f /etc/cache/smb.conf

rm -rf /var/lib/samba 
rm -rf /var/cache/samba

mkdir -p /var/lib/samba/sysvol

samba-tool domain provision \
  --realm="AU-TEAM.IRPO" \
  --domain="AU-TEAM" \
  --server-role="dc" \
  --dns-backend="SAMBA_INTERNAL" \
  --option="dns forwarder=192.168.100.2" \
  --adminpass="P@ssw0rd" 

systemctl enable --now samba

/bin/cp -f /var/lib/samba/private/krb5.conf /etc/krb5.conf

systemctl restart samba

cat > "/etc/net/ifaces/enp7s1/resolv.conf" <<EOF
search au-team.irpo
nameserver 77.88.8.8
EOF

systemctl restart network

echo "P@ssw0rd" | kinit Administrator@AU-TEAM.IRPO

samba-tool group add hq

for i in {1..5};
do
  samba-tool user add hquser$i P@ssw0rd;
  samba-tool user setexpiry hquser$i --noexpiry;
  samba-tool group addmembers "hq" hquser$i;
done

cat > /etc/chrony.conf <<EOF
server 172.16.2.1 iburst
EOF

systemctl restart chronyd

apt-get update && apt-get install -y ansible sshpass 

cat > /etc/ansible/inventory.yml <<EOF
Networking:
  hosts:
    hq-rtr:
      ansible_host: 192.168.100.1
      ansible_user: net_admin
      ansible_password: P@ssw0rd
      ansible_port: 2027
    br-rtr:
      ansible_host: 192.168.0.1
      ansible_user: net_admin
      ansible_password: P@ssw0rd
      ansible_port: 2027
Servers:
  hosts:
    hq-srv:
      ansible_host: 192.168.100.2
      ansible_user: sshuser
      ansible_password: P@ssw0rd
      ansible_port: 2027
    br-srv:
      ansible_host: 192.168.0.2
      ansible_user: sshuser
      ansible_password: P@ssw0rd
      ansible_port: 2027
Clients:
  hosts:
    hq-cli:
      ansible_host: 192.168.200.4
      ansible_user: sshuser
      ansible_password: P@ssw0rd
      ansible_port: 2027
EOF

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

cat > /etc/ansible/get.yml <<EOF
- name: Get_hostname
  hosts: hq-srv,hq-cli
  gather_facts: true
  tasks:
    - name: Create info directory
      file:
        path: /etc/ansible/PC_INFO
        state: directory
        mode: '0755'
      delegate_to: localhost
      run_once: true

    - name: Save hostname and ip
      copy:
        dest: /etc/ansible/PC_INFO/{{ ansible_hostname }}.yml
        content: |
          Hostname: {{ ansible_hostname }}
          IP_Address: {{ ansible_default_ipv4.address }}
      delegate_to: localhost
EOF

ansible-playbook /etc/ansible/get.yml

mount /dev/sr0 /mnt

printf '%s\n' \
'#!/bin/bash' \
'' \
'csv_file="$1"' \
'' \
'# Create OU' \
'awk -F '"'"';'"'"' '"'"'NR>1 {print $5}'"'"' "$csv_file" | sort | uniq | while read ou;' \
'do' \
$'\tsamba-tool ou add OU="$ou",DC=au-team,DC=irpo;' \
'done' \
'' \
'# Create Users' \
'while IFS=";" read -r firstName lastName role phone ou street zip city country password;' \
'do' \
$'\tif [ "$firstName" == "First Name" ];' \
$'\tthen' \
$'\t\tcontinue' \
$'\tfi' \
'' \
$'\tusername="${firstName,,}.${lastName,,}"' \
'' \
$'\tsamba-tool user add "$username" P@ssw0rd1 \\' \
$'\t\t--given-name="$firstName" \\' \
$'\t\t--surname="$lastName" \\' \
$'\t\t--telephone-number="$phone" \\' \
$'\t\t--job-title="$role" \\' \
$'\t\t--userou="OU=$ou"' \
$'\tsamba-tool user setexpiry "$username" --noexpiry' \
'done < "$csv_file"' \
> import_user.sh

chmod +x import_user.sh

./import_user.sh /mnt/Users.csv
