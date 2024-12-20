#! /bin/bash
UUID=
KEY=
apt-get install -y ceph-common
cat > secret.xml <<EOF
<secret ephemeral='no' private='no'>
<uuid>${UUID}</uuid>
<usage type='ceph'>
<name>client.pf9 secret</name>
</usage>
</secret>
EOF
cat secret.xml
virsh secret-define --file secret.xml
virsh secret-set-value --secret ${UUID} --base64 ${KEY}
