#!/system/bin/sh
export TMPDIR=/data/local/tmp
export LD_LIBRARY_PATH=/vendor/lib:/system/lib:/system/b2g
export LD_PRELOAD=/system/b2g/libmozglue.so
export GRE_HOME=/system/b2g

mkdir -p $TMPDIR
chmod 777 $TMPDIR
exec /system/b2g/b2g
