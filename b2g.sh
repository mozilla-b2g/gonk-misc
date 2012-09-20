#!/system/bin/sh
umask 0027
export TMPDIR=/data/local/tmp
export LD_LIBRARY_PATH=/vendor/lib:/system/lib:/system/b2g
export LD_PRELOAD=/system/b2g/libmozglue.so
export GRE_HOME=/system/b2g

if [ /data/local/user.js -ot /system/b2g/profile/user.js ]
then
    cat /system/b2g/profile/user.js > /data/local/user.js
fi

mkdir -p $TMPDIR
chmod 1777 $TMPDIR
exec /system/b2g/b2g
