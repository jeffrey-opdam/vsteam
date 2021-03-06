Set-StrictMode -Version Latest

Get-Module VSTeam | Remove-Module -Force
Import-Module $PSScriptRoot\..\..\src\team.psm1 -Force
Import-Module $PSScriptRoot\..\..\src\users.psm1 -Force

InModuleScope users {
   $VSTeamVersionTable.Account = 'https://test.visualstudio.com'
   
   Describe "Users TFS Errors" {
      Context 'Get-VSTeamUser' {  
         Mock _callAPI { throw 'Should not be called' } -Verifiable

         It 'Should throw' {
            { Get-VSTeamUser } | Should Throw
         }

         It '_callAPI should not be called' {
            Assert-MockCalled _callAPI -Exactly 0
         }
      }
   }

   Describe "Users VSTS" {

      # Must be defined or call will throw error
      $VSTeamVersionTable.MemberEntitlementManagement = '4.1-preview'

      Context 'Get-VSTeamUser no parameters' {  
         Mock  _callAPI { return [PSCustomObject]@{ 
               count = 1
               value = [PSCustomObject]@{ accessLevel = [PSCustomObject]@{ } }
            } 
         }

         It 'Should return users' {
            Get-VSTeamUser 

            # Make sure it was called with the correct URI
            Assert-MockCalled _callAPI -Exactly 1 -ParameterFilter {
               $url -eq "https://test.vsaex.visualstudio.com/_apis/userentitlements/?api-version=$($VSTeamVersionTable.MemberEntitlementManagement)&top=100&skip=0"
            }
         }
      }

      Context 'Get-VSTeamUser By ID' {  
         Mock  _callAPI {
            return [PSCustomObject]@{
               accessLevel = [PSCustomObject]@{ }
               email       = 'fake@email.com'
            } 
         }

         It 'Should return users with projects' {
            Get-VSTeamUser -Id '00000000-0000-0000-0000-000000000000'

            # Make sure it was called with the correct URI
            Assert-MockCalled _callAPI -Exactly 1 -ParameterFilter {
               $subDomain -eq 'vsaex' -and
               $id -eq '00000000-0000-0000-0000-000000000000' -and
               $resource -eq 'userentitlements'
            }
         }
      }

      Context 'Get-VSTeamUser with select for projects' {  
         Mock  _callAPI {
            return [PSCustomObject]@{ 
               count = 1
               value = [PSCustomObject]@{ 
                  accessLevel = [PSCustomObject]@{ }
                  email       = 'fake@email.com'
               }
            } 
         }

         It 'Should return users with projects' {
            Get-VSTeamUser -Select Projects

            # Make sure it was called with the correct URI
            Assert-MockCalled _callAPI -Exactly 1 -ParameterFilter {
               $url -eq "https://test.vsaex.visualstudio.com/_apis/userentitlements/?api-version=$($VSTeamVersionTable.MemberEntitlementManagement)&top=100&skip=0&Select=Projects"
            }
         }
      }

      Context 'Remove-VSTeamUser by Id' {
         Mock _callAPI

         Remove-VSTeamUser -UserId '00000000-0000-0000-0000-000000000000' -Force

         It 'Should remmove user' {
            Assert-MockCalled _callAPI -Exactly 1 -ParameterFilter {
               $subDomain -eq 'vsaex' -and
               $id -eq '00000000-0000-0000-0000-000000000000' -and
               $resource -eq 'userentitlements' -and
               $method -eq 'Delete' -and
               $version -eq $VSTeamVersionTable.MemberEntitlementManagement
            }
         }
      }

      Context 'Remove-VSTeamUser by email' {
         Mock _callAPI -ParameterFilter {
            $Method -eq 'Delete' -and
            $subDomain -eq 'vsaex' -and
            $id -eq '00000000-0000-0000-0000-000000000000' -and
            $resource -eq 'userentitlements' -and
            $version -eq $VSTeamVersionTable.MemberEntitlementManagement
         }
         Mock  _callAPI {
            return [PSCustomObject]@{ 
               count = 1
               value = [PSCustomObject]@{ 
                  accessLevel = [PSCustomObject]@{ }
                  email       = 'test@user.com'
                  id          = '00000000-0000-0000-0000-000000000000'
               }
            } 
         }

         Remove-VSTeamUser -Email 'test@user.com' -Force

         It 'Should remmove user' {
            Assert-MockCalled _callAPI -Exactly 1 -ParameterFilter {
               $Method -eq 'Delete' -and
               $subDomain -eq 'vsaex' -and
               $id -eq '00000000-0000-0000-0000-000000000000' -and
               $resource -eq 'userentitlements' -and
               $version -eq $VSTeamVersionTable.MemberEntitlementManagement
            }
         }
      }

      Context 'Remove-VSTeamUser by invalid email' {
         Mock _callAPI { return [PSCustomObject]@{ 
               count = 1
               value = [PSCustomObject]@{ 
                  accessLevel = [PSCustomObject]@{ }
                  email       = 'test@user.com'
                  id          = '00000000-0000-0000-0000-000000000000'
               }
            } 
         }

         It 'Should throw' {
            { Remove-VSTeamUser -Email 'not@found.com' -Force } | Should Throw
         }
      }

      Context 'Add-VSTeamUser' {
         $obj = @{
            accessLevel         = @{
               accountLicenseType = 'earlyAdopter'
            }
            user                = @{
               principalName = 'test@user.com'
               subjectKind   = 'user'
            }
            projectEntitlements = @{
               group      = @{
                  groupType = 'ProjectContributor'
               }
               projectRef = @{
                  id = $null
               }
            }
         }
   
         $expected = $obj | ConvertTo-Json

         Mock _callAPI -Verifiable -ParameterFilter {
            $Method -eq 'Post' -and
            $Body -eq $expected
         }

         Add-VSTeamUser -License earlyAdopter -Email 'test@user.com'

         It 'Should add a user' {
            Assert-VerifiableMocks
         }
      }
   }
}