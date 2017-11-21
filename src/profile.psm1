Set-StrictMode -Version Latest

# Load common code
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

function Get-VSTeamProfile {
   if (Test-Path "$HOME/profiles.json") {
      try {
         # We needed to add ForEach-Object to unroll and show the inner type
         $result = Get-Content "$HOME/profiles.json" | ConvertFrom-Json

         if ($result) {
            return ($result | ForEach-Object { $_ })
         }
      }
      catch {         
         # Catch any error and fail to the return empty array below
      }
   }
      
   return '[]' | ConvertFrom-Json
}

function Remove-VSTeamProfile {
   [CmdletBinding()]
   param(
      # Name is an array so I can pass an array after -Name 
      # I can also use pipe
      [parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
      [string[]] $Name
   )

   begin {
      [System.Collections.ArrayList]$profiles = Get-VSTeamProfile
   }

   process {
      foreach ($item in $Name) {
         # See if this item is already in there
         $profile = $profiles | Where-Object Name -eq $item

         if ($profile) {
            $profiles.Remove($profile) | Out-Null
         }     
      }
   }

   end {
      $contents = ConvertTo-Json $profiles
      
      Set-Content -Path "$HOME/profiles.json" -Value $contents
   }
}

function Add-VSTeamProfile {
   [CmdletBinding(DefaultParameterSetName = 'Secure')]
   param(
      [parameter(ParameterSetName = 'Windows', Mandatory = $true, Position = 1)]
      [parameter(ParameterSetName = 'Secure', Mandatory = $true, Position = 1)]
      [Parameter(ParameterSetName = 'Plain')]
      [string] $Account,
      [parameter(ParameterSetName = 'Plain', Mandatory = $true, Position = 2, HelpMessage = 'Personal Access Token')]
      [string] $PersonalAccessToken,
      [parameter(ParameterSetName = 'Secure', Mandatory = $true, HelpMessage = 'Personal Access Token')]
      [securestring] $SecurePersonalAccessToken,
      [string] $Name
   )

   process {
      if ($SecurePersonalAccessToken) {
         # Convert the securestring to a normal string
         # this was the one technique that worked on Mac, Linux and Windows
         $credential = New-Object System.Management.Automation.PSCredential $account, $SecurePersonalAccessToken
         $_pat = $credential.GetNetworkCredential().Password
      }
      else {
         $_pat = $PersonalAccessToken
      }

      # If they only gave an account name add visualstudio.com
      if ($Account -notlike "*/*") {
         if ($Account -match "(?<protocol>https?\://)?(?<account>[A-Z0-9][-A-Z0-9]*[A-Z0-9])(?<domain>\.visualstudio\.com)?") {
            $Account = "https://$($matches.account).visualstudio.com"
         }
      }

      $authType = "Pat"
      $encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$_pat"))

      # If no SecurePersonalAccessToken is entered, and on windows, are we using default credentials for REST calls
      if ((!$_pat) -and (_isOnWindows) -and ($UsingWindowsAuth)) {
         Write-Verbose "Using Default Windows Credentials for authentication; no Personal Access Token required"
         $encodedPat = ""
         $authType = "OnPremise"
      }

      if (-not $Name) {
         $Name = $Account
      }

      [System.Collections.ArrayList]$profiles = Get-VSTeamProfile

      # See if this item is already in there
      # I am testing URL because the user may provide a different
      # name and I don't want two with the same URL.
      $profile = $profiles | Where-Object URL -eq $Account

      if ($profile) {
         $profiles.Remove($profile)
      }

      # Without the Out-Null the original size is showing in output.
      $profiles.Add([PSCustomObject]@{
            Name = $Name
            URL  = $Account
            Type = $authType
            Pat  = $encodedPat
         }) | Out-Null

      $contents = ConvertTo-Json $profiles

      Set-Content -Path "$HOME/profiles.json" -Value $contents
   }
}

Set-Alias Get-Profile Get-VSTeamProfile
Set-Alias Add-Profile Add-VSTeamProfile
Set-Alias Remove-Profile Remove-VSTeamProfile

Export-ModuleMember `
   -Function Get-VSTeamProfile, Add-VSTeamProfile, Remove-VSTeamProfile `
   -Alias Get-Profile, Add-Profile, Remove-Profile