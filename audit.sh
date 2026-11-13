#!/bin/bash
# CyberPatriot Debian Audit Script (Read-Only)
# Usage: sudo bash 1_audit.sh

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash $0"
    exit 1
fi

OUT="/root/cp_audit"
mkdir -p "$OUT"
echo "[*] Saving audit reports to $OUT..."

# 1. Users, UID 0, and Sudoers
awk -F: '($3 >= 1000 && $1 != "nobody") {print $1 " (UID:" $3 ")"}' /etc/passwd > "$OUT/users.txt"
awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd > "$OUT/uid0_rogue.txt"
getent group sudo adm shadow > "$OUT/privileged_groups.txt"
grep -rn "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null > "$OUT/sudoers_nopasswd.txt"

# 2. Listening Ports & Active Processes (Finds Python/Netcat backdoors)
ss -tulnp > "$OUT/open_ports.txt"
ps aux | grep -E "python|perl|nc|netcat|bash -i|php" | grep -v grep > "$OUT/suspicious_processes.txt"

# 3. Scheduled Tasks (Cron & At)
cat /etc/crontab > "$OUT/cron_jobs.txt"
ls -la /etc/cron.* /var/spool/cron/crontabs/ >> "$OUT/cron_jobs.txt" 2>/dev/null
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -u “$user” - 1 2 >/dev/null | sed "s/^/ [$user] /" >> “$OUT/cron_jobs.txt”
done

# 4. Installed Packages (Hacking tools, P2P clients like deluge, games)
dpkg-query -W -f='${Package}\n' | grep -E "nmap|zenmap|wireshark|john|hydra|aircrack|nikto|netcat|ophcrack|kismet|deluge|transmission|qbittorrent|4g8|freeciv|minetest|telnet|rsh|nis|snmp|tftpd|tightvnc|x11vnc" > "$OUT/prohibited_packages.txt"

# 5. Media & Unauthorized Files in /home

find /home -type f \( -iname "*.mp3" -o -iname "*.mp4" -o -iname "*.wav" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.flac" -o -iname "*.ogg" \) > "$OUT/media_files.txt"

# 6. World-Writable & Unowned Files (CIS 6.1.10 - 6.1.12)
find /etc /home /var/www -xdev -type f -perm -0002 2>/dev/null > "$OUT/world_writable.txt"
find / -xdev \( -nouser -o -nogroup \) 2>/dev/null > "$OUT/unowned_files.txt"

echo -e "\n=== QUICK SUMMARY ==="
echo "Rogue UID 0 users: (wc-l<"OUT/uid0_rogue.txt")"
echo "NOPASSWD sudo rules: (wc-l<"OUT/sudoers_nopasswd.txt")"
echo "Suspicious processes: (wc-l<"OUT/suspicious_processes.txt")"
echo "Prohibited packages found: (wc-l<"OUT/prohibited_packages.txt")"
echo "Media files in /home: (wc-l<"OUT/media_files.txt")"
echo "Review all files in $OUT before running 2_harden.sh!"