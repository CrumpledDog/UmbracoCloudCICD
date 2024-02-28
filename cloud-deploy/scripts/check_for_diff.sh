#!/bin/bash
# Set variables
projectId="$1"
apiKey="$2"
pathToWorkspace="$3"
pathToAction="$4"
patchRequired="$5"
cloudPatchMessage="$6"
gitusername="$7"
gitemail="$8"
downloadFolder="tmp"
newline=$'\n'
mkdir -p $downloadFolder # ensure folder exists

if [[ "$patchRequired" = "false" ]]; then
  echo "No Git patch is required"  
  exit 0
fi

# Get latest deployment id
function get_latest_deployment_id {
  deployments_url="https://api.cloud.umbraco.com/v1/projects/$projectId/deployments?skip=$1&take=1"
  response=$(curl --insecure -s -X GET $deployments_url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
  latestDeploymentId=$(echo $response | jq -r '.deployments[0].deploymentId')
}

# Get diff - stores file as git-patch.diff
function get_changes {
  mkdir -p $downloadFolder # ensure folder exists
  change_url="https://api.cloud.umbraco.com/v1/projects/$projectId/deployments/$latestDeploymentId/diff"
  responseCode=$(curl --insecure -s -w "%{http_code}" -L -o "$downloadFolder/git-patch.diff" -X GET $change_url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
}

get_latest_deployment_id 0

# deployment id found
if [ -z "$latestDeploymentId" ]; then
    echo "Deployment id not found."
    exit 1
fi

get_changes

skip=1

while [[ $responseCode -eq 409 ]]; do

    sleep 10
    get_latest_deployment_id $skip

    # deployment id found
    if [ -z "$latestDeploymentId" ]; then
      echo "Deployment id not found."
      exit 1
    fi

    sleep 10
    get_changes
    ((skip++))
done

if [[ $responseCode -eq 204 ]]; then # Http 204 No Content means that there are no changes
  echo "No changes"
  rm -fr $downloadFolder/git-patch.diff
elif [[ $responseCode -eq 200 ]]; then # Http 200 downloads the file and set a few variables for pipeline
  pwd
  cd $pathToWorkspace
  pwd
  git clean -f -d -x
  git restore .
  git config --global user.name "$gitusername"
  git config --global user.email "$gitemail"
  git checkout -b "umbcloud/$latestDeploymentId"
  echo "$pathToAction/$downloadFolder/git-patch.diff"
  git apply "$pathToAction/$downloadFolder/git-patch.diff"
  rm -fr $pathToAction/$downloadFolder/git-patch.diff
  git status
  git add .
  git commit -m "Applied work from deployment $latestDeploymentId"
  git push --set-upstream origin "umbcloud/$latestDeploymentId"
  gh pr create --title "Umbraco Cloud deployment $latestDeploymentId" --body-file - <<< $"Latest changes from Umbraco Cloud: ${newline}$cloudPatchMessage" 
  exit 1
else
  echo "Unexpected status: $responseCode"
  exit 1
fi