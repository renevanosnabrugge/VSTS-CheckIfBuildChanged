﻿param
(
    [int] $currentBuildID,
    [switch] $pester
)

#global variables
$baseurl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI 
$baseurl += $env:SYSTEM_TEAMPROJECT + "/_apis"

Write-Debug  "baseurl=$baseurl"

function New-VSTSAuthenticationToken
{
    [CmdletBinding()]
    [OutputType([object])]
         
    $accesstoken = "";
    if([string]::IsNullOrEmpty($env:System_AccessToken)) 
    {
        if([string]::IsNullOrEmpty($env:PersonalAccessToken))
        {
            throw "No token provided. Use either env:PersonalAccessToken for Localruns or use in VSTS Build/Release (System_AccessToken)"
        } 
        Write-Debug $($env:PersonalAccessToken)
        $userpass = ":$($env:PersonalAccessToken)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userpass))
        $accesstoken = "Basic $encodedCreds"
    }
    else 
    {
        $accesstoken = "Bearer $env:System_AccessToken"
    }

    return $accesstoken;
}

function Get-BuildDefinition
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [string] $BuildDefinitionName=""
    )

    $token = New-VSTSAuthenticationToken
    $bdURL = "$baseurl/build/definitions?api-version=2.0"
    Write-Verbose "bdURL: $bdURL"
    
    $response = Invoke-RestMethod -Uri $bdURL -Headers @{Authorization = $token}  -Method Get
    $buildDef = $response.value | Where-Object {$_.name -eq $BuildDefinitionName} | select -First 1
    Write-Verbose "Build Definition: $buildDef"
    return $buildDef
}

function Get-BuildById
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [int] $BuildId
    )

    $token = New-VSTSAuthenticationToken
    $bdURL = "$baseurl/build/builds/$BuildId"
    
    $response = Invoke-RestMethod -Uri $bdURL -Headers @{Authorization = $token}  -Method Get
    return $response
}

<#
.Synopsis
Sets a Build Tag on a specific BuildID. Semicolon separates multiple Build Tags (e.g. Test;TEST2;Ready)
#>
function Set-BuildTag
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [string] $BuildID="",
        [string] $BuildTags=""
    )

    $buildTagsArray = $BuildTags.Split(";");

    $token = New-VSTSAuthenticationToken

    Write-Host "BaseURL: [$baseurl]"
    Write-Host "tagURL: [$tagURL]"
    Write-Host "token: [$token]"

    if ($buildTagsArray.Count -gt 0) 
    {

        foreach($tag in $buildTagsArray)
        {
            $tagURL = "$baseurl/build/builds/$BuildID/tags/$tag`?api-version=2.0"
            $response = Invoke-RestMethod -Uri $tagURL -Headers @{Authorization = $token}  -Method Put
            Write-Host $response
        }   
    }
}


<#
.Synopsis
Gets builds with a specific Tag. Semicolon separates multiple Build Tags (e.g. Test;TEST2;Ready)
#>
function Get-BuildsByDefinition
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [int] $BuildDefinitionID
    )
    $token = New-VSTSAuthenticationToken
    
    
    $buildsbyDefinitionURL = "$baseurl/build/builds?definitions=$BuildDefinitionID&api-version=2.0"

    $_builds = Invoke-RestMethod -Uri $buildsbyDefinitionURL -Headers @{Authorization = $token}  -Method Get -ContentType "application/json" 
    Write-Verbose "Builds $_builds"
    return $_builds
}


function Invoke-CheckSameCommitInBuild
{
    
    $CurrentBuild = Get-BuildById -BuildId $currentBuildID
    $builds = Get-BuildsByDefinition -BuildDefinitionID $CurrentBuild.definition[0].id

    $LatestBuild = $builds.value | Where-Object {$_.result -eq "succeeded"} |Sort-Object {$_.finishtime} -Descending | select -First 1

    if ($LatestBuild -eq $null)
    {
        #No successfull builds found, thus different commit"
        Set-BuildTag -BuildID $currentBuildID -BuildTags "Release" 

    }

    if ($LatestBuild.sourceVersion -ne $CurrentBuild.sourceVersion)
    {
        # Not the same, tag with a Release Tag
        Set-BuildTag -BuildID $currentBuildID -BuildTags "Release" 
    }
}

if (-not $pester) 
{
    Invoke-CheckSameCommitInBuild
}

