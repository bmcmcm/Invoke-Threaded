# Invoke-Threaded
The Invoke-Threaded module contains a PowerShell function for invoking a script file (.ps1), scriptblock, or commandlet/function as threads against an array of supplied 'target objects' and then returning the collective results. Invoke-Threaded function works in PowerShell Core or Windows PowerShell. The Invoke-Threaded function isn't more powerful than For-EachObject with -Parallel, however it may add some flexibility (although For-EachObject -Parallel is not even available in Windows PowerShell).

The function or script being invoked must accept the objects from the array of supplied target object as the first (or default) argument. Additional parameters may be supplied as required via [System.Collections.Generic.Dictionary[string,object]], where they will be passed to the script file (.ps1), scriptblock, or commandlet/function as added parameters.

The loading of modules per thread session state is a supported parameter option, if required. This would be a situation where the commandlet/function is not available by default to a new PowerShell session on the host (e.g. A custom PowerShell module that exists on the host, but is not currently installed on the host).

The Invoke-Threaded functions require that the commandlet/funtion or script being invoked is thread-safe. The Invoke-Threaded will return an array of whatever is returned by a single execution of the supplied script file (.ps1), scriptblock, or commandlet/function. Therefore, it is best if the function or script being invoked will always return the same format of data no matter what happens in the function or script, otherwise jagged results may be returned. Invoke-Threaded function returns a result object upon completion of all thread operations, not an object per thread as the threads complete. Threads that fail due to a timeout will return null, thus completeness is not guaranteed.

# Examples:

### Invoke-Threaded With A Commandlet

In this example, Test-Connection is iterated against all of the computer names, via 100 threads. The $param variable simply adds "-Count 1" to Test-Connection so that only one ping is made. Assuming there are 1000 computers and 50% of the computer names timed out on a Test-Connection, this will iterate through the computer pings many times faster than a serial foreach.

```
#Get all computers in the domain
$computers = (Get-ADComputer -Filter *).Name

#Use a generic dictionary to supply additional parameters
$param = [System.Collections.Generic.Dictionary[string,object]]::new()
   
#repeat .Add as many times as necessary to add all parameters
$param.Add("Count",1)

#Invokes Test-Connection against the computer names collected, adding function parameters, and altering MaxThreads to 100
$computers | Invoke-FunctionThreaded "Test-Connection" -ParametersToPass $param -MaxThreads 100 | Out-GridView
```

### Invoke-Threaded With A Script File

In this example, test.ps1 is iterated against all of the computer names, via 8 threads (the default number). Note that test.ps1 is hypothetically a script takes in one parameter from the pipeline and returns a consistent result. In this example, the output of anything returned from test.ps1 is stored in $results.

```
#Hypothetical thread-safe script file called test.ps1:
Param(
    [Parameter(Mandatory=$true,ValueFromPipeline = $true)]
    [string]$ComputerName,
    [Parameter(Mandatory=$false,ValueFromPipeline = $false)]
    [string]$Count = 1
    )

return Test-Connection -ComputerName $ComputerName -Count $Count
```

```
#Invoke test.ps1 against all computers found in Active Directory
$script = "C:\Scripts\test.ps1"

#Get all computers in the domain
$computers = Get-ADComputer -Filter *

$param = [System.Collections.Generic.Dictionary[string,object]]::new()
$param.Add("Count",1)

#Invoke test.ps1 against the computer names collected
$results = Invoke-Threaded -ScriptFile $script -TargetList $computers.name -ParametersToPass $param
$results | Out-GridView
```

### Revised $test.ps1 example
What if the computer name wasn't resolvable in the test.ps1 example above? Either the results would be inconsistent with an error message in the middle of formatted results, or the result would be null, returning nothing per failure. In either case, it wouldn't be clear which computer name failed. This problem can be avoided if the target script is written to handle such issues. For example, the script below returns the successes and failures, creating a much better chance for completeness:

```
Param(
    [Parameter(Mandatory=$true,ValueFromPipeline = $true)]
    [string]$ComputerName,
    [Parameter(Mandatory=$false,ValueFromPipeline = $false)]
    [string]$Count = 1
    )

$returnResult = "" | Select-Object TargetName,TargetIPV4,PingTime
$returnResult.TargetName = $ComputerName
try  
{  
   $result = Test-Connection -ComputerName $ComputerName -Count $Count
   $returnResult.TargetIPV4 = $result.IPV4Address
   $returnResult.PingTime = $result.ResponseTime
}
catch
{
   $returnResult.TargetIPV4 = "Failed"
   $returnResult.PingTime = "N/A"
}
return $returnResult
```
