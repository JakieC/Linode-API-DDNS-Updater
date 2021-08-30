function createConfigFile {
    param(
        $configPath
    )
    
    Read-Host
    Clear-Host   
    $host.ui.RawUI.WindowTitle = "Setting Up API Domain Updater"
    # Get Linode API token
    $loop = "y"
    while ($loop -eq "y") {
        $userInputData = Read-Host -Prompt 'Please enter you API token'
        $token = $userInputData.Trim()

        try {
            $domainListResult = Invoke-RestMethod -Uri https://api.linode.com/v4/domains -Headers  @{ Authorization="Bearer $token"}
        }
        catch {
            Clear-Host
            Write-Host "Incorrect token or web API error" -ForegroundColor Red
            $domainListResult = ""
        }
        
        if ($domainListResult) {
            $loop = "n"
        }
        else{
            
        }
    }

    # Get domain ID
    Clear-Host
    $loop = "y"
    while ($loop -eq "y") {
        Write-Host "Token:" $token -ForegroundColor Yellow
        Write-Host ($domainListResult.data | Format-Table | Out-String)
        $userInputData = Read-Host -Prompt 'Please the enter domain'
        $domainSelected = $domainListResult.data | Where-Object domain -in $userInputData.Trim()

        if ($domainSelected) {
            $loop = "n"
        }
        else{
            Clear-Host
            Write-Host "Please enter the correct domain." -ForegroundColor Red
        }
    }

    # Get domain record ID
    Clear-Host
    $domainId = $domainSelected.id
    $domainRecordsListResult = Invoke-RestMethod -Uri  https://api.linode.com/v4/domains/$domainId/records -Headers  @{ Authorization="Bearer $token"}
    $loop = "y"
    while ($loop -eq "y") {
        Write-Host "Token:" $token "`nDomain ID:" $domainSelected.id "(" $domainSelected.domain ")" -ForegroundColor Yellow
        Write-Host ($domainRecordsListResult.data | Where-Object type -in "A" | Format-Table | Out-String)
        $userInputData = Read-Host -Prompt 'Please enter the sub domain name or leave empty for root domain'
        $domainRecordsSelected = $domainRecordsListResult.data | Where-Object type -in "A" | Where-Object name -in $userInputData.Trim()

        if ($domainRecordsSelected) {
            $loop = "n"
        }
        else{
            Clear-Host
            Write-Host "Please enter the correct sub domain name." -ForegroundColor Red
        }
    }

    # Ask need IPv6 or IPv4 only
    Clear-Host
    Write-Host "Token:" $token "`nDomain ID:" $domainSelected.id "(" $domainSelected.domain ")" "`nRecord ID ( IPv4 ):" $domainRecordsSelected.id "(" $domainRecordsSelected.name ")"-ForegroundColor Yellow
    $loop = "y"
    while ($loop -eq "y") {
        $userInputData = Read-Host -Prompt "Do you want to update AAAA record (IPv6) ? [y/n]" 
        $ipv6 = $userInputData.Trim().ToLower()
        if (($ipv6 -eq "y") -or ($ipv6 -eq "n")) {
            $loop = "n"
        }
        else{
            Clear-Host
        }
    }

    # IF IPv6 is Y then get domain AAAA record ID (ipv6)
    if ($ipv6 -eq "y") {
        Clear-Host
        $loop = "y"
        while ($loop -eq "y") {
            Write-Host "Token:" $token "`nDomain ID:" $domainSelected.id "(" $domainSelected.domain ")" "`nRecord ID ( IPv4 ):" $domainRecordsSelected.id "(" $domainRecordsSelected.name ")"-ForegroundColor Yellow
            Write-Host ($domainRecordsListResult.data | Where-Object type -in "AAAA" | Format-Table | Out-String)
            $userInputData = Read-Host -Prompt 'Please enter the sub domain name or leave empty for root domain' 
            $AAAAdomainRecordsSelected = $domainRecordsListResult.data | Where-Object type -in "AAAA" | Where-Object name -in $userInputData.Trim()

            if ($AAAAdomainRecordsSelected) {
                $loop = "n"
            }
            else{
                Clear-Host
                Write-Host "Please enter the correct sub domain name." -ForegroundColor Red
            }
        }
    }

    # Generate object for config file
    Clear-Host
    $recordId = $domainRecordsSelected.id
    $recordIdIPv6 = $AAAAdomainRecordsSelected.id
    $config = @{
        token = $token
        domainId = $domainId
        recordId = $recordId
        ipv6 = $ipv6
        recordIdIPv6 = $recordIdIPv6
    } 

    # Conver to json and save it
    $config | ConvertTo-Json | Out-File -FilePath $configPath
    Write-Host "Configuration file created"
    Write-Host "Token:" $token "`nDomain ID:" $domainSelected.id "(" $domainSelected.domain ")" "`nRecord ID ( IPv4 ):" $domainRecordsSelected.id "(" $domainRecordsSelected.name ")" "`nRecord ID ( IPv6 ):" $AAAAdomainRecordsSelected.id "(" $AAAAdomainRecordsSelected.name ")" "`nUpdate IPv6:" $ipv6 "`n" -ForegroundColor Yellow
    Write-Host -NoNewline -Object 'Ready to run domain updater, press any key to continue...' 
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function updateDomain {
    param (
        $configPath,
        $logPath
    )

    $host.ui.RawUI.WindowTitle = "Running API Domain Updater"
    #read config.json
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    $token = $config.token
    $domainId = $config.domainId
    $recordId = $config.recordId
    $ipv6 = $config.ipv6.ToLower()
    $recordIdIPv6 = $config.recordIdIPv6
    $log = Get-Date -Format "dd/MM/yyyy HH:mm K"

    # Get Domain IPv4
    try {
        $DomainRecordInfoIpv4 = Invoke-RestMethod -Uri  https://api.linode.com/v4/domains/$domainId/records/$recordId -Headers  @{ Authorization="Bearer $token"}
    }
    catch {
        $log = $log + " Invalid configuration or web API error !"
        Write-Host $log
        $log | Add-Content -Path $logPath
        exit
    }
    $domainIpv4 = $DomainRecordInfoIpv4.target
    
    # Get public IPv4
    try {
        $publicIpv4Result = Invoke-RestMethod -Uri  http://ipv4.icanhazip.com/
    }
    catch {
        $log = $log + " Get public IPv4 fail !"
        Write-Host $log
        $log | Add-Content -Path $logPath
        exit
    }    
    $publicIpv4 = $publicIpv4Result.Trim() 
    $log = $log + " IPv4: "
    
    # Compare Domain and public IPv4
    if ($domainIpv4 -eq $publicIpv4){
        $log = $log + "No need to update"
    }
    else {
        $log = $log + $publicIpv4
        $bodyJson = @{"target"="$publicIpv4"} | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri https://api.linode.com/v4/domains/$domainId/records/$recordId -Method PUT -ContentType "application/json" -Headers @{ Authorization="Bearer $token"} -Body $bodyJson           
        }
        catch {
            $log = $log + " Update Fail !"
        }
    }

    # check ipv6 update option
    if ($ipv6 -eq "y"){
        # GetDomain IP
        try {
            $DomainRecordInfoIpv6 = Invoke-RestMethod -Uri  https://api.linode.com/v4/domains/$domainId/records/$recordIdIPv6 -Headers  @{ Authorization="Bearer $token"}
        }
        catch {
            $log = $log + "; Invalid recordIdIPv6 !"
            Write-Host $log
            $log | Add-Content -Path $logPath
        exit
        }
        $domainIpv6 = $DomainRecordInfoIpv6.target

        # Get public IPv6
        try {
            $publicIpv6Result = Invoke-RestMethod -Uri  http://ipv6.icanhazip.com/
        }
        catch {
            $log = $log + "; Get public IPv6 fail !"
            Write-Host $log
            $log | Add-Content -Path $logPath
            exit
        }
        
        $publicIpv6 = $publicIpv6Result.Trim()
        $log = $log + "; IPv6: "

        # Compare Domain and public IPv6
        if ($domainIpv6 -eq $publicIpv6){
            $log = $log + "No need to update"
        }
        else {
            $log = $log + $publicIpv6
            $bodyJson = @{"target"="$publicIpv6"} | ConvertTo-Json
            try {
                Invoke-RestMethod -Uri https://api.linode.com/v4/domains/$domainId/records/$recordIdIPv6 -Method PUT -ContentType "application/json" -Headers @{ Authorization="Bearer $token"} -Body $bodyJson
            }
            catch {
                $log = $log + " Update Fail !"
            }
        }
    }

    Write-Host $log
    $log | Add-Content -Path $logPath
}

# Avoid Invoke-WebRequest could not create SSL/TLS secure channel error.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

# Check config.json exist
$configPath = $PSScriptRoot + "\config.json"
$logPath = $PSScriptRoot + "\log.txt"
if (Test-Path -Path $configPath -PathType Leaf){
    updateDomain -configPath $configPath -logPath $logPath
}
else {
    $counter = 0
    Write-Host "Configuration file no found !" -ForegroundColor Red
    Write-Host "Press any key within 10 seconds to create new configuration file..."
    while(!$Host.UI.RawUI.KeyAvailable -and ($counter++ -lt 10))
    {
        [Threading.Thread]::Sleep( 1000 )
        if ($counter -eq 10){
                (Get-Date -Format "dd/MM/yyyy HH:mm K") + " Configuration file no found !" | Add-Content -Path $logPath
                exit
        }
    }
    createConfigFile -configPath $configPath
    Clear-Host
    updateDomain -configPath $configPath -logPath $logPath
}