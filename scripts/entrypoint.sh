#! /usr/bin/env bash

set -e
set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

#Variables
: "${MYSQL_HOST:=}"
: "${POSTGRESS_HOST:=}"
: "${ELASTICSEARCH_HOST:=}"


: "${WORKING_DIR:=""}"

VERSION="0.0.1"
INIT="false"

case "$1" in
    -v | --version)
        echo "Version: $VERSION"
        exit
        ;;
    --init)
        INIT="true"
        ;;

esac

Check_TCP_service() {
    HOST=$1
    PORT=$2
    /scripts/wait_for.sh $HOST:$PORT -t 1
}

Check_HTTP_service() {
    HOST=$1
    /scripts/wait_for.sh $HOST -t 1
}

if [[ $MYSQL_HOST != "" ]]; then
    : "${MYSQL_PORT:=3306}"

    Check_TCP_service $MYSQL_HOST $MYSQL_PORT 
    echo "MYSQL_HOST is ok"
fi

if [[ $POSTGRESS_HOST != "" ]]; then
    : "${POSTGRES_PORT:=5432}"
    
    Check_TCP_service $POSTGRES_HOST $POSTGRES_PORT 
    echo "POSTGRES_HOST is ok"
fi

if [[ $ELASTICSEARCH_HOST != "" ]]; then
    : "${ELASTICSEARCH_PORT:=9200}"

    LINK_TO_CHECK="http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_cluster/health"
    
    Check_HTTP_service $LINK_TO_CHECK 
    echo "ELASTICSEARCH_HOST is ok"
fi

if [ -z "$WORKING_DIR" ]; then
    echo "WORKING_DIR is not defined"
    exit 1
fi



# Only execute init script once
if [[ ! -f "$WORKING_DIR/.initialized" ]]; then
    case "$INIT" in
        true)
            echo "Initilizing app"
            /scripts/init.sh
            echo "App was initialized"
            touch "$WORKING_DIR/.initialized"
            ;;
        *)
            echo "Waiting for initialization"
            echo "If you want run this container as init, use --init flag"
            exit 1
            ;;
    esac
fi

if [[ $1 == '--init' ]]; then
    shift
fi

exec "$@"