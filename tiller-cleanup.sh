#!/bin/bash

# Cleanup old helm tiller history config maps.
# This can be handy if you forgot to set TILLER_HISTORY_MAX on your tiller deployment, and added it later on.
# 28/5/2019, Thijs Kaper.

# Change the two variables below to match your setup.
TILLER_NAMESPACE=kube-system
TILLER_HISTORY_MAX=5

echo "Settings: TILLER_NAMESPACE=${TILLER_NAMESPACE}, TILLER_HISTORY_MAX=${TILLER_HISTORY_MAX}"

if [ "$1" != "-f" -a "$1" != "-n" ]
then
   echo "Usage: $0 [-f | -n]"
   echo "Use -n for a dry-run to show what would be deleted"
   echo "Use -f to execute a run with actual deletes"
   exit 1
fi

function log {
   echo "`date` $*"
}

TMPFILE=/tmp/tiller-map-list-$$.lst

# get full list of tiller maps, per line: version tiller-name mapname
# Example line: 2 watchdog-service watchdog-service.v2
log "get list of tiller maps"
kubectl --request-timeout=600s -n ${TILLER_NAMESPACE} get cm --no-headers -l OWNER=TILLER \
        -o jsonpath='{range .items[*]}{.metadata.labels.VERSION}{" "}{.metadata.labels.NAME}{" "}{.metadata.name }{"\n"}{end}' | sort -r -n  >$TMPFILE
if [ "$?" != "0" ]
then
   echo "Error?"
   exit 1
fi
ORIGMAPCOUNT="`cat $TMPFILE | wc -l`"
log "read $ORIGMAPCOUNT maps"

log "get unique tiller deployment names"
MAPNAMES="`cat $TMPFILE | awk '{ print $2}' | sort -u`"
DEPLOYCOUNT="`echo $MAPNAMES | wc -w`"
log "found $DEPLOYCOUNT tiller deployment names"

# get a list of release label values from active k8s objects
# these are prefixed and postfixed by a # to enable exact match searching using grep later on
log "get list of active tiller releases"
kubectl --request-timeout=600s get all,cronjobs --all-namespaces -l heritage=Tiller -L release -o jsonpath='{range .items[*]}{"#"}{.metadata.labels.release}{"#\n"}{end}' | sort -u >$TMPFILE.active
kubectl --request-timeout=600s get all,cronjobs --all-namespaces -l app.kubernetes.io/managed-by=Tiller -L app.kubernetes.io/instance -o jsonpath='{range .items[*]}{"#"}{.metadata.labels.app\.kubernetes\.io/instance}{"#\n"}{end}'|sort -u >>$TMPFILE.active
if [ "$?" != "0" ]
then
   echo "Error?"
   exit 1
fi
ACTIVERELEASECOUNT="`cat $TMPFILE.active | wc -l`"
log "active tiller release count ${ACTIVERELEASECOUNT}"

deleteCount=0
for CHECKNAME in $MAPNAMES
do
   log "-----------------------------------"
   log "Check:  $CHECKNAME"
   grep -q "#${CHECKNAME}#" $TMPFILE.active
   if [ "$?" == "0" ]
   then
      ACTIVE=true
   else
      ACTIVE=false 
      log "Tiller map(s) found, but no deploy? - will remove tiller maps for ${CHECKNAME}"
   fi

   i=0
   while read VERSION NAME MAPNAME 
   do
      if [ "$CHECKNAME" == "$NAME" ]
      then
         i=$((i + 1))
         if [ $i -gt ${TILLER_HISTORY_MAX} -o "$ACTIVE" == "false" ]
         then
            log "Delete: $MAPNAME"
            deleteCount=$((deleteCount + 1))
            if [ "$1" == "-f" ]
            then
               kubectl delete -n ${TILLER_NAMESPACE} configmap $MAPNAME
            fi
         else
            log "Keep:   $MAPNAME"
         fi
      fi
   done <$TMPFILE

done

rm -rf $TMPFILE
rm -rf $TMPFILE.active

log "---------------------------------------------------"
log "Original number of maps $ORIGMAPCOUNT"
log "Original number of tiller deployments $DEPLOYCOUNT"
log "Active release count ${ACTIVERELEASECOUNT}"
log "Number of maps deleted $deleteCount"
log "Number of maps after deletion $((ORIGMAPCOUNT - deleteCount))"
log "---------------------------------------------------"

if [ "$1" != "-f" ]
then
   log "Note: this was a DRY-RUN, so nothing has been deleted..."
fi



