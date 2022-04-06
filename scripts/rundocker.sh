#!/bin/bash

set -e

CONTAINER_HOME=/home/kivy

# Specifies the name of the docker volume used to store p4a cache
P4A_CACHE=p4a_cached_dir_$ARCH
PEW_CACHE=pew_cache_dir

CID_FILE=kolibri-android-app-container-id.cid.txt

# create the container to be used throughout the script
# creates a volume for reuse between builds, holding p4a's android distro
podman create -it \
  --mount type=volume,src=${P4A_CACHE},dst=${CONTAINER_HOME}/.local \
  --mount type=volume,src=${PEW_CACHE},dst=${CONTAINER_HOME}/.pyeverywhere \
  --env BUILDKITE_BUILD_NUMBER \
  --env P4A_RELEASE_KEYSTORE=${CONTAINER_HOME}/$(basename "${P4A_RELEASE_KEYSTORE}") \
  --env P4A_RELEASE_KEYALIAS \
  --env P4A_RELEASE_KEYSTORE_PASSWD \
  --env P4A_RELEASE_KEYALIAS_PASSWD \
  --env ARCH \
  --cidfile ${CID_FILE} \
  android_kolibri

# Used to reference container, rather than name. For concurrency.
# Removing immediately, but could use this to check if running.
CONTAINER_ID=$(more ${CID_FILE} && rm ${CID_FILE})

echo -ne "Creating android build container, ID: ${CONTAINER_ID}"

# make sure the environment variable is defined
if [ "${P4A_RELEASE_KEYSTORE}" ]; then
  # make sure the directory is valid
  if [ -a ${P4A_RELEASE_KEYSTORE} ]; then
    echo -e "Copying the signing key \n\t From ${P4A_RELEASE_KEYSTORE} to ${CONTAINER_ID}:${CONTAINER_HOME}"
    # copy keystore to same location on the container
    podman cp ${P4A_RELEASE_KEYSTORE} ${CONTAINER_ID}:${CONTAINER_HOME}
  fi
fi

# run the container, generating the apk
echo "Starting ${CONTAINER_ID}"
podman start -i ${CONTAINER_ID}

# copy the apk to our host. Handles permissions.
echo -e "Copying APK \n\t From ${CONTAINER_ID}:${CONTAINER_HOME}/dist/ to ${PWD}"
podman cp ${CONTAINER_ID}:${CONTAINER_HOME}/dist/ .

# manually remove the container afterward
echo -n "Removing "
podman rm ${CONTAINER_ID}
