#! /bin/bash
if [ ! -f client.cinder.key ]; then
	exit
fi
UUID=013d74e6-4d67-43fe-9ae2-573c2d0124c1
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
virsh secret-set-value --secret ${UUID} --base64 $(cat client.cinder.key)
