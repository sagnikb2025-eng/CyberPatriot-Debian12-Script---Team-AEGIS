# 5. Kernel & Network Hardening (Sysctl)
echo -e "\e[1;36m=== [5/7] PERSISTENT SYSCTL KERNEL HARDENING ===\e[0m"
cat <<EOF > /etc/sysctl.d/99-cyberpatriot.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
EOF
sysctl --system
pause_step

# 6. Service Hardening (OpenSSH & Apache2)
echo -e "\e[1;36m=== [6/7] SERVICE HARDENING (SSH & APACHE2) ===\e[0m"
if dpkg -l | grep -qw openssh-server; then
    echo "Is OpenSSH required by the README? (y/n)"
    read -r need_ssh
    if [[ "needssh” = ~[Yy]]; then
        cp /etc/ssh/sshd_config "$BACKUP/sshd_config.bak"
        mkdir -p /etc/ssh/sshd_config.d
        cat <<EOF > /etc/ssh/sshd_config.d/99-cyberpatriot.conf
PermitRootLogin no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no
EOF
        sshd -t && systemctl restart ssh || systemctl restart sshd
        echo "[OK] OpenSSH hardened."
    else
        systemctl stop ssh sshd 2>/dev/null
        apt-get purge -y openssh-server
        echo "[OK] OpenSSH removed."
    fi
fi

if dpkg -l | grep -qw apache2; then
    echo "Is Apache2 web server required by the README? (y/n)"
    read -r need_apache
    if [[“$need_apache” =~ ^[Yy]$ ]]; then 
        cp /etc/apache2/apache2.conf "$BACKUP/apache2.conf.bak"
        chown -R root:root /etc/apache2
        cat <<EOF > /etc/apache2/conf-available/cyberpatriot-security.conf
ServerTokens Prod
ServerSignature Off
TraceEnable Off
Timeout 45
<Directory />
    Options None
    AllowOverride None
    Require all denied
</Directory>
EOF
        a2enconf cyberpatriot-security
        systemctl restart apache2
        echo "[OK] Apache2 hardened."
    else
        systemctl stop apache2
        apt-get purge -y apache2
        echo "[OK] Apache2 removed."
    fi
fi
pause_step

# 7. Auditing, Automatic Updates & System Upgrade
echo -e "\e[1;36m=== [7/7] AUDITD, AUTO-UPDATES & SYSTEM UPGRADE ===\e[0m"
apt-get install -y auditd audispd-plugins unattended-upgrades
systemctl enable auditd
systemctl start auditd
auditctl -e 1

cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get autoclean -y

echo -e "\e[1;32m[DONE] Hardening complete! Backups saved in $BACKUP.\e[0m”