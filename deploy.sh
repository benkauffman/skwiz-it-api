#!/bin/bash
cd "$(dirname "$0")"

set -e #exit on errors

echo "Running deploy.sh"

_IMAGE_NAME="skwiz-it-api"

echo "Example parameters to pass to this shell script..."
echo "./deploy.sh skwiz-it-api skwiz.it api development@developmentnow.com y"

#SHELL SCRIPT STARTS HERE
if [ ! -f "./config.json" ]; then
    echo "Missing config file ./config.json, application will not run without it..."
    echo "Exiting"
    exit 1
fi

NAME=${1}
DOMAIN=${2}
SUB_DOMAIN=${3}
CONTACT_EMAIL=${4}
REPLACE_FLAG=${5}

if [[ -z "${NAME}" ]]; then
    echo "Enter name for container:"
    read NAME
    if [[ -z "${NAME}" ]]; then
        echo "No container name was set"
        echo "Exiting..."
        exit 1
    fi
fi

CONTAINER_ID=$(docker ps -q -f name=^/${NAME}$);

if [[ -z "${CONTAINER_ID}" ]]; then
    echo "${NAME} container is not pre-existing or is not currently running..."
    SHOULD_DEPLOY=true
else
    echo "${NAME} container is already running with container id ${CONTAINER_ID}..."

    if [[ -z "${REPLACE_FLAG}" ]] || ! [[ ${REPLACE_FLAG} =~ ^(yes|y|Y) ]]; then
        echo "Would you like to replace it? [Y/n]:"
        read REPLACE_FLAG

        if [[ ${REPLACE_FLAG} =~ ^(yes|y|Y) ]]; then
            echo "Existing container ${NAME} will be removed after the images is built..."
        else
            echo "Container replacement cancelled exiting..."
            exit 0
        fi
    fi

fi

if [[ -z "${DOMAIN}" ]]; then
    echo "Enter domain url (i.e. skwiz.it):"
    read DOMAIN
    if [[ -z "${DOMAIN}" ]]; then
        echo "Host domain was not set"
        echo "Exiting..."
        exit 1
    fi
fi

if [[ -z "${SUB_DOMAIN}" ]]; then
    echo "Enter sub domain (i.e. api):"
    read SUB_DOMAIN
    if [[ -z "${SUB_DOMAIN}" ]]; then
        echo "Sub domain was not set"
        echo "Exiting..."
        exit 1
    fi
fi

if [[ -z "${CONTACT_EMAIL}" ]]; then
    echo "Enter contact email for domain expiration:"
    read CONTACT_EMAIL
    if [[ -z "${CONTACT_EMAIL}" ]]; then
        echo "Contact email was not set"
        echo "Exiting..."
        exit 1
    fi
fi

VIRTUAL_HOST="${SUB_DOMAIN}.${DOMAIN}"
echo "Deploying ${NAME} and binding to ${VIRTUAL_HOST}..."

_DOCKER_TAG=$(git rev-parse --short HEAD)
_DOCKER_IMAGE_NAME="${_IMAGE_NAME}:${_DOCKER_TAG}"

_IMAGE_EXISTS=$(docker images -q ${_DOCKER_IMAGE_NAME} 2> /dev/null);
if [[ "${_IMAGE_EXISTS}" == "" ]]; then
    echo "Creating docker image ${_DOCKER_IMAGE_NAME}"
    docker build -t ${_DOCKER_IMAGE_NAME} .
  else
    echo "Using existing docker image ${_DOCKER_IMAGE_NAME}"
fi


set +e
docker rm -f ${NAME}
set -e

docker run -d \
    --name ${NAME} \
    -P \
    -e "VIRTUAL_HOST=${VIRTUAL_HOST}" \
    -e "LETSENCRYPT_HOST=${VIRTUAL_HOST}" \
    -e "LETSENCRYPT_EMAIL=${CONTACT_EMAIL}" \
    --restart always \
    ${_DOCKER_IMAGE_NAME}

CONTAINER_ID=$(docker ps -q -f name=^/${NAME}$)

echo "Docker container ${NAME} running as id ${CONTAINER_ID}"

docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
