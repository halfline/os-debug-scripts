#!/bin/bash
cat << EOF > /etc/systemd/system/xorg@.service
[Unit]
Description=Remote, wide-open display server for port %i
BindsTo=xorg@%i.socket

[Service]
ExecStart=/usr/local/bin/xorg-as-a-service.sh %i
KillMode=mixed
Restart=no

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/xorg@.socket
[Unit]
Description=REmote, wide-open display servier bound to TCP port %i

[Socket]
ListenStream=%i

[Install]
WantedBy=sockets.target
EOF

mkdir -p /usr/local/bin
cat << 'EOF' > /usr/local/bin/xorg-as-a-service.sh
#!/bin/sh
PORT="$1"
DISPLAY_NUMBER="$(($PORT - 6000))"
exec Xorg ":$DISPLAY_NUMBER" -ac +iglx -terminate
EOF

chmod a+x /usr/local/bin/xorg-as-a-service.sh
restorecon /etc/systemd/system/xorg@.service /etc/systemd/system/xorg@.socket /usr/local/bin/xorg-as-a-service.sh
systemctl daemon-reload
