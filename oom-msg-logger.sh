#!/system/bin/sh
log "OOM Message Logger Started"
while read line; do
    if  [[ ("${line/*select*to kill*/select to kill}" = "select to kill") ||
           ("${line/*send sigkill to*/send sigkill to}" = "send sigkill to") ||
           ("${line/*lowmem_shrink*, return*/lowmem_shrink , return}" = "lowmem_shrink , return") ||
           ("${line/*lowmem_shrink*, ofree*/lowmem_shrink , ofree}" = "lowmem_shrink , ofree") ]]; then
        log $line;
    fi
done < /proc/kmsg
