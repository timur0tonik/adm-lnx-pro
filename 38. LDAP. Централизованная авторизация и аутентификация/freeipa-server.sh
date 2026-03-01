#!/bin/bash
set -eux

IPA_DOMAIN="${IPA_DOMAIN:-example.com}"
IPA_REALM="${IPA_REALM:-EXAMPLE.COM}"
ADMIN_PASS="${ADMIN_PASSWORD:-Vagrant123!}"
DS_PASS="${DS_PASSWORD:-Vagrant123!}"
SERVER_IP="${SERVER_IP:-192.168.50.10}"

# Отключение firewalld на время установки
systemctl stop firewalld || true
systemctl disable firewalld || true

# Настройка хоста и hosts
hostnamectl set-hostname "ipa.${IPA_DOMAIN}"
cat > /etc/hosts <<EOF
127.0.0.1 localhost localhost.localdomain
${SERVER_IP} ipa.${IPA_DOMAIN} ipa
EOF

# Убедимся, что на lo есть адрес ::1
sysctl net.ipv6.conf.lo.disable_ipv6=0
ip link set lo up
if ! ip -6 addr show dev lo | grep -q "::1/128"; then
    ip addr add ::1/128 dev lo || echo "Warning: could not add ::1, continuing..."
fi

# Установка пакетов (без DNS-сервера)
dnf install -y ipa-server bind bind-utils

# Установка FreeIPA (без DNS)
ipa-server-install \
  --hostname="ipa.${IPA_DOMAIN}" \
  --ip-address="${SERVER_IP}" \
  --domain="${IPA_DOMAIN}" \
  --realm="${IPA_REALM}" \
  --admin-password="${ADMIN_PASS}" \
  --ds-password="${DS_PASS}" \
  --unattended \
  --no-host-dns

# Включение firewalld и открытие портов (без DNS)
systemctl enable firewalld --now
firewall-cmd --permanent --add-service={ssh,http,https,ldap,ldaps,kerberos,kpasswd}
firewall-cmd --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,464/tcp}
firewall-cmd --reload

# Доп. задание 3: создание тестового пользователя
echo "Создание тестового пользователя..."
ssh-keygen -t rsa -b 2048 -f /tmp/testkey -N "" -q
TEST_SSH_KEY=$(cat /tmp/testkey.pub)

echo "${ADMIN_PASS}" | kinit admin

ipa user-add testuser --first=Test --last=User --password <<< "${ADMIN_PASS}${ADMIN_PASS}" 2>/dev/null || true
ipa user-mod testuser --sshpubkey="${TEST_SSH_KEY}" 2>/dev/null || true

cp /tmp/testkey /home/vagrant/testuser_key
chown vagrant:vagrant /home/vagrant/testuser_key
chmod 600 /home/vagrant/testuser_key

systemctl restart sssd

echo "=== FreeIPA Server setup completed ==="
echo "Web UI: https://ipa.${IPA_DOMAIN}"
echo "Admin credentials: admin / ${ADMIN_PASS}"
echo "Test user: testuser / ${ADMIN_PASS}${ADMIN_PASS}"
echo "Private key for testuser: /home/vagrant/testuser_key"