#!/bin/bash
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function processApiResponse {
  response="$1"
  
  #echo $response
  #echo "Array count: '$array_count'"

  status=$(echo $response | jq -r '.deploymentState')
  updateMessage=$(echo $response | jq -r '.updateMessage')
  deploymentId=$(echo $response | jq -r '.deploymentId')
  errorMessage=$(echo $response | jq -r '.errorMessage')

  if [ ! -z "$errorMessage" ]; then
    echo -e "${RED}$errorMessage${NC}"
  fi

  mapfile -t lines_array <<< $updateMessage

  if [[ ${#lines_array[@]} -gt $array_count ]]; then
    echo -e "Status is ${GREEN}$status${NC}, new information from Cloud"
    if [ -n "$lines_array" ]; then
      for i in "${!lines_array[@]}"; do 
        if [[ $i -ge $array_count ]]; then
          echo -e "$i ${CYAN}${lines_array[$i]}${NC}"
          if [[ "${lines_array[$i]:0:12}" = "Cannot apply" ]]; then
            cloudUpgradeMessage=$(echo "${lines_array[$i]}" | grep -o 'downgraded:.*$' | grep -o ':.*$' | sed 's/://' | sed 's/^ //')
            echo "CLOUD_UPGRADE_MESSAGE=$cloudUpgradeMessage" >> $GITHUB_OUTPUT
          fi
        fi
      done
    fi
  else
    echo -e "Status is ${BLUE}$status${NC}, nothing new from Cloud, waiting 15 seconds..."
  fi

  array_count=${#lines_array[@]}

}