#!/bin/bash
# provision-pam.sh — MINIMAL WORKING VERSION
echo "[+] Starting PAM HW provisioning..."

# 1. Обновление
apt-get update -qq

# 2. Пользователи
id timur >/dev/null 2>&1 || { useradd -m -s /bin/bash -G sudo timur; echo "timur:password" | chpasswd; }
id dockeruser >/dev/null 2>&1 || { useradd -m -s /bin/bash dockeruser; echo "dockeruser:dockerpass" | chpasswd; }

# 3. Docker
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker dockeruser

# 4. sudo для dockeruser
echo 'dockeruser ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart docker.service, /usr/bin/docker *' > /etc/sudoers.d/dockeruser
chmod 440 /etc/sudoers.d/dockeruser

# 5. PAM holiday check script
cat > /usr/local/bin/pam-holiday-check <<'EOF'
#!/bin/bash
TODAY=$(date +%Y-%m-%d)
WEEKDAY=$(date +%u)  # 1-7

# Праздники
HOLIDAYS="
2025-12-25
2025-12-26
2026-01-01
"

if [[ $WEEKDAY -ge 1 && $WEEKDAY -le 5 ]]; then exit 0; fi
if echo "$HOLIDAYS" | grep -q "^$TODAY\$"; then exit 0; fi
exit 1
EOF
chmod +x /usr/local/bin/pam-holiday-check

# 6. PAM: pam_exec → pam_time
grep -q pam_exec /etc/pam.d/common-account || \
  sed -i '1i account\trequired\tpam_exec.so quiet /usr/local/bin/pam-holiday-check' /etc/pam.d/common-account

grep -q pam_time /etc/pam.d/common-account || \
  echo "account required pam_time.so" >> /etc/pam.d/common-account

# 7. time.conf
cat > /etc/security/time.conf <<'EOF'
*;*;@sudo;Al0000-2400
*;*;dockeruser;Al0000-2400
*;*;*;!Wd0000-2400|Wd0600-2400
EOF

echo "[✓] Done. Reboot or reload sshd to test."