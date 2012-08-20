#!/system/bin/sh

export TMPDIR=/data/local/tmp
export LD_LIBRARY_PATH=/vendor/lib:/system/lib
export GRE_HOME=/system/b2g

# Apparently, when the value of the service string is longer than 91 characters,
# the "start" command stops working altogether. This means we can't pass the
# updater args directly through "start", and have to use properties instead.

file_exists() {
  # Android's ash doesn't have -f, test, or expr :(
  ls $1 2>&1 > /dev/null
  return $?
}

get_and_clear_prop() {
  VALUE=`getprop $1`
  setprop $1 ""
  echo $VALUE
}

UPDATER=`get_and_clear_prop b2g.updates.updater`
UPDATE_DIR=`get_and_clear_prop b2g.updates.update_dir`
APPLY_TO_DIR_ARG=`get_and_clear_prop b2g.updates.apply_to_dir`

# optional arguments
PID=`get_and_clear_prop b2g.updates.pid`
CWD=`get_and_clear_prop b2g.updates.cwd`
CALLBACK=`get_and_clear_prop b2g.updates.callback`

if ! file_exists "$UPDATER"; then
  echo "Updater path not found: $UPDATER" 1>&2
  exit 1
fi

if ! file_exists "$UPDATE_DIR"; then
  echo "Update dir not found: $UPDATE_DIR" 1>&2
  exit 1
fi

APPLY_ERROR="Error: missing applyToDir"
APPLY_TO_DIR=${APPLY_TO_DIR_ARG:?$APPLY_ERROR}

echo "$UPDATER" "$UPDATE_DIR" "$APPLY_TO_DIR" "$PID" "$CWD" "$CALLBACK"
exec "$UPDATER" "$UPDATE_DIR" "$APPLY_TO_DIR" "$PID" "$CWD" "$CALLBACK"
