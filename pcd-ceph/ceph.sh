#! /bin/bash
FSID=fb9bd1a4-b3ac-11ef-ba98-ad08389d3a5c
KEY=AQC/zFdnWx9TBxAAXTvltShVNr2vh+hpIuzn6A==
M1=172.29.22.10
M2=172.29.22.20
M3=172.29.22.30
UUID=013d74e6-4d67-43fe-9ae2-573c2d0124c1
POOL=volumes
USER=cinder
FILE=/etc/ceph/ceph.client.cinder.keyring
#
apt-get install -y ceph-common
cat > /etc/ceph/ceph.conf <<EOF
[global]
	fsid = ${FSID}
	mon_host = [v2:${M1}:3300/0,v1:${M1}:6789/0] [v2:${M2}:3300/0,v1:${M2}:6789/0] [v2:${M3}:3300/0,v1:${M3}:6789/0]
EOF
cat > ${FILE} <<EOF
[client.cinder]
	key = ${KEY}
EOF
chown pf9:pf9group /etc/ceph/ceph.conf ${FILE}
chmod 440 /etc/ceph/ceph.conf ${FILE}
if [ -f /usr/bin/virsh ]; then
cat > secret.xml <<EOF
<secret ephemeral='no' private='no'>
<uuid>${UUID}</uuid>
<usage type='ceph'>
<name>client.cinder secret</name>
</usage>
</secret>
EOF
cat secret.xml
virsh secret-define --file secret.xml
virsh secret-set-value --secret ${UUID} --base64 ${KEY}
fi
#
unser FILE
FILE=/opt/pf9/etc/pf9-cindervolume-base/conf.d/cinder_override.conf
echo ${FILE}
cat > ${FILE} <<EOF
[ceph]
rbd_pool = ${POOL}
rbd_user = ${USER}
volumes_dir = /opt/pf9/etc/pf9-cindervolume-base/volumes/
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_flatten_volume_from_snapshot = false
rbd_secret_uuid = ${UUID}
EOF
chown pf9:pf9group ${FILE}
cat ${FILE}
if [ -f /opt/pf9/pf9-cindervolume-base/lib/python3.9/site-packages/rbd.cpython-39-x86_64-linux-gnu.so ]; then
	echo rbd.cpython-39-x86_64-linux-gnu.so is present
else
	echo rbd.cpython-39-x86_64-linux-gnu.so is absent
fi
if [ -f /opt/pf9/pf9-cindervolume-base/lib/python3.9/site-packages/rados.cpython-39-x86_64-linux-gnu.so ]; then
        echo rados.cpython-39-x86_64-linux-gnu.so is present
else
        echo rados.cpython-39-x86_64-linux-gnu.so is absent
fi
systemctl restart pf9-cindervolume-base
