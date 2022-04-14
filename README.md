# Invoke-Threaded
The Invoke-Threaded module contains two PowerShell functions for invoking functions or scripts as threads and returning the results. Invoke-Threaded functions work in PowerShell Core or Windows PowerShell. The Invoke-Threaded functions aren't more powerful than For-EachObject with -Parallel, however they may add some flexibility. Foreach-Object -Parallel is not available in Windows PowerShell, it is only available in PowerShell Core.

Invoke-Threaded is a module with two utility functions for invoking scripts or functions as threads. The function or script being invoked must accept argument 1 as the 'target' of the iteration. Additional parameters may be supplied as required. The loading of modules per thread session state is a supported parameter option, if required.

The Invoke-Threaded functions require that the function/commandlet or script being invoked is thread-safe. The Invoke-Threaded functions will return what ever is returned by the function or thread. Therefore, it is best if the function or script being invoked will always return the same format of data no matter what happens in the function or script, otherwise jagged results may be returned. The Invoke-Threaded functions return a result object upon completion of all thread operations, not as the individual threads return results.

# Examples:

### Invoke-FunctionThreaded

In this example, Test-Connection is iterated against all of the computer names, via 100 threads. The $param variable simply adds "-Count 1" to Test-Connection so that only one ping is made. Assuming there are 1000 computers and 50% of the computer names timed out on a Test-Connection, this will iterate through the computer pings many times faster than a serial foreach.

```
#Get all computers in the domain
$computers = Get-ADComputer -Filter *

#Use a generic dictionary to supply additional parameters
$param = [System.Collections.Generic.Dictionary[string,object]]::new()
   
#repeat .Add as many times as nessessary to add all parameters
$param.Add("Count",1)

#Invokes Test-Connection against the computer names collected, adding function parameters, and altering MaxThreads to 100
Invoke-FunctionThreaded "Test-Connection" $computers.name -FunctionParameters $param -MaxThreads 100 | Out-GridView
```

### Invoke-ScriptThreaded

In this example, test.ps1 is iterated against all of the computer names, via 8 threads (the default number). Note that test.ps1 is hypothetically a script takes in one parameter from the pipline and returns a consistent result. In this example, the output of anything returned from test.ps1 is stored in $results.

```
#Hypothetical thread-safe script path/file
$script = "C:\Scripts\test.ps1"

#Get all computers in the domain
$computers = Get-ADComputer -Filter *

#Invoke test.ps1 against the computer names collected
$results = Invoke-ScriptThreaded -ScriptFile $script -ScriptTargetList $computers.name
$results | Out-GridView
```

### $test.ps1 example

```
Param(
    [Parameter(Mandatory=$true,ValueFromPipeline = $true)]
    [string]$ComputerName
    
return Test-Connection -ComputerName $ComputerName    
```
