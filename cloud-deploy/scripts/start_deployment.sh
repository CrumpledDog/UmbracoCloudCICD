#!/bin/bash
source scripts/shared_functions.sh

# Set variables
projectId="$1"
deploymentId="$2"
url="https://api.cloud.umbraco.com/v1/projects/$projectId/deployments/$deploymentId"
apiKey="$3"
array_count="$4"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Define function to call API to start thedeployment
function call_api {
  echo "Start deployment: $url"
  response=$(curl --insecure -s -X PATCH $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json" \
    -d "{\"deploymentState\": \"Queued\"}")
  # echo "$response"
  deployment_id=$(echo "$response" | jq -r '.deploymentId')

  processApiResponse "$response"
 
  # http status 202 expected here
  # extract status for validation
  status=$(echo "$response" | jq -r '.deploymentState')
  if [[ $status != "Queued" ]]; then
    echo "Unexpected status: $status"
    exit 1
  fi
}

call_api

echo -e "${GREEN}Deployment started successfully${NC} -> ${CYAN}$deployment_id${NC}."
echo "ARRAY_COUNT=$array_count" >> "$GITHUB_OUTPUT"