#!/bin/bash
# Baut 'Subnet' Statements fuer alle Netze die 10.190, 10.191, 172.21 oder fd21 enthalten
TMPFILE=$(mktemp)
if ! type -a ipcalc >/dev/null; then
  echo Jetzt aufrufen: apt install ipcalc
  exit 1

fi
if [ ! -e /etc/systemd/system/tincd\@.service ]; then
  cat <<-EOF >/etc/systemd/system/tincd\@.service
	[Unit]
	Description=tincd (connection %I)
	After=network.target
	
	[Service]
	Type=simple
	ExecStart=/usr/sbin/tincd -n %I -D
	Restart=always
	
	[Install]
	WantedBy=multi-user.target
	EOF
  systemctl daemon-reload
fi
(
cat /etc/tinc/ffsl3/hosts/$HOSTNAME | sed '/Subnet/d'
ip a l |
awk '/inet.* (10.19[01]|172.21|fd21)/ {
  netmask=$2;
  gsub(".*/","",netmask);
  ip=$2;
  gsub("/.*","",ip);
  gsub("a38.*","",$2); 
  gsub("/.*","",$2); 
  printf("%s\n%s/%s\n",ip,$2,netmask)
 }' | sort | while read a; do
  case $a in
    *.*/*) ipcalc $a | awk '$1 ~ /Network/ {print $2}';;
    *)     echo $a
  esac
done | sed 's/^/Subnet = /'
) > $TMPFILE
if [ 0 -lt $(wc -l $TMPFILE) ]; then
  if ! diff /etc/tinc/ffsl3/hosts/$HOSTNAME $TMPFILE; then
    cp $TMPFILE /etc/tinc/ffsl3/hosts/$HOSTNAME
    echo Jetzt aufrufen: systemctl restart tincd@ffsl3.service
  fi
fi
rm $TMPFILE
