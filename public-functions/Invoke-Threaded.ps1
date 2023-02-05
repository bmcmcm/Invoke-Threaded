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
        [System.Array[]]$TargetList,        
        
        [Parameter(Mandatory=$false,ParameterSetName='ScriptPath',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='FunctionName',Position=3)]
        [System.Collections.Generic.Dictionary[string,object]]$ParametersToPass = "",
        
        [Parameter(Mandatory=$false,ParameterSetName='ScriptPath',Position=4)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=4)]
        [Parameter(Mandatory=$false,ParameterSetName='FunctionName',Position=4)]
        [ValidateRange(1,1000)]
        [int]$MaxThreads = 8,

        [Parameter(Mandatory=$false,ParameterSetName='ScriptPath',Position=5)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=5)]
        [Parameter(Mandatory=$false,ParameterSetName='FunctionName',Position=5)]
        [ValidateRange(1,10000)]
        [int]$ThreadWaitSleepTimerMs = 200,

        [Parameter(Mandatory=$false,ParameterSetName='ScriptPath',Position=6)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=6)]
        [Parameter(Mandatory=$false,ParameterSetName='FunctionName',Position=6)]
        [ValidateRange(1,86400)]
        [int]$MaxThreadWaitTimeSec = 60, 
        
        [Parameter(Mandatory=$false,ParameterSetName='ScriptPath',Position=7)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=7)]
        [Parameter(Mandatory=$false,ParameterSetName='FunctionName',Position=7)]
        [string]$ImportModulePath = "",

        [Parameter(Mandatory=$false,ParameterSetName='ScriptPath',Position=8)]
        [Parameter(Mandatory=$false,ParameterSetName='ScriptBlock',Position=8)]
        [Parameter(Mandatory=$false,ParameterSetName='FunctionName',Position=8)]
        [string[]]$ImportModules = ""    
    )

    $ScriptToThread = ""
    $CommandToThread = ""

    if ($ScriptFile)
    {
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
        $ScriptToThread = $ScriptBlock
    }

    if ($FunctionName)
    {
        $ScriptToThread = (Get-Command $FunctionName).ScriptBlock
        if (!$ScriptToThread)
        {
            $CommandToThread = Get-Command $FunctionName
            if (!$CommandToThread)
            {
                Write-Error "Function Name supplied not found, unable to continue."
                return $null
            }
        }
    }

    if ($ScriptToThread)
    {
        Invoke-RunspacePool -ScriptBlock $ScriptToThread -TargetList $TargetList -ParametersToPass $ParametersToPass -MaxThreads $MaxThreads -ThreadWaitSleepTimerMs $ThreadWaitSleepTimerMs -MaxThreadWaitTimeSec $MaxThreadWaitTimeSec -ImportModulePath $ImportModulePath -ImportModules $ImportModules
    } else {
        Invoke-RunspacePool -Command $CommandToThread -TargetList $TargetList -ParametersToPass $ParametersToPass -MaxThreads $MaxThreads -ThreadWaitSleepTimerMs $ThreadWaitSleepTimerMs -MaxThreadWaitTimeSec $MaxThreadWaitTimeSec -ImportModulePath $ImportModulePath -ImportModules $ImportModules
    }
}
Export-ModuleMember -Function Invoke-Threaded

