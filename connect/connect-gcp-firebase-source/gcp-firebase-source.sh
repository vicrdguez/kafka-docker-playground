#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh
PROJECT=${1:-vincent-de-saboulin-lab}

KEYFILE="${DIR}/keyfile.json"
if [ ! -f ${KEYFILE} ] && [ -z "$KEYFILE_CONTENT" ]
then
     logerror "ERROR: either the file ${KEYFILE} is not present or environment variable KEYFILE_CONTENT is not set!"
     exit 1
else 
    if [ -f ${KEYFILE} ]
    then
        KEYFILE_CONTENT=`cat keyfile.json | jq -aRs .`
    else
        log "Creating ${KEYFILE} based on environment variable KEYFILE_CONTENT"
        echo -e "$KEYFILE_CONTENT" | sed 's/\\"/"/g' > ${KEYFILE}
    fi
fi

if [ ! -z "$CI" ]
then
     # running with github actions


     log "Removing all data"
     docker run -p 9005:9005 -e FIREBASE_TOKEN="$FIREBASE_TOKEN" -e PROJECT=$PROJECT -i kamshak/firebase-tools-docker firebase database:remove / -y --token "$FIREBASE_TOKEN" --project "$PROJECT"
     log "Adding data from musicBlog.json"
     docker run -p 9005:9005 -v ${DIR}/musicBlog.json:/tmp/musicBlog.json -e FIREBASE_TOKEN="$FIREBASE_TOKEN" -e PROJECT=$PROJECT -i kamshak/firebase-tools-docker firebase database:set / /tmp/musicBlog.json -y --token "$FIREBASE_TOKEN" --project "$PROJECT"
     log "Verifying data is in Firebase"
     docker run -p 9005:9005 -e FIREBASE_TOKEN="$FIREBASE_TOKEN" -e PROJECT=$PROJECT -i kamshak/firebase-tools-docker firebase database:get / --token "$FIREBASE_TOKEN" --project "$PROJECT" | jq .
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

log "Creating GCP Firebase Source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class" : "io.confluent.connect.firebase.FirebaseSourceConnector",
               "tasks.max" : "1",
               "gcp.firebase.credentials.path": "/tmp/keyfile.json",
               "gcp.firebase.database.reference": "https://'"$PROJECT"'.firebaseio.com/musicBlog",
               "gcp.firebase.snapshot":"true",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1",
               "errors.tolerance": "all",
               "errors.log.enable": "true",
               "errors.log.include.messages": "true"
          }' \
     http://localhost:8083/connectors/firebase-source/config | jq .

sleep 10

log "Verify messages are in topic artists"
timeout 60 docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic artists --from-beginning --max-messages 3

log "Verify messages are in topic songs"
timeout 60 docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic songs --from-beginning --max-messages 3
