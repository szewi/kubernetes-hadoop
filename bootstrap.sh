#!/bin/bash

sed "s,HOSTNAME,${HOSTNAME}," /opt/templates/core-site.xml.template > ${HADOOP_HOME}/etc/hadoop/core-site.xml
sed "s,HDFS_REPLICATION,${HDFS_REPLICATION}," /opt/templates/hdfs-site.xml.template > ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml

service ssh start

${HADOOP_HOME}/bin/hdfs namenode -format

DOMAIN_SUFFIX='svc.cluster.local'
if [ ! -z "${NODE_NAMESPACE}" ]; then
  DOMAIN_SUFFIX="${NODE_NAMESPACE}.${DOMAIN_SUFFIX}"
else
  DOMAIN_SUFFIX="default.${DOMAIN_SUFFIX}"
fi

if [ ! -z "${DATANODE_SUBDOMAIN}" ]; then
  DOMAIN_SUFFIX="${DATANODE_SUBDOMAIN}.${DOMAIN_SUFFIX}"
else
  DOMAIN_SUFFIX="hadoop-datanodes.${DOMAIN_SUFFIX}"
fi

if [ -z "${NODE_TYPE}" ]; then
  ${HADOOP_HOME}/sbin/start-dfs.sh
  echo "Starting single node cluster" > /opt/bootstrap_log
elif [[ "${NODE_TYPE}" == "datanode" ]]; then 
  echo "Node type is set to: ${NODE_TYPE}" > /opt/bootstrap_log
elif [[ "${NODE_TYPE}" == "namenode" ]]; then
  echo "Node type is set to: ${NODE_TYPE}" > /opt/bootstrap_log
  sed -i '/localhost/d' /opt/hadoop/etc/hadoop/workers
  if [ ! -z "${DATANODE_COUNT}" ]; then
    for ((i=0;i<${DATANODE_COUNT};i++)); do
      echo "datanode-${i}.${DOMAIN_SUFFIX}" >> /opt/hadoop/etc/hadoop/workers
    done
  fi
  cat /opt/hadoop/etc/hadoop/workers >> /opt/bootstrap_log
  cat /opt/hadoop/etc/hadoop/workers | xargs -L1 -I {} rsync -avhe "ssh -o StrictHostKeyChecking=no" /opt/hadoop/etc/hadoop/ {}:/opt/hadoop/etc/hadoop/
  NAME_NODE_HOST=$(grep namenode /etc/hosts)
  cat /opt/hadoop/etc/hadoop/workers | xargs -L1 -I {} ssh -o StrictHostKeyChecking=no {} "echo $NAME_NODE_HOST >> /etc/hosts"
  ${HADOOP_HOME}/sbin/start-dfs.sh
else
  echo "Not supported node type" > /opt/bootstrap_log
fi

if [[ "$1" == '-d' ]]; then
  while true; do sleep 3600; done
fi