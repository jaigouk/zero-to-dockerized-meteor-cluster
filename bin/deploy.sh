#!/bin/bash
set -e

USAGE="Usage: $0 [-a docker.io auth token] [-m docker.io auth email] [-k ssh key id] [-t digitalocean v2 token] [-o droplet name prefix] [-n number of droplets] [-e etcd token] [-s droplet size]
Options:
    -a DOCKER_IO_AUTH     docker.io auth token (see your ~/.dockercfg)
    -m DOCKER_IO_EMAIL    docker.io auth email (see your ~/.dockercfg)
    -k SSH_KEY_ID         SSH KEY ID on digitalocean. you need digitalocean token to get it.
    -t DO_TOKEN           digitalocean api v2 token that has read/write permission
    -o DROPLET_NAME       name prefix for droplets. core => core-1, core-2, core-3
    -n NUM_OF_DROPLETS    default 3
    -e ETCD_TOKEN         without this option, we will get one by default
    -s DROPLET_SIZE       512mb|1gb|2gb|4gb|8gb|16gb
"

while [ "$#" -gt 0 ]; do
    case $1 in
        -a)
            shift 1
            DOCKER_IO_AUTH=$1
            ;;
        -m)
            shift 1
            DOCKER_IO_EMAIL=$1
            ;;
        -k)
            shift 1
            INPUT_SSH_KEY_ID=$1
            ;;
        -t)
            shift 1
            DO_TOKEN=$1
            echo "do token: $DO_TOKEN "
            ;;
        -o)
            shift 1
            DROPLET_NAME=$1
            ;;
        -n)
            shift 1
            NUM_OF_DROPLETS=$1
            ;;
        -e)
            shift 1
            ETCD_TOKEN=$1
            ;;
        -s)
            shift 1
            DROPLET_SIZE=$1
            ;;
        --help)
            echo "$USAGE"
            exit 0
            ;;
        -h)
            echo "$USAGE"
            exit 0
            ;;
    esac
    shift 1
done

if [ -z "$DOCKER_IO_AUTH" ]; then
    echo "Please input your docker.io token for Digital Ocean after -a option."
    exit 1
else
  export DOCKERIO_TOKEN=$DOCKER_IO_AUTH
fi

if [ -z "$DOCKER_IO_EMAIL" ]; then
    echo "Please input your docker.io token for Digital Ocean after -a option."
    exit 1
else
  export DOCKERIO_EMAIL=$DOCKER_IO_EMAIL
fi



if ! echo $DROPLET_SIZE | grep -qE '512mb|1gb|2gb|4gb|8gb|16gb'; then
    echo 'Channel must be alpha, beta, or stable'
    exit 1
else
  export SIZE=$DROPLET_SIZE
fi


if [ -z "$DO_TOKEN" ]; then
    echo "Please input your token for Digital Ocean after -t option."
    echo "visit https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2#how-to-generate-a-personal-access-token"
    exit 1
fi

if [ -z "$INPUT_SSH_KEY_ID" ]; then
    echo -n "========================="
    curl -X GET -H "Authorization: Bearer $DO_TOKEN" "https://api.digitalocean.com/v2/account/keys"
    echo -n "========================="
    echo -n "Please input your ssh key id for CoreOS..."
    read -s INPUT_SSH_KEY_ID
    export SSH_KEY_ID=$INPUT_SSH_KEY_ID
else
  export SSH_KEY_ID=$INPUT_SSH_KEY_ID
fi

if [ -z "$ETCD_TOKEN" ]; then
  export DISCOVERY_URL=`curl -fsS -X PUT https://discovery.etcd.io/new`
  echo "Please SAVE your DISCOVERY_URL safely somewhere..."
  echo "$DISCOVERY_URL"
else
  export DISCOVERY_URL="https://discovery.etcd.io/$ETCD_TOKEN"
  echo "$DISCOVERY_URL"
fi

if [ -z "$NUM_OF_DROPLETS" ]; then
    NUM_OF_DROPLETS=3
fi

if [ -z "$DROPLET_NAME" ]; then
    DROPLET_NAME=core
    export DROPLET_NAME=$DROPLET_NAME
fi

NAME_PREFIX=$DROPLET_NAME

for i in `seq $NUM_OF_DROPLETS`; do ./create_droplet.sh $NAME_PREFIX-$i; done