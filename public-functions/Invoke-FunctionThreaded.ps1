<#
.SYNOPSIS
Invokes a function as threaded against a list of function targets. 
.DESCRIPTION
Invoke-FunctionThreaded invokes a supplied function name as threaded against a supplied list of function targets. All parameters needed by the function must be supplied in a specific manner. The output of the invoked function threads will be returned upon completion of all threads as a PSCustomObject array. 
.PARAMETER FunctionName
String name of the function that will be invoked on multiple threads
.PARAMETER FunctionTargetList
String array of target objects that will be iterated into threads. These objects should be the position 1 parameter for the invoked function.
.PARAMETER FunctionParameters
System.Collections.Generic.Dictionary[string,object] disctionary of key,value pairs containing parameter names and values. See example below:

$param = [System.Collections.Generic.Dictionary[string,object]]::new()
$param.Add("Count",1)
translates to "-Count 1" 
.PARAMETER MaxThreads
(Default=8, Min=1, Max=1000) Integer defining the maximum number of threads that will be created. Depending on the particular need, it can be beneficial to run a high number of threads; for example, pinging thousands of addresses where it is expected that most will time out. However, if the invoked function will be doing any sort of lengthy processing, too many threads can cause processing overhead that unnecessarily lengthens the overall processing time. Generally, the number of processor cores available is a good place to start.
.PARAMETER ThreadWaitSleepTimerMs
(Default=200, Min=1, Max=1000000) Integer defining the wait time in milliseconds between polling for thread completion. The default 200 represents polling for individual thread completion 5 times per second.
.PARAMETER MaxThreadWaitTimeSec
(Default=60, Min=1, Max=86400) Integer defining the wait time in seconds that an individual thread (job) will be allowed to run before it is forcably timed out. Take care when setting this parameter, too low of a value will potentially kill a thread before it is possible for it to complete.
.PARAMETER ImportModulePath
String defining the directory path where all modules found will be loaded by each thread session. Do not specify a file, only the root path where the module(s) is/are located.
.PARAMETER ImportModules
String array of module names to import into each thread session. Unlike ImportModulePath, these modules much be available from the default module path(s) for PowerShell ($env:PSModulePath -split ';'). Normally all of the modules in $env:PSModulePath are auto-loaded (so this parameter could be superflous), unless $PSModuleAutoLoadingPreference is set to "None", or "ModuleQualified".
.EXAMPLE
Invoke the Test-Connection function with "-Count 1" against all computer names in $computers:

$computers = Get-ADComputer *
$param = [System.Collections.Generic.Dictionary[string,object]]::new()
$param.Add("Count",1)
Invoke-FunctionThreaded "Test-Connection" $computers.name -FunctionParameters $param -MaxThreads 100 | Out-GridView
.EXAMPLE
Invoke custom function Get-PathStorageUse against all paths in $dirs and import all modules found in the path E:\Powershell\Modules\CalcFiles to each thread's session state:

$dirs = Get-ChildItem -Path "C:\Program Files" -Recurse -Directory
$results = Invoke-FunctionThreaded "Get-PathStorageUse" $dirs -ImportModulePath "E:\Powershell\Modules\CalcFiles" 
#>
function Invoke-FunctionThreaded
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)]
        [string]$FunctionName,

        [Parameter(Mandatory=$false,Position=2)]
        [string[]]$FunctionTargetList,        

        [Parameter(Mandatory=$false,Position=3)]
        [System.Collections.Generic.Dictionary[string,object]]$FunctionParameters,

        [Parameter(Mandatory=$false,Position=4)]
        [ValidateRange(1,1000)]
        [int]$MaxThreads = 8,

        [Parameter(Mandatory=$false,Position=5)]
        [ValidateRange(1,1000000)]
        [int]$ThreadWaitSleepTimerMs = 200,

        [Parameter(Mandatory=$false,Position=6)]
        [ValidateRange(1,86400)]
        [int]$MaxThreadWaitTimeSec = 60, 

        [Parameter(Mandatory=$false,Position=7)]
        [string]$ImportModulePath = "",

        [Parameter(Mandatory=$false,Position=8)]
        [string[]]$ImportModules = ""
    )

    if ($MaxThreadWaitTimeSec -lt 10)
    {
        Write-Warning "MaxThreadWaitTimeSec is set below 10 seconds, for some situations this can prematurely kill a thread."
    }
    $timeStart = Get-Date
    Write-Verbose "Invocation Start: $timeStart"
	
    $ISS = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
    if ($ImportModulePath -and (Test-Path -Path $ImportModulePath))
    {
        Write-Verbose "Importing $ImportModulePath to initial session state"
        $ISS.ImportPSModulesFromPath($ImportModulePath)
    }
    if ($ImportModules)
    {
        Write-Verbose "Importing $ImportModules to initial session state"
        $ISS.ImportPSModule($ImportModules)
    }
    Write-Verbose "Creating RunspacePool with $($MaxThreads) threads"
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads, $ISS, $host)
    $RunspacePool.Open()

    $Threads = @()
    $errorList = @()
    foreach ($item in $FunctionTargetList)
	{    
        Write-Progress `
            -Activity "$($FunctionTargetList.Count) iterationss on $($MaxThreads) threads $($FunctionName): $($item)" `
            -PercentComplete ($Threads.count / $FunctionTargetList.Count * 100) `
            -Status "Starting Job $($Threads.count) of $($FunctionTargetList.Count)"
        
        if ($FunctionParameters)
        {
            $thread = [powershell]::Create().AddCommand($FunctionName).AddArgument($item).AddParameters($FunctionParameters)
        } else {
            $thread = [powershell]::Create().AddCommand($FunctionName).AddArgument($item)
        }
        $thread.RunspacePool = $RunspacePool
		try
		{
        	$handle = $thread.BeginInvoke()
		}
		catch
		{
			Write-Error "Error caught during thread invocation, added to error list, will be dumped later"
			$errorList += [system.exception]
		}
		finally
		{
        	$row = "" | Select-Object Handle,Thread
        	$row.Handle = $handle
        	$row.Thread = $thread
        	$Threads += $row
		}
    }
    if ($errorList)
    {
        Write-Host "These errors were caught during thread invocations:" -ForegroundColor Magenta -BackgroundColor Yellow
        foreach ($err in $errorList)
        {
            Write-Error $err
        }
    }  
    Write-Verbose "All threads have been invoked, job now waiting on thread completions"
	$JobResults = @()
    $timeOutCheck = "" | Select-Object ID,FirstCheckTime
    $timeOutCheck.FirstCheckTime = Get-Date
    $Threads = $Threads | Sort-Object -Property {$_.thread.InstanceId}
    while (($Threads | Where-Object {$_.Handle}).Count -gt 0)  
	{    
        $Remaining = "$($Threads | Where-Object {$_.Handle.IsCompleted -eq $false})"
        if ($Remaining.Length -gt 60) { $Remaining = $Remaining.Substring(0,60) + "..." }
        Write-Progress `
            -Activity "Waiting for Threads: $($MaxThreads - $($RunspacePool.GetAvailableRunspaces())) of $MaxThreads threads running" `
            -PercentComplete (($Threads.count - $($($Threads | Where-Object {$_.Handle.IsCompleted -eq $false}).count)) / $Threads.Count * 100) `
            -Status "$(@($($Threads | Where-Object {$_.Handle.IsCompleted -eq $false})).count) remaining - $remaining" 
 
        foreach ($thread in $($Threads | Where-Object {$_.Handle.IsCompleted -eq $true}))
		{
            $JobResults += $thread.Thread.EndInvoke($thread.Handle)
            $thread.Thread.Dispose() | Out-Null
            $thread.Thread = $null
            $thread.Handle = $null
        }
        $waiting = $Threads | Where-Object {$_.Handle.IsCompleted -eq $false} 
        if ($waiting.Count -gt 1) {$waiting = $waiting[0]}
        if ($waiting.thread.InstanceId -eq $timeOutCheck.ID)
        {
            if (($(Get-Date) - $timeOutCheck.FirstCheckTime).TotalSeconds -gt $MaxThreadWaitTimeSec)
            {
                Write-Warning "Max runtime of $($MaxThreadWaitTimeSec) seconds exceeded for thread InstanceId $($timeOutCheck.ID), it will be disposed"
                $waiting.Thread.Dispose() | Out-Null
                $waiting.Thread = $null
                $waiting.Handle = $null                
            }
        } else {
            Write-Verbose "Setting Timeout Check ID: $($waiting.thread.InstanceId)"
            $timeOutCheck.ID = $waiting.thread.InstanceId
            $timeOutCheck.FirstCheckTime = Get-Date
        }
        if (($Threads | Where-Object {$_.Handle}).Count -gt 0) {Start-Sleep -Milliseconds $ThreadWaitSleepTimerMs}   
    }
    Write-Verbose "All thread results received or timed out, RunspacePool will be disposed"
    $RunspacePool.Close() | Out-Null
    $RunspacePool.Dispose() | Out-Null
	$timeEnd = Get-Date
    Write-Verbose "Invocation End  : $timeEnd"
    Write-Verbose "Elapsed Time    = $(New-TimeSpan -Start $timeStart -End $timeEnd)"
	$JobResults 
}
