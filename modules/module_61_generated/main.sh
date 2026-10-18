#!/data/data/com.termux/files/usr/bin/bash
echo "═══ Backup — локальний ═══"
tar -czf ~/cybra_backup_$(date +%s).tar.gz ~/CYBRA/config ~/CYBRA/logs 2>/dev/null
echo "✅ Бекап створено."
read -r _