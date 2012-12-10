#!/system/bin/sh
umask 0027
export TMPDIR=/data/local/tmp
mkdir -p $TMPDIR
chmod 1777 $TMPDIR

LD_PRELOAD="/system/b2g/libmozglue.so"
if [ -f "/system/b2g/libdmd.so" ]; then
  echo "Running with DMD."
  LD_PRELOAD="/system/b2g/libdmd.so $LD_PRELOAD"
  export DMD=1
fi
export LD_PRELOAD

export LD_LIBRARY_PATH=/vendor/lib:/system/lib:/system/b2g
export GRE_HOME=/system/b2g
exec /system/b2g/b2g
