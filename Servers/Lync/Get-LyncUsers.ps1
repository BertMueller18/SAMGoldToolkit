﻿##########################################################################
# 
# Get-LyncUsers
#
##########################################################################

<#
.SYNOPSIS
 The Get-LyncUsers script queries a single Lync server and produces up 1 CSV files
	1)    LyncUsers.csv - One record per user including enabled features and required CAL

.PARAMETER      UserName
Lync Server Username

.PARAMETER		Password
Lync Server Password

.PARAMETER      LyncServerName
Accepts a Fully Qualified Lync Server Domain Name
e.g. Server01.domain.local

.PARAMETER		OutputFile1
Output CSV file to store the results

#>

param(
	$UserName,
	$Password,
	[alias("server")]
	$LyncServer,
    [ValidateSet("Both", "RemoteSession","SnapIn")] 
	$ConnectionMethod = "Both",
	[alias("o1")]
	[string] $OutputFile1 = "LyncUsers.csv",
	[alias("log")]
	[string] $LogFile = "LyncLogFile" + $LyncServer + ".txt",
    [switch]
	$Verbose
)

function InitialiseLogFile {
	if ($LogFile -and (Test-Path $LogFile)) {
		Remove-Item $LogFile
	}
}

function LogText {
	param(
		[Parameter(Position=0, ValueFromRemainingArguments=$true, ValueFromPipeline=$true)]
		[Object] $Object,
		[System.ConsoleColor]$color = [System.Console]::ForegroundColor,
		[switch]$NoNewLine = $false  
	)

	# Display text on screen
	Write-Host -Object $Object -ForegroundColor $color -NoNewline:$NoNewLine

	if ($LogFile) {
		$Object | Out-File $LogFile -Encoding utf8 -Append 
	}
}

function LogError([string[]]$errorDescription){
	if ($Verbose){
		LogText ""
	}

	$output = Get-Date -Format HH:mm:ss.ff
	$output += " - "
	$output += $errorDescription -join "`r`n              "
	LogText $output -Color Red
	Start-Sleep -s 3
}

function LogLastException() {
    $currentException = $Error[0].Exception;

    while ($currentException)
    {
        LogText -Color Red $currentException
        LogText -Color Red $currentException.Data
        LogText -Color Red $currentException.HelpLink
        LogText -Color Red $currentException.HResult
        LogText -Color Red $currentException.Message
        LogText -Color Red $currentException.Source
        LogText -Color Red $currentException.StackTrace
        LogText -Color Red $currentException.TargetSite

        $currentException = $currentException.InnerException
    }

	Start-Sleep -s 3
}

function LogProgress([string]$Activity, [string]$Status, [Int32]$PercentComplete, [switch]$Completed ){
	
	Write-Progress -activity $Activity -Status $Status -percentComplete $PercentComplete -Completed:$Completed
	
	if ($Verbose){
		LogText ""
	}

	$output = Get-Date -Format HH:mm:ss.ff
	$output += " - "
	$output += $Status
	LogText $output -Color Green
}

function QueryUser([string]$Message, [string]$Prompt, [switch]$AsSecureString = $false, [string]$DefaultValue){
	if ($Message) {
		LogText $Message -color Yellow
	}

	if ($DefaultValue) {
		$Prompt += " (Default [$DefaultValue])"
	}

	$Prompt += ": "
	LogText $Prompt -color Yellow -NoNewLine
	$strResult = Read-Host -AsSecureString:$AsSecureString

	if(!$strResult) {
		$strResult = $DefaultValue
	}

	return $strResult
}

function Get-ConsoleCredential([String] $Message, [String] $DefaultUsername)
{
	$strUsername = QueryUser -Message $Message -Prompt "Username" -DefaultValue $DefaultUsername
	if (!$strUsername){
		return $null
	}

	$strSecurePassword = QueryUser -Prompt "Password" -AsSecureString
	if (!$strSecurePassword){
		return $null
	}

	return new-object Management.Automation.PSCredential $strUsername, $strSecurePassword
}                                                                     
function LogEnvironmentDetails {
	LogText -Color Gray " "
	LogText -Color Gray "   _____         __  __    _____       _     _   _______          _ _    _ _   "
	LogText -Color Gray "  / ____|  /\   |  \/  |  / ____|     | |   | | |__   __|        | | |  (_) |  "
	LogText -Color Gray " | (___   /  \  | \  / | | |  __  ___ | | __| |    | | ___   ___ | | | ___| |_ "
	LogText -Color Gray "  \___ \ / /\ \ | |\/| | | | |_ |/ _ \| |/ _`` |    | |/ _ \ / _ \| | |/ / | __|"
	LogText -Color Gray "  ____) / ____ \| |  | | | |__| | (_) | | (_| |    | | (_) | (_) | |   <| | |_ "
	LogText -Color Gray " |_____/_/    \_\_|  |_|  \_____|\___/|_|\__,_|    |_|\___/ \___/|_|_|\_\_|\__|"
	LogText -Color Gray " "
	LogText -Color Gray " Get-LyncUsers.ps1"
	LogText -Color Gray " "

	$OSDetails = Get-WmiObject Win32_OperatingSystem
	LogText -Color Gray "Computer Name:        $($env:COMPUTERNAME)"
	LogText -Color Gray "User Name:            $($env:USERNAME)@$($env:USERDNSDOMAIN)"
	LogText -Color Gray "Windows Version:      $($OSDetails.Caption)($($OSDetails.Version))"
	LogText -Color Gray "PowerShell Host:      $($host.Version.Major)"
	LogText -Color Gray "PowerShell Version:   $($PSVersionTable.PSVersion)"
	LogText -Color Gray "PowerShell Word size: $($([IntPtr]::size) * 8) bit"
	LogText -Color Gray "CLR Version:          $($PSVersionTable.CLRVersion)"
	LogText -Color Gray "Current Date Time:    $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
	LogText -Color Gray "Username Parameter:   $UserName"
	LogText -Color Gray "Server Parameter:     $LyncServer"
	LogText -Color Gray "Connection Method:    $ConnectionMethod"
	LogText -Color Gray "Output File 1:        $OutputFile1"
	LogText -Color Gray "Log File:             $LogFile"
	LogText -Color Gray ""
}

function EnvironmentConfigured {
	if (Get-Command "Get-CsSite" -errorAction SilentlyContinue){
		return $true
    }
	else {
		return $false
    }
}

function CalculateCAL($bUserStatus, $bStdCAL, $bEntCAL, $bPlusCAL) {
    if (! $bUserStatus) {
        return "No CAL"
    }
    elseif ($bEntCAL -and $bPlusCAL) {
        return "Enterprise Plus CAL"
    }
    elseif ($bEntCAL) {
        return "Enterprise CAL"
    }
    elseif ($bStdCAL -and $bPlusCAL) {
        return "Standard Plus CAL"
    }
    elseif ($bStdCAL) {
        return "Standard CAL"
    }
    elseif ($bPlusCAL) {
        return "Plus CAL"
    }
    else {
        return "No CAL"
    }    
}

function Get-LyncUsers {
	InitialiseLogFile
	LogEnvironmentDetails

	Try {

















        $bAuthenticate = $false
		$currConnectionMethod = ""

        if ($ConnectionMethod -eq "Both" -or $ConnectionMethod -eq "SnapIn") {
            $getModule = Get-Module -ListAvailable -Name Lync

            if($getModule) {
                # Import the specified Module if it exist
                Import-Module Lync -ErrorAction SilentlyContinue -ErrorVariable $errImport
                if (EnvironmentConfigured) {
		            LogProgress -activity "Lync Server - Module" -Status "Loaded Lync module" -percentComplete 10 
                    $bAuthenticate = $true
                    $currConnectionMethod = "SnapIn"
                }
            }
        }
        
        # If ConnectionMethod = Both
        # Check if importing module was successful from SnapIn method. 
        # If not then try the RemoteSession.
        if (!$bAuthenticate -and ( $ConnectionMethod -eq "Both" -or $ConnectionMethod -eq "RemoteSession" ) ) {

			if (!$LyncServer) {
				$LyncServer = QueryUser -Prompt "Lync Server FQDN" -DefaultValue "$($env:computerName).$($env:USERDNSDOMAIN)"
			}

        	# Create the Credentials object if username has been provided
			if(!($UserName -and $Password)){
				$lyncCreds = Get-ConsoleCredential -DefaultUsername $UserName -Message "Lync Server Administrator Credentials Required"
			}
			else 
			{
				$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
				$lyncCreds = New-Object System.Management.Automation.PSCredential ($UserName, $securePassword)
			}

			# URI for the LYNC Server
            $uri = "https://" + $LyncServer + "/OcsPowershell"
			LogProgress -activity "Lync Data Export" -Status "Connecting To Server $uri" -percentComplete 5		
            $session = New-PSSession -ConnectionURI $uri -Credential $lyncCreds -ErrorAction Continue

            if(-not($session)) {
                LogError ("The script was unable to connect to Lync server", 
							"To maximise the chance of connectivity, please",
							"   1) Ensure that the Lync PowerShell Module is installed on this device and/or",
							"   2) Execute this script on the Lync server")
			    Exit
            }
            else {
		        LogProgress -activity "Lync Data Export" -Status "Importing Lync Session" -percentComplete 10    
                
                # Import authenticated session
                $importSession = Import-PsSession $session -AllowClobber
                
                $bAuthenticate = $true
                $currConnectionMethod = "RemoteSession"
            }
	    }
		
        if($bAuthenticate) {
		    LogProgress -activity "Lync Data Export" -Status "Loading Lync users" -percentComplete 12
            $users = Get-CsUser
            if ($Verbose){
		        LogText "User Count: $($users.count)"
            }
		    
            # Load all the policies
            $ConferencePolicies = Get-CsConferencingPolicy
            if ($Verbose){
		        LogText "Conference Policy Count: $($ConferencePolicies.count)"
            }

            $VoicePolicies = Get-CsVoicePolicy     
            if ($Verbose){
		        LogText "Voice Policy Count: $($VoicePolicies.count)"
            }     
          
            foreach ($user in $users) {
                if ($Verbose){
				    LogText "Collecting user data for $($user.UserPrincipalName)"
                }

                $bUserStatus = $false
                $bStdCAL = $false
                $bEntCAL = $false
                $bPlusCAL = $false
                $bVoicePolicy = $false
				
                # Check for Standard CAL requirement
                if ($user.Enabled) {
                    $bUserStatus = $true
                    $bStdCAL = $true
                }
				
				# Check for Enterprise CAL requirement
                if ($user.ConferencingPolicy -ne $null) {

					# Get details of the Conferencing Policy
                    if($currConnectionMethod -eq "SnapIn") {
                        $userConfPolicy = $ConferencePolicies | Where-Object {$_.Identity -eq ("Tag:" + $user.ConferencingPolicy.FriendlyName)}
                    }
                    else {
                        $userConfPolicy = $ConferencePolicies | Where-Object {$_.Identity -eq ("Tag:" + $user.ConferencingPolicy)}
                        #$userConfPolicy = Get-CsConferencingPolicy $user.ConferencingPolicy
                    }

                    if ( ($userConfPolicy.AllowIPAudio -eq $true) -or `
                         ($userConfPolicy.AllowIPVideo -eq $true) -or `
                         ($userConfPolicy.AllowUserToScheduleMeetingsWithAppSharing -eq $true) -or `
                         ($userConfPolicy.EnableDataCollaboration -eq $true) ) {
                        # User needs Enterprise CAL
                        $bEntCAL = $true
                    }
                }

                if ($bEntCAL) {
                    $user | Add-Member -MemberType NoteProperty -Name AllowIPAudio -Value $userConfPolicy.AllowIPAudio
                    $user | Add-Member -MemberType NoteProperty -Name AllowIPVideo -Value $userConfPolicy.AllowIPVideo
                    $user | Add-Member -MemberType NoteProperty -Name AllowUserToScheduleMeetingsWithAppSharing -Value $userConfPolicy.AllowUserToScheduleMeetingsWithAppSharing
                    $user | Add-Member -MemberType NoteProperty -Name EnableDataCollaboration -Value $userConfPolicy.EnableDataCollaboration            
                }
                else {
                    $user | Add-Member -MemberType NoteProperty -Name AllowIPAudio -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name AllowIPVideo -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name AllowUserToScheduleMeetingsWithAppSharing -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableDataCollaboration -Value $false            
                }
											
                # Check for Plus CAL requirement
                if ($user.EnterpriseVoiceEnabled -eq $true) {
                    # If true then the user requires Plus CAL
                    $bPlusCAL = $true
                }
                
                # Check if any Voice Policy exist for the user in Plus CAL
                if ($user.VoicePolicy -ne $null) {
								
                    # Get details of the Voice Policy
                    if($currConnectionMethod -eq "SnapIn") {
                        $userVoicePolicy = $VoicePolicies | Where-Object {$_.Identity -eq ("Tag:" + $user.VoicePolicy.FriendlyName)}
                    }
                    else {
                        $userVoicePolicy = $VoicePolicies | Where-Object {$_.Identity -eq ("Tag:" + $user.VoicePolicy)}
                    }
            
                    $user | Add-Member -MemberType NoteProperty -Name AllowSimulRing -Value $userVoicePolicy.AllowSimulRing
                    $user | Add-Member -MemberType NoteProperty -Name AllowCallForwarding -Value $userVoicePolicy.AllowCallForwarding
                    $user | Add-Member -MemberType NoteProperty -Name AllowPSTNReRouting -Value $userVoicePolicy.AllowPSTNReRouting
                    $user | Add-Member -MemberType NoteProperty -Name EnableDelegation -Value $userVoicePolicy.EnableDelegation
                    $user | Add-Member -MemberType NoteProperty -Name EnableTeamCall -Value $userVoicePolicy.EnableTeamCall
                    $user | Add-Member -MemberType NoteProperty -Name EnableCallTransfer -Value $userVoicePolicy.EnableCallTransfer
                    $user | Add-Member -MemberType NoteProperty -Name EnableCallPark -Value $userVoicePolicy.EnableCallPark
                    $user | Add-Member -MemberType NoteProperty -Name EnableMaliciousCallTracing -Value $userVoicePolicy.EnableMaliciousCallTracing
                    $user | Add-Member -MemberType NoteProperty -Name EnableBWPolicyOverride -Value $userVoicePolicy.EnableBWPolicyOverride
                    $user | Add-Member -MemberType NoteProperty -Name PreventPSTNTollBypass -Value $userVoicePolicy.PreventPSTNTollBypass
                }
                else {
                    $user | Add-Member -MemberType NoteProperty -Name AllowSimulRing -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name AllowCallForwarding -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name AllowPSTNReRouting -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableDelegation -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableTeamCall -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableCallTransfer -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableCallPark -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableMaliciousCallTracing -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name EnableBWPolicyOverride -Value $false
                    $user | Add-Member -MemberType NoteProperty -Name PreventPSTNTollBypass -Value $false
                }
				
                $CAL = CalculateCAL $bUserStatus $bStdCAL $bEntCAL $bPlusCAL

                # Add CAL to CSV    
                $user | Add-Member -MemberType NoteProperty -Name CALRequired -Value $CAL
            }   # End users for loop
    
			LogProgress -activity "Lync Data Export" -Status "Exporting Lync User Data" -percentComplete 95
            $users | Select-Object SamAccountName, UserPrincipalName, FirstName, LastName, `
                WindowsEmailAddress, Sid, LineServerURI, OriginatorSid, AudioVideoDisabled, `
                IPPBXSoftPhoneRoutingEnabled, RemoteCallControlTelephonyEnabled, PrivateLine, `
                HostedVoiceMail, DisplayName, HomeServer, TargetServerIfMoving, EnabledForFederation, `
                EnabledForInternetAccess, PublicNetworkEnabled, EnterpriseVoiceEnabled, EnabledForRichPresence, `
                LineURI, SipAddress, Enabled, TenantId, TargetRegistrarPool, VoicePolicy, MobilityPolicy, `
                ConferencingPolicy, PresencePolicy, RegistrarPool, DialPlan, LocationPolicy, ClientPolicy, `
                ClientVersionPolicy, ArchivingPolicy, PinPolicy, ExternalAccessPolicy, HostedVoicemailPolicy, `
                HostingProvider, Name, DistinguishedName, Identity, Guid, ObjectCategory, `
                WhenChanged, WhenCreated, OriginatingServer, IsValid, ObjectState, AllowIPAudio, AllowIPVideo, `
                AllowUserToScheduleMeetingsWithAppSharing, EnableDataCollaboration, AllowSimulRing, `
                AllowCallForwarding, AllowPSTNReRouting, EnableDelegation, EnableTeamCall, EnableCallTransfer, `
                EnableCallPark, EnableMaliciousCallTracing, EnableBWPolicyOverride, PreventPSTNTollBypass, CALRequired `
                | Export-Csv -NoTypeInformation -Path $OutputFile1 -Encoding UTF8

            # Clear session
            if ($session) { 
                Remove-PsSession $session
            }

		    LogProgress -activity "Lync Data Export" -Status "Lync User Data Exported" -percentComplete 100
        }
        else {
		    LogError ("The script was unable to connect to Lync server", 
						"To maximise the chance of connectivity, please",
						"   1) Ensure that the Lync PowerShell Module is installed on this device and/or",
						"   2) Execute this script on the Lync server") 
        }
	}
    catch {
        # Clear session
        if ($session) { 
            Remove-PsSession $session
        }
		LogLastException
    }
}

# Call the Get-LyncUsers Function to 
#	- Load Account Details
#   - Calculate an approximation on CAL required 
#	- Export CSV
Get-LyncUsers