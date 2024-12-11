#! /bin/bash
SO_DIR=/opt/pf9/pf9-cindervolume-base/lib/python3.9/site-packages
if [ ! -d ${SO_DIR} ]; then
echo "Exiting as ${SO_DIR} does not exist."
exit
fi
cp rados.cpython-39-x86_64-linux-gnu.so rbd.cpython-39-x86_64-linux-gnu.so ${SO_DIR}
chown pf9:pf9group ${SO_DIR}/rados.cpython-39-x86_64-linux-gnu.so  ${SO_DIR}/rbd.cpython-39-x86_64-linux-gnu.so
ls -lrt ${SO_DIR}/rados.cpython-39-x86_64-linux-gnu.so  ${SO_DIR}/rbd.cpython-39-x86_64-linux-gnu.so
