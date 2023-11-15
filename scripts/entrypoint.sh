#! /usr/bin/env sh

set -e
# set -x
set -o errexit
set -o nounset
# set -o pipefail # Doesn't work with sh
# set -o xtrace # Uncomment this line for debugging purposes

#Variables
: "${MYSQL_HOST:=}"
: "${POSTGRESS_HOST:=}"
: "${ELASTICSEARCH_HOST:=}"
: "${MQ_SERVER_COMMUNICATE_HOST:=}"
: "${REDIS_HOST:=}"

: "${WORKING_DIR:=""}"


VERSION="0.0.4"
INIT="false"
TIMEOUT=1

usage() {
  cat << USAGE >&2
Usage:
    --init          : Run the initialization script.
    bash | sh       : Enter the container without executing a command.
    -v | --version  : Display the version and usage information.

Service Verification:
    To validate services before starting the container, you can 
    configure the following environment variables:
    - \$MYSQL_HOST                  : MySQL host verification.
    - \$POSTGRESS_HOST              : Postgres host verification.
    - \$ELASTICSEARCH_HOST          : Elasticsearch host verification.
    - \$MQ_SERVER_COMMUNICATE_HOST  : RabbitMQ host verification.
    - \$REDIS_HOST                  : Radis host verification.

Once all checks pass successfully, the container will execute the provided CMD/command.
USAGE
}

case "$1" in
    -v | --version)
        echo "Version: $VERSION"
        usage
        exit
        ;;
    --init)
        INIT="true"
        ;;
    bash | sh)
        exec "$@"
        ;;
esac

check_service() {
    protocol=$1
    host_to_check=$2

    # case "$host_to_check" in
    #    redis)
    #         set -x ;;
    #     *)
    #         set +x ;;
    # esac 

    if [ $# -eq 3 ]; then
        port_to_check=$3
    fi

    case "$protocol" in
        tcp)
        if ! command -v nc >/dev/null; then
            echoerr 'nc command is missing!'
            exit 1
        fi
        ;;
        http)
        if ! command -v wget >/dev/null; then
            echoerr 'wget command is missing!'
            exit 1
        fi
        ;;
    esac

    case "$protocol" in
    tcp)
        result=$(nc -w $TIMEOUT -z "$host_to_check" "$port_to_check" > /dev/null 2>&1 ; echo $?)
        ;;
    http)
        result=$(wget --timeout=$TIMEOUT --tries=1 -q "$host_to_check" -O /dev/null > /dev/null 2>&1 ; echo $?)
        ;;
    *)
        echoerr "Unknown protocol '$protocol'"
        exit 1
        ;;
    esac

    
    if [ $result -eq 0 ] ; then
        return
    else  
        echo "Operation timed out. host: $host_to_check is unreachable" >&2
        exit 1
    fi


}

if [ ! -z $MYSQL_HOST ]; then
    : "${MYSQL_PORT:=3306}"

    check_service tcp $MYSQL_HOST $MYSQL_PORT 
    echo "MYSQL_HOST is ok"
fi

if [ ! -z $POSTGRES_HOST ]; then
    : "${POSTGRES_PORT:=5432}"
    
    check_service tcp $POSTGRES_HOST $POSTGRES_PORT 
    echo "POSTGRES_HOST is ok"
fi

if [ ! -z $ELASTICSEARCH_HOST ]; then
    : "${ELASTICSEARCH_PORT:=9200}"

    LINK_TO_CHECK="http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_cluster/health"
    
    check_service http $LINK_TO_CHECK 
    echo "ELASTICSEARCH_HOST is ok"
fi

if [ ! -z $MQ_SERVER_COMMUNICATE_HOST ]; then
    : "${MQ_SERVER_CHECK_PORT:=15692}"
    
    LINK_TO_CHECK="http://$MQ_SERVER_COMMUNICATE_HOST:$MQ_SERVER_CHECK_PORT/metrics"

    check_service http $LINK_TO_CHECK
    echo "MQ_SERVER_COMMUNICATE_HOST is ok"
fi

if [ ! -z $REDIS_HOST ]; then
    : "${REDIS_PORT:=6379}"
    
    check_service tcp $REDIS_HOST $REDIS_PORT 
    echo "REDIS_HOST is ok"
fi

if [ -z "$WORKING_DIR" ]; then
    echo "WORKING_DIR is not defined"
    exit 1
fi



# Only execute init script once
if [ ! -f "$WORKING_DIR/.initialized" ]; then
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

if [ $1 == '--init' ]; then
    shift
fi

exec "$@"