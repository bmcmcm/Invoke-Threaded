<#
.SYNOPSIS
Invokes a PowerShell script file, scriptblock, or commandlet/function name as threaded against a list of targets. 
.DESCRIPTION
Invoke-Threaded invokes a supplied script file, scriptblock, or commandlet/function name as threaded against a supplied list of targets. A parameter set is used to differentiate between the three use cases. In addition to a script file, scriptblock, or commandlet/function name, an array of target objects to thread against must be passed; these objected will be used as the default arguement for the script or commandlet/function. Optionally, additional parameters for the script or commandlet/function may be supplied, as well as modules that would be required to import to each thread session (this is for a use case where the module is not already installed in default PowerShell sessions on the host).

.PARAMETER ScriptFile
String containing the filename and a path of a .ps1 file to be invoked on multiple threads
.PARAMETER ScriptBlock
String containing a scriptblock to be invoked on multiple threads.
.PARAMETER FunctionName
String name of the commandlet/function that will be invoked on multiple threads. If the function is local to the script calling Invoke-Threaded, it will be invoked as a scriptblock, otherwise it will be invoked as a command.
.PARAMETER TargetList
Array of target objects that will be iterated into threads. The objects in the array must be accepted as the first (default) argument for the supplied script or commandlet/function.
.PARAMETER ParametersToPass
System.Collections.Generic.Dictionary[string,object] dictionary of key,value pairs containing parameter names and values that will be passed to each iteration of the supplied script or commandlet/function. 
.PARAMETER MaxThreads
(Default=8, Min=1, Max=1000) Integer defining the maximum number of threads that will be created. Depending on the particular need, it can be beneficial to run a high number of threads; for example, pinging thousands of addresses where it is expected that most will time out. However, if the invoked function will be doing any sort of lengthy processing, too many threads can cause processing overhead that unnecessarily lengthens the overall processing time. Generally, the number of processor cores available is a good place to start.
.PARAMETER ThreadWaitSleepTimerMs
(Default=200, Min=1, Max=1000000) Integer defining the wait time in milliseconds between polling for thread completion. The default 200 represents polling for individual thread completion 5 times per second.
.PARAMETER MaxThreadWaitTimeSec
(Default=60, Min=1, Max=86400) Integer defining the wait time in seconds that an individual thread will be allowed to run before it is forcably timed out. Take care when setting this parameter, too low of a value will potentially kill a thread before it is possible for the thread to complete.
.PARAMETER ImportModulePath
String defining the directory path where ALL modules found will be loaded by each thread session. Do not specify a filename, only the root path where the module(s) is/are located.
.PARAMETER ImportModules
String array of module names to import into each thread session. Unlike ImportModulePath, these modules much be available from the default module path(s) for PowerShell ($env:PSModulePath -split ';'). Normally all of the modules in $env:PSModulePath are auto-loaded (so this parameter could be superflous), unless $PSModuleAutoLoadingPreference is set to "None", or "ModuleQualified".

.INPUTS
Any whole list/array ocontaining the target list of objects to iterate into threads may pipelined to Invoke-Threaded
.OUTPUTS
Invoke-Threaded output depends on the supplied script, scriptblock, or commandlet/function. The output will be an array of whatever each thread returns.

.EXAMPLE
Invoke C:\Scripts\Test.ps1 against computer names in returned from Get-ADComputer:

$scriptfile = "C:\Scripts\Test.ps1" 
$computers = (Get-ADComputer -Filter *).Name
Invoke-ScriptThreaded -ScriptFile $scriptfile -TargetList $computers

This would also be acceptable:

$scriptfile = "C:\Scripts\Test.ps1" 
(Get-ADComputer -Filter *).Name | Invoke-ScriptThreaded -ScriptFile $scriptfile

.EXAMPLE
Invoke the Test-Connection function with "-Count 1" against computer names returned from Get-ADComputer:

$computers = (Get-ADComputer -Filter *).Name
$param = [System.Collections.Generic.Dictionary[string,object]]::new()
$param.Add("Count",1)
Invoke-Threaded -FunctionName "Test-Connection" $computers -ParametersToPass $param -MaxThreads 100 | Out-GridView

This would also be acceptable:

$param = [System.Collections.Generic.Dictionary[string,object]]::new()
$param.Add("Count",1)
(Get-ADComputer -Filter *).Name | Invoke-Threaded -FunctionName "Test-Connection" -ParametersToPass $param -MaxThreads 100 | Out-GridView

.EXAMPLE
Invoke custom function Get-PathStorageUse against all paths in $dirs and import all modules found in the path E:\Powershell\Modules\CalcFiles to each thread's session state:

$dirs = Get-ChildItem -Path "C:\Program Files" -Recurse -Directory
$results = Invoke-PublicFunctionThreaded "Get-PathStorageUse" $dirs -ImportModulePath "E:\Powershell\Modules\CalcFiles" 
#>

function Invoke-Threaded
{
    [CmdletBinding(DefaultParameterSetName = 'ScriptPath')]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName='ScriptPath',Position=1)]
        [string]$ScriptFile,
        [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock',Position=1)]
        [string]$ScriptBlock,
        [Parameter(Mandatory=$true,ParameterSetName='FunctionName',Position=1)]
        [string]$FunctionName,
        
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='ScriptPath',Position=2)]
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='ScriptBlock',Position=2)]
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='FunctionName',Position=2)]
        [System.Array]$TargetList,        
        
        [Parameter(ParameterSetName='ScriptPath',Position=3)]
        [Parameter(ParameterSetName='ScriptBlock',Position=3)]
        [Parameter(ParameterSetName='FunctionName',Position=3)]
        [System.Collections.Generic.Dictionary[string,object]]$ParametersToPass = $null,
        
        [Parameter(ParameterSetName='ScriptPath',Position=4)]
        [Parameter(ParameterSetName='ScriptBlock',Position=4)]
        [Parameter(ParameterSetName='FunctionName',Position=4)]
        [ValidateRange(1,1000)]
        [int]$MaxThreads = 8,

        [Parameter(ParameterSetName='ScriptPath',Position=5)]
        [Parameter(ParameterSetName='ScriptBlock',Position=5)]
        [Parameter(ParameterSetName='FunctionName',Position=5)]
        [ValidateRange(1,10000)]
        [int]$ThreadWaitSleepTimerMs = 200,

        [Parameter(ParameterSetName='ScriptPath',Position=6)]
        [Parameter(ParameterSetName='ScriptBlock',Position=6)]
        [Parameter(ParameterSetName='FunctionName',Position=6)]
        [ValidateRange(1,86400)]
        [int]$MaxThreadWaitTimeSec = 60, 
        
        [Parameter(ParameterSetName='ScriptPath',Position=7)]
        [Parameter(ParameterSetName='ScriptBlock',Position=7)]
        [Parameter(ParameterSetName='FunctionName',Position=7)]
        [string]$ImportModulePath = "",

        [Parameter(ParameterSetName='ScriptPath',Position=8)]
        [Parameter(ParameterSetName='ScriptBlock',Position=8)]
        [Parameter(ParameterSetName='FunctionName',Position=8)]
        [string[]]$ImportModules = ""    
    )

    $ScriptToThread = ""
    $CommandToThread = ""
    $InvokeType = ""
    if ($ScriptFile)
    {
        $InvokeType = "Script File"
        $OFS = "`r`n"
        $ScriptToThread = [ScriptBlock]::Create($(Get-Content $ScriptFile))
        Remove-Variable OFS
        if (!$ScriptToThread)
        {
            Write-Error -Message "Script file was not read, unable to continue."
            return $null
        }
    }

    if ($ScriptBlock)
    {
        $InvokeType = "Script Block"
        $ScriptToThread = $ScriptBlock
    }

    if ($FunctionName)
    {
        $InvokeType = "Commandlet/Function"
        $CommandToThread = Get-Command $FunctionName
        if (!$CommandToThread)
        {
            Write-Error "Commandlet/Function Name supplied not found, unable to continue."
            return $null
        }
    }

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
    foreach ($item in $TargetList)
	{    
        Write-Progress `
            -Activity "$($TargetList.Count) iterations on $($MaxThreads) threads $($Command): $($item)" `
            -PercentComplete ($Threads.count / $TargetList.Count * 100) `
            -Status "Starting $($Threads.count) of $($TargetList.Count)"

        if ($ScriptToThread)
        {

            if ($ParametersToPass)
            {
                $thread = [powershell]::Create().AddScript($ScriptToThread).AddArgument($item).AddParameters($ParametersToPass)
            } else {
                $thread = [powershell]::Create().AddScript($ScriptToThread).AddArgument($item)
            }

        } else {

            if ($ParametersToPass)
            {
                $thread = [powershell]::Create().AddCommand($Command).AddArgument($item).AddParameters($ParametersToPass)
            } else {
                $thread = [powershell]::Create().AddCommand($Command).AddArgument($item)
            }

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
    Write-Verbose "All threads have been invoked, waiting on thread completions"
	$Results = @()
    $timeOutCheck = "" | Select-Object ID,FirstCheckTime
    $timeOutCheck.FirstCheckTime = Get-Date
    $Threads = $Threads | Sort-Object -Property {$_.thread.InstanceId}
    while (($Threads | Where-Object {$_.Handle}).Count -gt 0)  
	{    
        $Remaining = "$($Threads | Where-Object {$_.Handle.IsCompleted -eq $false})"
        if ($Remaining.Length -gt 60) { $Remaining = $Remaining.Substring(0,60) + "..." }
        Write-Progress `
            -Activity "Executing $InvokeType threads: $($MaxThreads - $($RunspacePool.GetAvailableRunspaces())) of $MaxThreads threads active" `
            -PercentComplete (($Threads.count - $($($Threads | Where-Object {$_.Handle.IsCompleted -eq $false}).count)) / $Threads.Count * 100) `
            -Status "$(@($($Threads | Where-Object {$_.Handle.IsCompleted -eq $false})).count) threads remaining - $remaining" 
 
        foreach ($thread in $($Threads | Where-Object {$_.Handle.IsCompleted -eq $true}))
		{
            $Results += $thread.thread.EndInvoke($thread.Handle)
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
    return $Results 
}





Export-ModuleMember -Function Invoke-Threaded

