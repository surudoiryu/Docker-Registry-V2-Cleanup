#!/bin/bash

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_WHITE='\033[1;37m'

printf "${C_GREEN}=======================================\nStarting Docker Registry Cleaner V0.1.0\n=======================================${C_WHITE}\n\n"
printf "${C_RED}Make sure that you have enabled deletion of images in the registry \r\n${C_WHITE}See: https://docs.docker.com/registry/configuration/#delete.\n\n"

# Username for registry (Basic Auth)
echo -n Username:
read UNAME
# Password for registry hidden (Basic Auth)
echo -n Password:
read -s UPASS
echo

# set defaults
set -e
UREGI="your.registry.com:5000"              # Registry URL
PROTOCOL="https://"                         # Http or Https
REGCONT="dockerregistry_registry_1"         # Name of the registry container
REGCONF="/etc/docker/registry/config.yml"   # Config file of the registry
REMOVE_LATEST="false"                       # Remove latest tags
REMOVE_VERSION="false"                      # Remove version tags
DRY_RUN="true"                              # Enable fake run

REGISTRY=${PROTOCOL}${UNAME}:${UPASS}@${UREGI}/v2/
REPO_LIST=$(curl -Ss ${REGISTRY}_catalog | jq -r '.repositories[] | @uri')

printf "\n${C_GREEN}=========================\nChecking all repositories\n=========================${C_WHITE}\n\n"
for i in ${REPO_LIST}
do
  printf "Found image:${C_YELLOW} ${i} ${C_WHITE}- checking tags...\n"
  if [[ $(curl -Ss ${REGISTRY}${i}/tags/list | jq -r '.tags | @uri') == 'null' ]]
  then
    printf "== No tags found\n"
  else

    TAG_LIST=$(curl -Ss ${REGISTRY}${i}/tags/list | jq -r '.tags[] | @uri')
    for j in ${TAG_LIST}
    do
      # Remove all but these images
      if [ ${j} ]
      then
          skip=0;
          if [ ${j} != "latest" ] && [ ${REMOVE_LATEST} == "true" ]
          then
            # If we dont want to remove the latest and this image is not the latest tag, then skip it
            skip=1;
          fi

          if [[ ${j} != *.* ]] && [ ${REMOVE_VERSION} == "true" ]
          then
            # If we dont want to remove version images and this is not a version tagm then skip it
            skip=1;
          fi

          if [ ${skip} == 0 ]
          then
            DIGEST=$(curl -s -i -H "Accept: application/vnd.docker.distribution.manifest.v2+json" ${REGISTRY}${i}/manifests/${j} | awk 'BEGIN {FS=": "}/^Docker-Content-Digest/{print $2}' )
            printf "== Getting Digest hash:${C_YELLOW} ${REGISTRY}${i}/manifests/${DIGEST%$'\r'}${C_WHITE}\n"
            if [ ${DRY_RUN} == "true" ]; then
              printf "${C_YELLOW}Would have run: ${C_WHITE}curl -v -s ${CURL_INSECURE_ARG} -X DELETE [registry-location]${i}/manifests/${DIGEST%$'\r'} -H 'Accept: application/vnd.docker.distribution.manifest.v2+json'\n"
            else
              curl -v -s -XDELETE ${REGISTRY}${i}/manifests/${DIGEST%$'\r'} -H "Accept: application/vnd.docker.distribution.manifest.v2+json"
              printf "== Removing image tag:${C_RED} ${j}${C_WHITE}\n"
            fi
          fi
      fi
    done
    curl ${REGISTRY}${i}/tags/list
  fi
done

printf "\n${C_GREEN}===============================\nCleaning up the Docker Registry\n===============================${C_WHITE}\n\n"
MANIFESTS_WITHOUT_TAGS=$(comm -23 <(find . -type f -name "link" | grep "_manifests/revisions/sha256" | grep -v "\/signatures\/sha256\/" | awk -F/ '{print $(NF-1)}' | sort) <(for f in $(find . -type f -name "link" | grep "_manifests/tags/.*/current/link"); do cat ${f} | sed 's/^sha256://g'; echo; done | sort))

CURRENT_COUNT=0
FAILED_COUNT=0
TOTAL_COUNT=$(echo ${MANIFESTS_WITHOUT_TAGS} | wc -w | tr -d ' ')

if [ ${TOTAL_COUNT} -gt 0 ]; then
	DF_BEFORE=$(df -Ph . | awk 'END{print}')

	printf "Found ${C_RED}${TOTAL_COUNT}${C_WHITE} manifests. Starting to clean up"

	if [ ${DRY_RUN} == "true" ]; then
		printf " ${C_YELLOW}..not really, because dry-run.${C_WHITE}"
	fi
  printf "\n"

	for manifest in ${MANIFESTS_WITHOUT_TAGS}; do
		complete_repo=$(find . | grep "_manifests/revisions/sha256/${manifest}/link" | awk -F "_manifest"  '{print $(NF-1)}' | sed 's#^./\(.*\)/#\1#') &> /dev/null
    repo=$(basename $complete_repo)

		if [ ${DRY_RUN} == "true" ]; then
			printf "${C_YELLOW}Would have run: ${C_WHITE}curl -fsS ${CURL_INSECURE_ARG} -X DELETE [registry-location]/${repo}/manifests/sha256:${manifest}\n"
		else
			curl -fsS ${CURL_INSECURE_ARG} -X DELETE ${REGISTRY}${repo}/manifests/sha256:${manifest} &> /dev/null
			exit_code=$?

			if [ ${exit_code} -eq 0 ]; then
				CURRENT_COUNT=$((CURRENT_COUNT+1))
			else
				FAILED_COUNT=$((FAILED_COUNT+1))
			fi
		fi
	done

	DF_AFTER=$(df -Ph . | awk 'END{print}')

	if [ ${DRY_RUN} == "true" ]; then
		printf "${C_RED}DRY_RUN over\n"
	else
		printf "Job done, Cleaned ${C_GREEN}${CURRENT_COUNT}${C_WHITE} of ${C_RED}${TOTAL_COUNT}${C_WHITE} manifests.\n"

		if [ ${FAILED_COUNT} -gt 0 ]; then
			printf "${C_RED}${FAILED_COUNT} manifests failed. ${C_WHITE}Check for curl errors in the output above.\n"
		fi

		printf "${C_WHITE}Disk usage before and after:\n${C_RED}${DF_BEFORE}\n${C_GREEN}${DF_AFTER}\n"
	fi
else
	printf "${C_GREEN}No manifests without tags found. Nothing to do.\n"
fi

printf "\n${C_GREEN}===============================\nCleaning up the Docker Registry\n===============================${C_WHITE}\n\n"
if [ ${DRY_RUN} == "true" ]; then
  echo DRY RUN is activated, deactivate it first.
else
  echo Starting...
  docker exec -it ${REGCONT} bin/registry garbage-collect ${REGCONF} &> /dev/null
  echo Done...
fi

printf "\n${C_GREEN}===============================\nCleanup done\n===============================${C_WHITE}\n\n"
