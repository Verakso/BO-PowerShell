# Define username and password used to logon
$userName = "Administrator"
$passWord = "Password"
$authType = "secEnterprise" # can be either secEnterprise, secLDAP, secWinAD or secSAPR3

# Define the base URL and URLs for logon and logoff
$baseURL   = "http://localhost:6405/biprws"
$logonURL  = "$baseURL/logon/long"
$logoffURL = "$baseURL/logoff"

# Create a generic dictionary to hold the headers needed to communicate with the BI Rest Web Service
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept","Application/Json")
$headers.Add("Content-Type","Application/Json")

# Make the json object used for logon
$logonJson = @"
{
    "userName":  "$userName",
    "password":  "$passWord",
    "auth":  "$authType"
}
"@

# Log on to the BI Platform
$response = Invoke-RestMethod -Uri $logonURL -Method Post -Headers $headers -Body $logonJson

# Retrieve the logonToken, this assumes everything went OK, since Invoke-RestMethod doesn't support .StatusCode
$SAPToken = $response.logonToken

# Add the logonToken to the headers collection
$headers.Add("X-SAP-Logontoken",$SAPToken)

# Create json for a new user
$userJson = @"
{
    "emailAddress":  "",
    "isPasswordToChangeAtNextLogon":  false,
    "isPasswordChangeAllowed":  false,
    "description":  "This user was created by a script",
    "fullName":  "Demo User 01",
    "newPassword":  "Password1",
    "connection":  0,
    "isPasswordExpiryAllowed":  true,
    "title":  "Demo01"
}
"@

# Post the userJson to the BI platform
$response = Invoke-RestMethod -Uri "${baseUrl}/users/user " -Method Post -Headers $headers -Body $userJson

# Retrive the user ID for later use
$userID = $response.entries.id

# Create json for adding new group
$groupJson = @"
{
    "description":  "Group containing Demo Users",
    "title":  "Demo Users"
}
"@

# Post the groupJson to create the new group
$response = Invoke-RestMethod -Uri "${baseUrl}/userGroups/userGroup" -Method Post -Headers $headers -Body $groupJson

# Retrieve the newly created group ID
$groupId = $response.entries.id

# Retrive the group object for the newly created group
$groupInfo = Invoke-RestMethod -Uri "${baseUrl}/userGroups/${groupId}" -Method Get -Headers $headers

# Add the new user to the group
$groupInfo.addMembers = "$userID"

# Create a new object that can be used to parse the information back
$newGroupObject = @{
    cuid = $groupInfo.cuid
    Description = $groupInfo.Description
    addMembers = $groupInfo.addMembers
    removeMembers = $groupInfo.removeMembers
    id = $groupInfo.id
    title = $groupInfo.title
    parentID = $groupInfo.parentID
}

$newGroupJson = ConvertTo-Json($newGroupObject)

# Submit the changes back to the server
$response = Invoke-RestMethod -Uri "${baseUrl}/userGroups/${groupId}" -Method Put -Headers $headers  -Body $newGroupJson

Write-Host $response.entries.SuccessAddingMessage

<#
Invoke-RestMethod -Uri "${baseUrl}/userGroups/${groupId}" -Method Delete -Headers $headers
Invoke-RestMethod -Uri "${baseUrl}/users/$userID" -Method Delete -Headers $headers
#>

# Log off the BI Platform (and release the logonToken)
Invoke-RestMethod -Uri $logoffURL -Method Post -Headers $headers
