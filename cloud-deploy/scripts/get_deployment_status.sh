#!/bin/bash

source scripts/shared_functions.sh

# Set variables
projectId="$1"
deploymentId="$2"
url="https://api.cloud.umbraco.com/v1/projects/$projectId/deployments/$deploymentId"
apiKey="$3"
array_count="$4"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
api_count=0

# Define function to call API and check status
function call_api {
  response=$(curl --insecure -s -X GET $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
#echo "$response"
  status=$(echo $response | jq -r '.deploymentState')
  updateMessage=$(echo $response | jq -r '.updateMessage')
  deploymentId=$(echo $response | jq -r '.deploymentId')
  errorMessage=$(echo $response | jq -r '.errorMessage')
}

status="Init"

while [[ $status == "Init" || $status == "Pending" || $status == "InProgress" || $status == "Queued" ]]; do
  call_api
  sleep 15 
  processApiResponse "$response"

    # Wait max 20 minutes. This is a variable value depending on your project
  if [[ $SECONDS -gt 1200 ]]; then
    echo -e "${RED}Timeout reached, exiting loop.${NC}"
    break
  fi

  ((api_count++))

done

# Check final status
if [[ $status == "Completed" ]]; then
  echo -e "${GREEN}Deployment completed successfully.${NC}"
  echo "PATCH_REQUIRED=false" >> "$GITHUB_OUTPUT"
elif [[ $status == "Failed" ]]; then
  echo -e "${RED}Deployment failed. Beginning patch procedure.${NC}"
  echo "PATCH_REQUIRED=true" >> "$GITHUB_OUTPUT"
else
  echo -e "${RED}Unexpected status: $status${NC}"
  echo "PATCH_REQUIRED=false" >> "$GITHUB_OUTPUT"
  exit 1
fi