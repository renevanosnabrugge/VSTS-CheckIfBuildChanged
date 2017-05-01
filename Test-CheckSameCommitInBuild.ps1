$env:SYSTEM_TEAMFOUNDATIONSERVERURI = "account.visualstudio.com"
$env:SYSTEM_TEAMPROJECT = "yourProject"
$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = "https://account.visualstudio.com/"
$env:PersonalAccessToken="your PAT"

cd $PSScriptRoot

. .\CheckSameCommitInBuild.ps1 -pester -currentBuildID <buildID>

Invoke-CheckSameCommitInBuild 
