#!/system/bin/sh
umask 0027
export TMPDIR=/data/local/tmp
mkdir -p $TMPDIR
chmod 1777 $TMPDIR
ulimit -n 4096

if [ ! -d /system/b2g ]; then

  log -p W "No /system/b2g directory. Attempting recovery."
  if [ -d /system/b2g.bak ]; then
    if ! mount -w -o remount /system; then
      log -p E "Failed to remount /system read-write"
    fi
    if ! mv /system/b2g.bak /system/b2g; then
      log -p E "Failed to rename /system/b2g.bak to /system/b2g"
    fi
    mount -r -o remount /system
    if [ -d /system/b2g ]; then
      log "Recovery successful."
    else
      log -p E "Recovery failed."
    fi
  else
    log -p E "Recovery failed: no /system/b2g.bak directory."
  fi
fi

LD_PRELOAD="/system/b2g/libmozglue.so"
if [ -f "/system/b2g/libdmd.so" ]; then
  echo "Running with DMD."
  LD_PRELOAD="/system/b2g/libdmd.so $LD_PRELOAD"
  export DMD="1"
fi
export LD_PRELOAD

export LD_LIBRARY_PATH=/vendor/lib:/system/lib:/system/b2g
export GRE_HOME=/system/b2g
exec /system/b2g/b2g
