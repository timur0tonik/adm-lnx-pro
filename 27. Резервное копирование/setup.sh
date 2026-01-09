#!/bin/bash
set -euo pipefail

# === Настройки ===
CLIENT_IP="172.17.64.72"
BORG_PASSPHRASE="MyStrongBackupPass123!"
ANSIBLE_DIR="/tmp/ansible"
REPO_PATH="/var/backup/client-etc"

# === 1. Установка Ansible (если отсутствует) ===
if ! command -v ansible >/dev/null 2>&1; then
  echo "[+] Installing Ansible..."
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible
fi

# === 2. Подготовка структуры Ansible ===
echo "[+] Creating Ansible structure..."
mkdir -p "$ANSIBLE_DIR"/{inventory,roles/backup_server/tasks,roles/backup_server/templates,roles/client/tasks}

cd "$ANSIBLE_DIR"

# site.yaml
cat > site.yaml <<'EOF'
---
- name: Configure backup server
  hosts: localhost
  connection: local
  become: yes
  roles:
    - backup_server

- name: Configure client (minimal check)
  hosts: client
  become: yes
  roles:
    - client
EOF

# inventory
cat > inventory/hosts.yaml <<EOF
all:
  children:
    backup_servers:
      hosts:
        localhost:
          ansible_connection: local
    clients:
      hosts:
        client:
          ansible_host: $CLIENT_IP
  vars:
    ansible_user: vagrant
    ansible_ssh_private_key_file: /home/vagrant/.ssh/id_rsa
    ansible_python_interpreter: /usr/bin/python3
EOF

# === 3. Роль backup_server ===
cat > roles/backup_server/tasks/main.yaml <<'EOF'
---
- name: Install borgbackup
  apt:
    name: borgbackup
    state: present
    update_cache: yes

- name: Create /backup-images directory
  file:
    path: /backup-images
    state: directory
    mode: '0755'

- name: Create 2GB disk image (idempotent)
  command: dd if=/dev/zero of=/backup-images/backup.img bs=1M count=2048 status=none
  args:
    creates: /backup-images/backup.img

- name: Attach to loop device (idempotent)
  command: losetup --find --show /backup-images/backup.img
  register: loop_result
  args:
    creates: /backup-images/backup.img.attached

- name: Create attach flag
  file:
    path: /backup-images/backup.img.attached
    state: touch
  when: loop_result.changed

- name: Set loop device fact
  set_fact:
    backup_loop: "{{ loop_result.stdout }}"

- name: Format ext4 (idempotent)
  command: mkfs.ext4 -F {{ backup_loop }}
  args:
    creates: /backup-images/backup.img.formatted

- name: Create format flag
  file:
    path: /backup-images/backup.img.formatted
    state: touch
  when: loop_result.changed

- name: Create /var/backup mount point
  file:
    path: /var/backup
    state: directory
    mode: '0755'

- name: Mount backup volume
  mount:
    path: /var/backup
    src: "{{ backup_loop }}"
    fstype: ext4
    opts: defaults,nofail
    state: mounted

- name: Initialize Borg repository (encrypted)
  command: borg init --encryption=repokey --make-parent-dirs /var/backup/client-etc
  environment:
    BORG_PASSPHRASE: "{{ lookup('env', 'BORG_PASSPHRASE') }}"
  args:
    creates: /var/backup/client-etc/config

- name: Deploy backup script
  copy:
    content: |
      #!/bin/bash
      set -euo pipefail
      REPO="/var/backup/client-etc"
      CLIENT_IP="{{ lookup('env', 'CLIENT_IP') }}"
      BACKUP_NAME="etc-\$(date +%Y-%m-%dT%H:%M:%S)"
      LOG_TAG="backup-borg"
      logger -t "\$LOG_TAG" "Starting backup: \$BACKUP_NAME"
      if borg create --stats --compression lz4 "\$REPO::\$BACKUP_NAME" "vagrant@\$CLIENT_IP:/etc" 2>&1 | logger -t "\$LOG_TAG"; then
        logger -t "\$LOG_TAG" "Backup succeeded"
      else
        logger -t "\$LOG_TAG" "Backup FAILED"
        exit 1
      fi
      logger -t "\$LOG_TAG" "Pruning..."
      borg prune --list --prefix "etc-" --keep-daily=90 --keep-monthly=12 "\$REPO" 2>&1 | logger -t "\$LOG_TAG"
      logger -t "\$LOG_TAG" "Prune completed"
    dest: /usr/local/bin/borg-backup.sh
    mode: '0755'

- name: Deploy systemd service
  copy:
    content: |
      [Unit]
      Description=Borg Backup Service
      After=network.target
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/borg-backup.sh
      Environment=BORG_PASSPHRASE={{ lookup('env', 'BORG_PASSPHRASE') }}
      StandardOutput=journal
      StandardError=journal
      SyslogIdentifier=backup-borg
    dest: /etc/systemd/system/borg-backup.service

- name: Deploy systemd timer (every 5 minutes)
  copy:
    content: |
      [Unit]
      Description=Run Borg Backup every 5 minutes
      Requires=network.target
      [Timer]
      OnBootSec=1min
      OnUnitActiveSec=5min
      AccuracySec=1s
      [Install]
      WantedBy=timers.target
    dest: /etc/systemd/system/borg-backup.timer

- name: Enable and start timer
  systemd:
    daemon_reload: yes
    name: borg-backup.timer
    enabled: yes
    state: started
EOF

# === 4. Роль client (минимальная) ===
cat > roles/client/tasks/main.yaml <<'EOF'
---
- name: Ensure /etc exists and is readable
  stat:
    path: /etc
EOF

# === 5. Настройка SSH для клиента ===
echo "[+] Configuring SSH known_hosts for client..."
ssh-keygen -R "$CLIENT_IP" 2>/dev/null || true
ssh-keyscan -H "$CLIENT_IP" >> ~/.ssh/known_hosts 2>/dev/null || true

# === 6. Запуск playbook ===
echo "[+] Running Ansible playbook..."
export CLIENT_IP="$CLIENT_IP"
export BORG_PASSPHRASE="$BORG_PASSPHRASE"
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts.yaml site.yaml -v

echo "[✓] Setup completed. Check timer status with:"
echo "   systemctl is-active borg-backup.timer"
echo "   journalctl -t backup-borg -f"