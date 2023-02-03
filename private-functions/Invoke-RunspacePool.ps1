function Invoke-RunspacePool
{
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    Param(

        [Parameter(Mandatory=$true,ParameterSetName='Command',Position=1)]
        [string]$Command,    
        [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock',Position=1)]
        [string]$ScriptBlock,   

        [Parameter(Mandatory=$true,ParameterSetName='Command',Position=2)]
        [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock',Position=2)]
        [System.Array[]]$TargetList,        
        
        [Parameter(Mandatory=$false,ParameterSetName='Command',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=3)]
        [System.Collections.Generic.Dictionary[string,object]]$ParametersToPass,
        
        [Parameter(Mandatory=$false,ParameterSetName='Command',Position=4)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=4)]
        [ValidateRange(1,1000)]
        [int]$MaxThreads = 8,

        [Parameter(Mandatory=$false,ParameterSetName='Command',Position=5)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=5)]
        [ValidateRange(1,10000)]
        [int]$ThreadWaitSleepTimerMs = 200,

        [Parameter(Mandatory=$false,ParameterSetName='Command',Position=6)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=6)]
        [ValidateRange(1,86400)]
        [int]$MaxThreadWaitTimeSec = 60, 
        
        [Parameter(Mandatory=$false,ParameterSetName='Command',Position=7)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=7)]
        [string]$ImportModulePath = "",

        [Parameter(Mandatory=$false,ParameterSetName='Command',Position=8)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=8)]
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
    foreach ($item in $TargetList)
	{    
        Write-Progress `
            -Activity "$($TargetList.Count) iterations on $($MaxThreads) threads $($Command): $($item)" `
            -PercentComplete ($Threads.count / $TargetList.Count * 100) `
            -Status "Starting $($Threads.count) of $($TargetList.Count)"
        
        if ($Command)
        {  
            if ($ParametersToPass)
            {
                $thread = [powershell]::Create().AddCommand($Command).AddArgument($item).AddParameters($ParametersToPass)
            } else {
                $thread = [powershell]::Create().AddCommand($Command).AddArgument($item)
            }
        }

        if ($ScriptBlock)
        {
            if ($ParametersToPass)
            {
                $thread = [powershell]::Create().AddScript($ScriptBlock).AddArgument($item).AddParameters($ParametersToPass)
            } else {
                $thread = [powershell]::Create().AddScript($ScriptBlock).AddArgument($item)
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
            -Activity "Waiting for threads: $($MaxThreads - $($RunspacePool.GetAvailableRunspaces())) of $MaxThreads threads running" `
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
	$Results 
}