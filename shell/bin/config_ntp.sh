#!/bin/bash

# resolve links - $0 may be a softlink
this="${BASH_SOURCE-$0}"
common_bin=$(cd -P -- "$(dirname -- "$this")" && pwd -P)
script="$(basename -- "$this")"
this="$common_bin/$script"

# convert relative path to absolute path
config_bin=`dirname "$this"`
script=`basename "$this"`
config_bin=`cd "$config_bin"; pwd`
this="$config_bin/$script"


HOSTNAME=`hostname -f`
NODES_FILE=$config_bin/../conf/nodes
NODES="`cat $NODES_FILE |grep -v $HOSTNAME |sort -n | uniq | tr '\n' ' '|  sed 's/,$//'`"

pscp -H "$NODES" /etc/localtime /etc/localtime
pscp -H "$NODES" /etc/sysconfig/clock /etc/sysconfig/clock

### ntp ###
echo "[INFO]:Config `hostname -f`'s ntp"
\cp $config_bin/../template/ntp.conf /etc/ntp.conf
sed -i "/^driftfile/ s:^driftfile.*:driftfile /var/lib/ntp/ntp.drift:g" /etc/ntp.conf
service ntpd start

echo "[INFO]:Synchronizing time and timezone to $HOSTNAME"
pssh -P -i -H "$NODES" '
	echo "[INFO]:Waiting for `hostname -f` to update time and timezone to ['$HOSTNAME']..."

	if service ntpd status >/dev/null 2>&1; then
		service ntpd stop
	fi

	waiting_time=30
	while ! ntpdate '$HOSTNAME' 2>&1 ; do
		if [ $waiting_time -eq 0 ]; then
		    echo "[ERROR]: Please check whether the ntpd service is running on ntp server '$HOSTNAME'."
		    exit 1
		fi

		mod=`expr $waiting_time % 3`
		if [[ $mod -eq 0 ]]; then
		    echo "."
		fi

		sleep 1
		let waiting_time=$waiting_time-1
	done

	for x in 1 2 3 4 5 ; do
		echo -n "" ; ntpdate '$HOSTNAME'; sleep 1
	done
	hwclock --systohc || true
'
