Example yml for your project to use these actions, please adapt to your own needs/setup

```yml
name: Build and deploy to Umbraco Cloud

on:
  push:
    branches: [ main ]
  workflow_dispatch:
    
env:
  PATH_TO_FRONTEND: ${{ vars.PATH_TO_FRONTEND }}
  UMBRACO_CLOUD_API_KEY: ${{ secrets.UMBRACO_CLOUD_API_KEY }}
  UMBRACO_CLOUD_PROJECT_ID: ${{ vars.UMBRACO_CLOUD_PROJECT_ID }}
  CRUMPLED_PACKAGE_VIEW_TOKEN: ${{ secrets.CRUMPLED_PACKAGE_VIEW_TOKEN }}
  CRUMPLED_PACKAGE_FEED_URL: ${{ vars.CRUMPLED_PACKAGE_FEED_URL }}
  CRUMPLED_SLACK_OAUTH_HEALTHCHECKS: ${{ vars.CRUMPLED_SLACK_OAUTH_HEALTHCHECKS }}
  GH_TOKEN: ${{ github.token }}
      
jobs:
  setup:
    name: Setup
    runs-on: ubuntu-latest
    outputs:
      artifact-prefix: ${{ steps.set-artifact-prefix.outputs.ARTIFACT_PREFIX }}
      dotnet-base-path: ${{ steps.get-base-path.outputs.PATH_TO_BASE }}
      cloudsource-artifact: ${{ steps.set-artifact-prefix.outputs.ARTIFACT_PREFIX }}.cloudsource-${{ github.run_number }}

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Set Artifact Key Prefix
        id: set-artifact-prefix
        env:
          REPO_NAME: ${{ github.event.repository.name }}
        run: |
          typeset -l output
          output=${REPO_NAME// /_}
          echo "$output"
          echo "ARTIFACT_PREFIX=$output" >> "$GITHUB_OUTPUT"

      - name: Get DotNet Base Project Path
        id: get-base-path
        shell: bash
        run: |
          pathToBase=$(grep -oP 'base = "\K[^"]+' ${{ github.Workspace }}/.umbraco)
          echo "PATH_TO_BASE=$pathToBase" >> $GITHUB_OUTPUT

  build-fe:
    name: Build and test front end
    needs: setup
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js environment
        uses: actions/setup-node@v4
        with:
            node-version: 20.9.0
            cache: 'npm'
            cache-dependency-path: '${{env.PATH_TO_FRONTEND}}/package-lock.json'

      - name: Install dependencies
        working-directory: ./${{env.PATH_TO_FRONTEND}}
        run: npm ci

      - name: Run WebPack
        working-directory: ./${{env.PATH_TO_FRONTEND}}
        run: npm run build:ci

      - name: Create artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ needs.setup.outputs.artifact-prefix }}.frontend-${{ github.run_number }}
          path: |
            ${{needs.setup.outputs.dotnet-base-path}}/wwwroot/*
            ${{needs.setup.outputs.dotnet-base-path}}/Webpack/*   
          retention-days: 5

  build-be:
    name: Build and test back end
    needs: setup
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Add GitHub Package Registry
        run: dotnet nuget add source --username USERNAME --password ${{ secrets.GITHUB_TOKEN }} --store-password-in-clear-text --name github ${{env.CRUMPLED_PACKAGE_FEED_URL}}

      - name: Cache NuGet
        id: nuget-packages
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: nuget-cache-${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj*') }}
          restore-keys: |
            nuget-cache-${{ runner.os }}-nuget-

      - name: Setup .Net
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
          
      - name: Install Dependencies
        run: dotnet restore ${{ needs.setup.outputs.dotnet-base-path }}
      
      - name: Build
        run: dotnet build ${{ needs.setup.outputs.dotnet-base-path }} --configuration Release --no-restore

  create-cloud-source:
    name: Create source for Umbraco Cloud
    needs: [setup,build-fe]
    runs-on: ubuntu-latest
    outputs:
      artifact-name: ${{ steps.create-zip.outputs.artifact-name }}
    steps:
      - name: Create cloud source Zip
        id: create-zip
        uses: CrumpledDog/UmbracoCloudCICD/cloud-zip@main
        with:
          artifact-prefix: ${{ needs.setup.outputs.artifact-prefix }}
          path-to-frontend: ${{ env.PATH_TO_FRONTEND }}
          package-view-token: ${{ env.CRUMPLED_PACKAGE_VIEW_TOKEN }}
          package-feed-url: ${{ env.CRUMPLED_PACKAGE_FEED_URL }}
          slack_token: ${{ env.CRUMPLED_SLACK_OAUTH_HEALTHCHECKS }}

  publish:
    name: Publish to Umbraco Cloud
    needs: [setup,create-cloud-source]
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ needs.create-cloud-source.outputs.artifact-name }}
      - id: deploy-to-cloud
        uses: CrumpledDog/UmbracoCloudCICD/cloud-deploy@main
        with:
          umbraco-cloud-project-id: '${{ env.UMBRACO_CLOUD_PROJECT_ID }}'
          umbraco-cloud-api-key: '${{ env.UMBRACO_CLOUD_API_KEY }}'
          path-to-zip: '${{ needs.create-cloud-source.outputs.artifact-name }}.zip'
          git-username: "Crumpled Bot"
          git-email: "it@crumpled-dog.com"
```