targetScope = 'subscription'

// The main bicep module to provision Azure resources.
// For a more complete walkthrough to understand how this file works with azd,
// see https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/make-azd-compatible?pivots=azd-create

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// abbrevations located in abbreviations.json for consistency
var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}

// Generate a unique token to be used in naming resources.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}


// Add resources to be provisioned below.
// A full example that leverages azd bicep modules can be seen in the todo-python-mongo template:
// https://github.com/Azure-Samples/todo-python-mongo/tree/main/infra

module web 'core/host/appservice.bicep' = {
  name: 'appservice'
  scope: resourceGroup
  params: {
    name: '${abbrs.webSitesAppService}${environmentName}-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'app' })
    appServicePlanId: appServicePlan.outputs.id
    appCommandLine: 'gunicorn --workers 2 --timeout 60 --access-logfile "-" --error-logfile "-" --bind=0.0.0.0:8000 -k uvicorn.workers.UvicornWorker app.main:app'
    runtimeName: 'python'
    runtimeVersion: '3.11'
    scmDoBuildDuringDeployment: true
    ftpsState: 'Disabled'
  }
}

module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'serviceplan'
  scope: resourceGroup
  params: {
    name: '${abbrs.webServerFarms}${environmentName}-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
    }
    reserved: true
  }
}

module logAnalyticsWorkspace 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: resourceGroup
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${environmentName}-${resourceToken}'
    location: location
    tags: tags
  }
}

// Add outputs from the deployment here, if needed.
//
// This allows the outputs to be referenced by other bicep deployments in the deployment pipeline,
// or by the local machine as a way to reference created resources in Azure for local development.
// Secrets should not be added here.
//
// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output WEB_URI string = 'https://${web.outputs.uri}'
output AZURE_LOCATION string = location
