# HELPER: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-7.3
# HELPER: https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/wiql/query-by-wiql?view=vsts-rest-tfs-4.1&tabs=HTTP
# HELPER: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod?view=powershell-7.3
# HELPER: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-html?view=powershell-5.1

# TODO: Convert to a function that can be called from the pipeline
# TODO: Make the script portable, and capable of running for any target build
# Function Start-EmailBuilder {
#     [CmdletBinding()]
#     Param(
#         [Parameter(Mandatory=$true)]
#         [string]$Product
#     )
# }


# # Set the target build using the Product environment variable which is the branch name
$Target = ($($env:Product).Split(" ")).WHERE({$_ -match "^\d+\.\d+"})

# # Build parameters for the query
# # TODO: Make the query dynamic based on the target build
$Data = @{query="SELECT [ID], [Title], [State] FROM workitems WHERE [State] = 'Code Complete' AND ([Discipline] Contains '$($Target)' OR [Target Build] Contains '$($Target)')"} | ConvertTo-Json



# For now, we'll just hardcode the query to look for 17.10
# $Data = @{query="SELECT [ID], [Title], [State] FROM workitems WHERE [State] = 'Code Complete' AND ([Discipline] Contains 'Fulfillment 17.10 - Release' OR [Target Build] Contains '17.10')"} | ConvertTo-Json
$Headers = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($env:TFSPAT)"))}
$URI = "http://****:8080/tfs/defaultcollection/_apis/wit/wiql?api-version=4.1"

# Make the query and get the work items
$QueryResults = Invoke-RestMethod -Method POST -ContentType 'Application/Json' -Body $Data -Uri $URI -Headers $Headers

# HTML parameters to build the HTML doc with the ConvertTo-Html cmdlet
$htmlParams = @{
    Title = "WorkItems"
    Head = "<style>body{font-family: Arial; font-size: 10pt;}table, th, td {border: .5px solid black;border-collapse: collapse;padding-left: 5px;padding-right: 5px;padding-top: .5px; padding-bottom: .5px}</style>"
    Body = "<br><h3>Work Items in Code Complete by User:</h3>"
}


# Use the workItems.id property to get the work items
# Here also establishes the arrays to hold the users and categories
$WorkItems = $QueryResults.workItems.id
$Users = @()
$Categories = @()

# Create the first HTML table header
$htmlParams.Body += "<table><tr><th>Assigned To</th><th>Count</th></tr>"

# Get the work item details and add the users and categories to their arrays
ForEach ($WorkItem in $WorkItems) {
    $WorkItemDetails = Invoke-RestMethod -Method GET -ContentType 'Application/Json' -Uri "http://****:8080/tfs/defaultcollection/_apis/wit/workitems/$($WorkItem)?api-version=4.1" -Headers $Headers
    $Users += $WorkItemDetails.fields.'System.AssignedTo'
    $Categories += $WorkItemDetails.fields.'User.Category'
}

# Group, count and sort the users and add them to the HTML
# The array of names is created by getting the enumerator of the grouped users, sorting by count, and then adding the name and count to the HTML
$GroupedNames = ($Users | Group-Object | Select-Object Name, Count).GetEnumerator() | Sort-Object Count -Descending
$GroupedNames.ForEach({$htmlParams.Body += "<tr><td>$($_.Name)</td><td>$($_.Count)</td></tr>"})
$htmlParams.Body += "</table><br>"


# Repeat the process for the categories
$htmlParams.Body += "<h3>Work Items in Code Complete by Category:</h3>"
$htmlParams.Body += "<table><tr><th>Category</th><th>Count</th></tr>"

$GroupedCategories = ($Categories | Group-Object | Select-Object Name, Count).GetEnumerator() | Sort-Object Count -Descending
$GroupedCategories.ForEach({$htmlParams.Body += "<tr><td>$($_.Name)</td><td>$($_.Count)</td></tr>"})
$htmlParams.Body += "</table><br>"

# Repeat the process for the work items, but this time add the work item details to the HTML table
$htmlParams.Body += "<h3>The following Work Items are in Code Complete state:</h3>"
$htmlParams.Body += "<table><tr><th>ID</th><th>Type</th><th>Category</th><th>Discipline</th><th>Assigned To</th></tr>"
ForEach ($WorkItem in $WorkItems) {
    $WIData = Invoke-RestMethod -Method GET -ContentType 'Application/Json' -Uri "http://***:8080/tfs/defaultcollection/_apis/wit/workitems/$($WorkItem)?api-version=4.1" -Headers $Headers
    $htmlParams.Body += "<tr><td><a href='http://iaswtfs18:8080/tfs/defaultcollection/_workitems/edit/$($WorkItem)'>$($WorkItem)</a></td>"
    $htmlParams.Body += "<td>$($WIData.fields.'System.WorkItemType')</td>"
    $htmlParams.Body += "<td>$($WIData.fields.'User.Category')</td>"
    $htmlParams.Body += "<td>$($WIData.fields.'Microsoft.VSTS.Common.Discipline')</td>"
    $htmlParams.Body += "<td>$($WIData.fields.'System.AssignedTo')</td></tr>"
}
$htmlParams.Body += "</table><br>"

# Write the HTML to a file 
ConvertTo-Html @htmlParams | Out-File -Encoding UTF8 -Force -FilePath .\here.html


# Return the HTML to the console to be consumed by the pipeline
Get-Content .\here.html

