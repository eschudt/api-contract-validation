#! /bin/bash

dockerCommand="docker run"
dockerPort="-p 8080:8080"

if [ -z "$1" ]; then
  echo "Usage: $0 serviceDockerTag dependentServiceDetails"
  echo "Example: $0 eschudt/name-generator:0.0.1 eschudt/age-generator,AGE_SERVICE_URL"
  exit 1
fi

serviceDockerTag=$1
dependentServiceDetails=$2

# get swagger of service under executeTest
projectName=`echo ${serviceDockerTag} | cut -d':' -f1`
wget "https://raw.githubusercontent.com/${projectName}/master/docs/swagger.yaml"

# get swagger of depedent service and start mocks
if [ ! -z "$2" ]; then
  dependentDockerTag=`echo ${dependentServiceDetails} | cut -d',' -f1`
  dependentEnvVar=`echo ${dependentServiceDetails} | cut -d',' -f2`
  dependentPort=4000
  echo "Starting mock dependent service...\n";
  prism mock --spec https://raw.githubusercontent.com/${dependentDockerTag}/master/docs/swagger.yaml --port ${dependentPort} > output.log 2>&1 &
  depedentService="http://172.17.0.1:${dependentPort}"
  dependentPort=${dependentPort}+1
fi

echo "Starting service to test...\n";
if [ ! -z "$2" ]; then
  env1="-e ${dependentEnvVar}=${depedentService}"
fi
command="docker run ${env1} -e NOMAD_PORT_http=8080 -it -p 8080:8080 -d ${serviceDockerTag} >> testContainerIds.txt"
eval $command

sleep 3
echo "Running tests...\n";
dredd ./swagger.yaml http://127.0.0.1:8080 --header="Authorization: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2NvdW50SUQiOiIyIiwiaXNTZXJ2aWNlIjpmYWxzZSwibmJmIjoxNDQ0NDc4NDAwfQ.xCA5x2O-iS8qIshwAKWC0GyJlxPEW0ZjZGS0AaiqNmY"

echo "Cleanup...\n";
while read p; do
  echo "$p"
  docker stop $p
done <testContainerIds.txt

rm testContainerIds.txt
rm ./swagger.yaml

exit 0
