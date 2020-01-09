#!/bin/bash

verify_installed()
{
  local cmd="$1"
  if [[ $(type $cmd 2>&1) =~ "not found" ]]; then
    echo -e "\nERROR: This script requires '$cmd'. Please install '$cmd' and run again.\n"
    exit 1
  fi
}
verify_installed "jq"
verify_installed "docker-compose"

DOCKER_COMPOSE_FILE_OVERRIDE=$1
# Starting kerberos,
# Avoiding starting up all services at the begining to generate the keytab first
if [ -f "${DOCKER_COMPOSE_FILE_OVERRIDE}" ]
then

  docker-compose -f ../../environment/kerberos/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} down -v
  docker-compose -f ../../environment/kerberos/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} build kdc
  docker-compose -f ../../environment/kerberos/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} build client
  docker-compose -f ../../environment/kerberos/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} up -d kdc
else
  docker-compose -f ../../environment/kerberos/docker-compose.yml down -v
  docker-compose -f ../../environment/kerberos/docker-compose.yml build kdc
  docker-compose -f ../../environment/kerberos/docker-compose.yml build client
  docker-compose -f ../../environment/kerberos/docker-compose.yml up -d kdc
fi

### Create the required identities:
# Kafka service principal:
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey kafka/broker.kerberos-demo.local@TEST.CONFLUENT.IO"  > /dev/null
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey kafka/broker2.kerberos-demo.local@TEST.CONFLUENT.IO"  > /dev/null

# Zookeeper service principal:
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey zookeeper/zookeeper.kerberos-demo.local@TEST.CONFLUENT.IO"  > /dev/null

# Create a principal with which to connect to Zookeeper from brokers - NB use the same credential on all brokers!
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey zkclient@TEST.CONFLUENT.IO"  > /dev/null

# Create client principals to connect in to the cluster:
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey kafka_producer@TEST.CONFLUENT.IO"  > /dev/null
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey kafka_producer/instance_demo@TEST.CONFLUENT.IO"  > /dev/null
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey kafka_consumer@TEST.CONFLUENT.IO"  > /dev/null
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey connect@TEST.CONFLUENT.IO"  > /dev/null
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey schemaregistry@TEST.CONFLUENT.IO"  > /dev/null
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey controlcenter@TEST.CONFLUENT.IO"  > /dev/null


# Create an admin principal for the cluster, which we'll use to setup ACLs.
# Look after this - its also declared a super user in broker config.
docker exec -ti kdc kadmin.local -w password -q "add_principal -randkey admin/for-kafka@TEST.CONFLUENT.IO"  > /dev/null

# Create keytabs to use for Kafka
echo -e "\033[0;33mCreate keytabs\033[0m"
docker exec -ti kdc rm -f /var/lib/secret/broker.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/broker2.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/zookeeper.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/zookeeper-client.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/kafka-client.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/kafka-admin.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/kafka-connect.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/kafka-schemaregistry.key 2>&1 > /dev/null
docker exec -ti kdc rm -f /var/lib/secret/kafka-controlcenter.key 2>&1 > /dev/null

docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/broker.key -norandkey kafka/broker.kerberos-demo.local@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/broker2.key -norandkey kafka/broker2.kerberos-demo.local@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/zookeeper.key -norandkey zookeeper/zookeeper.kerberos-demo.local@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/zookeeper-client.key -norandkey zkclient@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-client.key -norandkey kafka_producer@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-client.key -norandkey kafka_producer/instance_demo@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-client.key -norandkey kafka_consumer@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-admin.key -norandkey admin/for-kafka@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-connect.key -norandkey connect@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-schemaregistry.key -norandkey schemaregistry@TEST.CONFLUENT.IO " > /dev/null
docker exec -ti kdc kadmin.local -w password -q "ktadd  -k /var/lib/secret/kafka-controlcenter.key -norandkey controlcenter@TEST.CONFLUENT.IO " > /dev/null


# Starting zookeeper and kafka now that the keytab has been created with the required credentials and services
if [ -f "${DOCKER_COMPOSE_FILE_OVERRIDE}" ]
then
  docker-compose -f ../../environment/kerberos/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} up -d
else
  docker-compose -f ../../environment/kerberos/docker-compose.yml up -d
fi

shift
../../scripts/wait-for-connect-and-controlcenter.sh $@

# Adding ACLs for consumer and producer user:
docker exec client bash -c "kinit -k -t /var/lib/secret/kafka-admin.key admin/for-kafka && kafka-acls --bootstrap-server broker:9092 --command-config /etc/kafka/command.properties --add --allow-principal User:kafka_producer --producer --topic=*"
docker exec client bash -c "kinit -k -t /var/lib/secret/kafka-admin.key admin/for-kafka && kafka-acls --bootstrap-server broker:9092 --command-config /etc/kafka/command.properties --add --allow-principal User:kafka_consumer --consumer --topic=* --group=*"
# Adding ACLs for connect user:
docker exec client bash -c "kinit -k -t /var/lib/secret/kafka-admin.key admin/for-kafka && kafka-acls --bootstrap-server broker:9092 --command-config /etc/kafka/command.properties --add --allow-principal User:connect --consumer --topic=* --group=*"
docker exec client bash -c "kinit -k -t /var/lib/secret/kafka-admin.key admin/for-kafka && kafka-acls --bootstrap-server broker:9092 --command-config /etc/kafka/command.properties --add --allow-principal User:connect --producer --topic=*"
# schemaregistry and controlcenter is super user

# Output example usage:
echo -e "\033[0;33m-----------------------------------------\033[0m"
echo -e "\033[0;33mExample configuration to access kafka:\033[0m"
echo -e "\033[0;33m-----------------------------------------\033[0m"
echo -e "\033[0;33m-> docker-compose exec client bash -c 'kinit -k -t /var/lib/secret/kafka-client.key kafka_producer && kafka-console-producer --broker-list broker:9092 --topic test --producer.config /etc/kafka/producer.properties'\033[0m"
echo -e "\033[0;33m-> docker-compose exec client bash -c 'kinit -k -t /var/lib/secret/kafka-client.key kafka_consumer && kafka-console-consumer --bootstrap-server broker:9092 --topic test --consumer.config /etc/kafka/consumer.properties --from-beginning'\033[0m"

shift
../../scripts/wait-for-connect-and-controlcenter.sh $@
