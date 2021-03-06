﻿function Get-ADSITokenGroup
{
<#
.SYNOPSIS
    Retrieve the list of group present in the tokengroups of a user or computer object.

.DESCRIPTION
    Retrieve the list of group present in the tokengroups of a user or computer object.

    TokenGroups attribute
    https://msdn.microsoft.com/en-us/library/ms680275%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396

.PARAMETER SamAccountName
    Specifies the SamAccountName to retrieve

.PARAMETER Credential
    Specifies Credential to use

.PARAMETER DomainDistinguishedName
    Specify the Domain or Domain DN path to use

.PARAMETER SizeLimit
    Specify the number of item maximum to retrieve

.EXAMPLE
    Get-ADSITokenGroup -SamAccountName 'testaccount'

    Retrieve the list of groups present in the TokenGroups for the user 'testaccount'

.NOTES
    https://github.com/lazywinadmin/ADSIPS

#>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        [Alias('UserName', 'Identity')]
        [String]$SamAccountName,

        [Alias("RunAs")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Alias('DomainDN', 'Domain')]
        [String]$DomainDistinguishedName = $(([adsisearcher]"").Searchroot.path),

        [Alias('ResultLimit', 'Limit')]
        [int]$SizeLimit = '100'
    )

    process
    {
        try
        {
            # Building the basic search object with some parameters
            $Search = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ErrorAction 'Stop'
            $Search.SizeLimit = $SizeLimit
            $Search.SearchRoot = $DomainDN
            #$Search.Filter = "(&(anr=$SamAccountName))"
            $Search.Filter = "(&((objectclass=user)(samaccountname=$SamAccountName)))"

            # Credential
            if ($PSBoundParameters['Credential'])
            {
                $Cred = New-Object -TypeName System.DirectoryServices.DirectoryEntry -ArgumentList $DomainDistinguishedName, $($Credential.UserName), $($Credential.GetNetworkCredential().password)
                $Search.SearchRoot = $Cred
            }

            # Different Domain
            if ($DomainDistinguishedName)
            {
                if ($DomainDistinguishedName -notlike "LDAP://*")
                {
                    $DomainDistinguishedName = "LDAP://$DomainDistinguishedName"
                }#if
                Write-Verbose -Message "[PROCESS] Different Domain specified: $DomainDistinguishedName"
                $Search.SearchRoot = $DomainDistinguishedName
            }

            foreach ($Account in $Search.FindAll())
            {

                $AccountGetDirectory = $Account.GetDirectoryEntry();

                # Add the properties tokenGroups
                $AccountGetDirectory.GetInfoEx(@("tokenGroups"), 0)


                foreach ($Token in $($AccountGetDirectory.Get("tokenGroups")))
                {
                    # Create SecurityIdentifier to translate into group name
                    $Principal = New-Object -TypeName System.Security.Principal.SecurityIdentifier($token, 0)

                    # Prepare Output
                    $Properties = @{
                        SamAccountName = $Account.properties.samaccountname -as [string]
                        GroupName      = $principal.Translate([System.Security.Principal.NTAccount])
                    }

                    # Output Information
                    New-Object -TypeName PSObject -Property $Properties
                }
            }

        }

        catch
        {
            $pscmdlet.ThrowTerminatingError($_)
        }
    }#process
    end
    {
        Write-Verbose -Message "[END] Function Get-ADSITokenGroup End."
    }
}#Function