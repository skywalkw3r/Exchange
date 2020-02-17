<#
.Synopsis
    # Exchange 2016 Install Script
    # V2 - 2.16.2020
    Future: 
        Write Progress?
        Multiple Servers?
        Email report?
        Parameter Org NAME
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
        $ExchangeISO = 'ExchangeServer2016-x64-CU15.ISO',
        
        [Parameter()]
        [switch]$InstallWindowsComponents,

        [Parameter()]
        [switch]$InstallPreReqs,

        [Parameter()]
        $InstallPath = 'P:\Microsoft\Exchange Server\V15',
        
        [Parameter()]
        $OrgName = 'Homelabz',
        
        [Parameter()]
        [switch]$PrepareAD,

        [Parameter()]
        [switch]$PrepareSchema,

        [Parameter()]
        [ValidateSet('Mailbox','ManagementTools','EdgeTransport','Mailbox,ManagementTools')]
        $Roles,

        [Parameter()]
        $StagingLocation = 'C:\temp\exiso'

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
            
            Remove-Object $webclient
        }
    }
    process {
        if($InstallWindowsComponents){
            # install windows features
            Install-WindowsFeature NET-Framework-45-Features, Server-Media-Foundation, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, RSAT-ADDS, ADLDS # only for edge transport?
        }
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
            #Start-Process "$StagingLocation\ucmaRuntimeSetup.exe" -ArgumentList "/q" -Wait -Verbose
            #Get from ISO?
        }
        ####REBOOOT???
        # mount exchange iso
        Write-Verbose "Mounting $ExchangeISO ISO on $ENV:ComputerName"
        Mount-DiskImage -ImagePath "$StagingLocation\$ExchangeISO" # need to update for source parameter

        Write-Verbose "Invoking Exchange 2016 installer on $ENV:ComputerName"
        if($PrepareSchema){
            Write-Verbose "Invoking PrepareSchema"
            .\Setup.EXE /PrepareSchema /IAcceptExchangeServerLicenseTerms
            # error Check Schema after update? "Exchange Schema Version = " + ([ADSI]("LDAP://CN=ms-Exch-Schema-Version-Pt," + ([ADSI]"LDAP://RootDSE").schemaNamingContext)).rangeUpper
        }
        if($PrepareAD){ # NEEDED FOR EVER INSTALL MINUS ORGNAME? https://practical365.com/exchange-server/installing-exchange-server-2016/
            Write-Verbose "Invoking PrepareAD"
            .\Setup.EXE /PrepareAD /IAcceptExchangeServerLicenseTerms /on:$OrgName    
        }
        .\Setup.EXE /IAcceptExchangeServerLicenseTerms /M:Install /R:Mailbox /on:$OrgName /InstallWindowsComponents /t:$InstallPath
        #.\Setup.EXE /Mode:Install /IAcceptExchangeServerLicenseTerms /InstallWindowsComponents
    }
    end {}
}