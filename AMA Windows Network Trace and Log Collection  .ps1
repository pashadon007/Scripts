Start-Transcript -Path "$($env:TEMP)\AMA_NetworkTrace_Transcript.log"

# Set vars
$date = Get-Date -Format yyyyMMdd_hhmmss
Write-Host "VAR: date = $date"

$dirName = "AMA_NetworkTrace_$($env:COMPUTERNAME)_$date"
$path = $($env:TEMP + "\" + $dirName)
Write-Host "VAR: path = $path"

$sleepSecondsStartTrace = 15
Write-Host "VAR: sleepSecondsStartTrace = $sleepSecondsStartTrace"

$sleepSecondsTraceDuration = 300
Write-Host "VAR: sleepSecondsTraceDuration = $sleepSecondsTraceDuration"

Write-Host "CREATE: Output directory $path"
New-Item -Path $env:TEMP -Name $dirName -ItemType Directory

# Start the trace
## If heavy network traffic, the default size of 250MB may be too small - add maxsize=2048
Write-Host "START: Trace"
cmd.exe /c "netsh trace start persistent=yes capture=yes tracefile=$path\AMA_NetworkCapture_$date.etl"

# Wait for trace to start
Write-Host "WAIT: $sleepSecondsStartTrace seconds from now ($(Get-Date)) for trace to start"
Start-Sleep -Seconds $sleepSecondsStartTrace

# Flush DNS
Write-Host "START: DNS Flush"
cmd.exe /c "ipconfig /flushdns"

# Get existing processes
Write-Host "GET: AMA Processes"
$processes = Get-Process | Where-Object {$_.ProcessName -In "MonAgentCore","MonAgentHost","MonAgentLauncher","MonAgentManager"}
Write-Host "LIST: AMA Processes"
$processes

# Stop existing processes
Write-Host "STOP: AMA Processes"
$processes | Stop-Process -Force

# Wait for 300 seconds after processes stop (they should automatically restart)
Write-Host "WAIT: $sleepSecondsTraceDuration seconds from now ($(Get-Date)) for agent to startup"
Start-Sleep -Seconds $sleepSecondsTraceDuration

# Get new processes
Write-Host "GET: AMA Processes"
$processes = Get-Process | Where-Object {$_.ProcessName -In "MonAgentCore","MonAgentHost","MonAgentLauncher","MonAgentManager"}
Write-Host "LIST: AMA Processes"
$processes

# Stop the trace
Write-Host "STOP: Trace"
Start-Process -FilePath "c:\windows\system32\netsh.exe" -ArgumentList "trace stop" -Wait

# Collect AMA Logs (post network trace)
$currentVersion = ((Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Azure\HandlerState\" | where Name -like "*AzureMonitorWindowsAgent*" | ForEach-Object {$_ | Get-ItemProperty} | where InstallState -eq "Enabled").PSChildName -split('_'))[1]

$troubleshooterPath = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent\$currentVersion\Troubleshooter"
Set-Location -Path $troubleshooterPath
Start-Process -FilePath $troubleshooterPath\AgentTroubleshooter.exe -ArgumentList "--ama" -Wait

# Stop transcript
Write-Host "STOP: Transcript"
Stop-Transcript

# Move transcript to folder
Write-Host "MOVE: Transcript to $path"
Move-Item -Path "$($env:TEMP)\AMA_NetworkTrace_Transcript.log" -Destination $path 

# Compress folder where traces are placed
Write-Host "COMPRESS: traces to .zip"
Compress-Archive -Path $path -DestinationPath $($path + ".zip")

# Create directory to consolidate logs
New-Item -ItemType Directory -Path $env:TEMP -Name $("logs_ama-net_" + $env:COMPUTERNAME + "_" + $date)
$logsDirectory = Get-Item -Path $($env:TEMP + "\logs_ama-net_" + $env:COMPUTERNAME + "_" + $date)
Write-Host "COMPRESS: create output directory - $logsDirectory"

# Move troubleshooter + netTrace files to consolidated directory
$troubleshooterFile = (Get-ChildItem -Path $troubleshooterPath -Filter "AgentTroubleshooterOutput-*" | Sort-Object LastWriteTime -Descending)[0]
$netTraceFile = (Get-ChildItem -Path $env:TEMP -Filter "AMA_NetworkTrace_*.zip" | Sort-Object LastWriteTime -Descending)[0]
$split = $troubleshooterFile.Name -split "AgentTroubleshooterOutput-"
Write-Host "MOVE: Troubleshooter file to output directory."
Move-Item -Path $troubleshooterFile.FullName -Destination $($logsDirectory.FullName + "\AgentTroubleshooterOutput-" + $env:COMPUTERNAME + "-$split")
Write-Host "MOVE: Network Trace file to output directory."
Move-Item -Path $netTraceFile.FullName -Destination $logsDirectory

# Open Explorer to the path where .zip files exists
Write-Host "OPEN: Output directory - $logsDirectory"
Invoke-Item $logsDirectory


