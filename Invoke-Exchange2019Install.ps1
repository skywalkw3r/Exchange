<#
.Synopsis
    # Exchange 2016 Install Script
    # V2 - 2.16.2020
    Future: 
        Write Progress?
        Multiple Servers?
        Email report?
        Parameter for ISO Name/location?
        Parameter for install location?
        Error checking:
            - Pre-Req Install
            - Exchange Install
.EXAMPLE
   C:\PS> Invoke-ExchangeServerInstall
.EXAMPLE
   C:\PS> Invoke-ExchangeServerInstall -ComputerName EX01 -StagingLocation 'C:\staging' -Roles Mailbox,ManagementTools
.EXAMPLE
   C:\PS> Invoke-ExchangeServerInstall -ComputerName EX01 -InstallWindowsComponents -PrepareAD -Roles EdgeTransport
#>
#Requires -RunAsAdministrator

function Invoke-ExchangeServerInstall {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        $ComputerName = $ENV:COMPUTERNAME,

        [Parameter()]
        [switch]$InstallWindowsComponents,

        [Parameter()]
        [switch]$InstallPreReqs,

        [Parameter()]
        [switch]$PrepareAD,

        [Parameter()]
        [ValidateSet('Mailbox','ManagementTools','EdgeTransport','Mailbox,ManagementTools')]
        $Roles,

        [Parameter()]
        $StagingLocation = 'C:\temp'

    )
    begin {
        # check for staging folder
        if(!(Test-Path $StagingLocation)){
            Write-Verbose "Staging folder does not exist! Creating new directory at $StagingLocation"
            New-Item $StagingLocation -ItemType Directory -Force
        }
        if($InstallPreReqs){
            # setup download client
            $webclient = New-Object System.Net.WebClient

            # download pre-reqs per - https://docs.microsoft.com/en-us/Exchange/plan-and-deploy/prerequisites?view=exchserver-2016
            Write-Verbose 'Downloading .NET Framework 4.8'
            $downloadurl = "https://go.microsoft.com/fwlink/?linkid=2088631"
            $webclient.Downloadfile($downloadurl, "$StagingLocation\ndp48-x86-x64-allos-enu.exe")

            Write-Verbose 'Downloading Visual C++ Redistributable Package for Visual Studio 2012'
            $downloadurl = "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
            $webclient.Downloadfile($downloadurl, "$StagingLocation\vcredist_2012_x64.exe")

            Write-Verbose 'Downloading Visual C++ Redistributable Package for Visual Studio 2013'
            $downloadurl = "https://aka.ms/highdpimfc2013x64enu"
            $webclient.Downloadfile($downloadurl, "$StagingLocation\vcredist_2013_x64.exe")

            Write-Verbose 'Downloading Unified Communications Managed API 4.0 Runtime'
            $downloadurl = "https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe"
            $webclient.Downloadfile($downloadurl, "$StagingLocation\ucmaRuntimeSetup.exe")
        }
    }
    process {
        if($InstallPreReqs){
            # install .Net 4.8
            Start-Process "$StagingLocation\ndp48-x86-x64-allos-enu.exe" -ArgumentList "/q /log $StagingLocation\ndp48.log" -Wait -Verbose

            # install Visual C++ Redistributable Package for Visual Studio 2012
            Write-Verbose 'Installing Visual C++ Redistributable Package for Visual Studio 2012'
            Start-Process "$StagingLocation\vcredist_2012_x64.exe" -ArgumentList "/install /quiet /norestart /log $StagingLocation\vcredist_2012_x64.log" -Wait -Verbose

            # install Visual C++ Redistributable Package for Visual Studio 2013
            Write-Verbose 'Installing Visual C++ Redistributable Package for Visual Studio 2013'
            Start-Process "$StagingLocation\vcredist_2013_x64.exe" -ArgumentList "/install /quiet /norestart /log $StagingLocation\vcredist_2013_x64.log" -Wait -Verbose

            # install Unified Communications Managed API 4.0 Runtime 
            Write-Verbose 'Installing Unified Communications Managed API 4.0 Runtime'
            Start-Process "$StagingLocation\ucmaRuntimeSetup.exe" -ArgumentList "/q" -Wait -Verbose

            # install required Lync Server or Skype for Business Server components
            Write-Verbose 'Installing Server-Media-Foundation Windows Feature required Lync Server or Skype for Business Server components'
            Install-WindowsFeature Server-Media-Foundation
        }
    
        # mount exchange iso
        Write-Verbose "Mounting Exchange 2016 ISO on $ENV:ComputerName"
        Mount-DiskImage -ImagePath "$StagingLocation\ExchangeServer2016-x64-CU15.ISO"

        # install exchange 2019 :)
        Write-Verbose "Installing Exchange 2016 on $ENV:ComputerName"
        .\Setup.EXE /Mode:Install /Roles:Mailbox,ManagementTools /IAcceptExchangeServerLicenseTerms /InstallWindowsComponents /PrepareAD /T:"F:\Microsoft\Exchange Server\V15\" #update to parameter?
        .\Setup.EXE /Mode:Install /IAcceptExchangeServerLicenseTerms /InstallWindowsComponents /PrepareAD 
    }
    end{}
}