#!/bin/bash

# Telegram Bot Token
BOT_TOKEN=""


CHAT_ID="YOUR_CHAT_ID"  # Замените на ваш chat ID

cat > /etc/zabbix/alertscripts/telegram.sh << 'EOF'
#!/bin/bash
BOT_TOKEN=""
CHAT_ID="$1"
MESSAGE="$3"
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=${MESSAGE}" \
  -d "parse_mode=HTML"
EOF

chmod +x /etc/zabbix/alertscripts/telegram.sh
chown zabbix:zabbix /etc/zabbix/alertscripts/telegram.sh

echo "Telegram script created. Now configure in Zabbix web interface:"
echo "1. Administration → Media types → Create: Telegram"
echo "2. Type: Webhook, Script: telegram.sh"
echo "3. Parameters: {ALERT.SENDTO}, {ALERT.SUBJECT}, {ALERT.MESSAGE}"
echo "4. Administration → Users → Select user → Media → Add: Telegram"