# Invoke-Threaded
PowerShell functions for invoking functions or scripts as threads. Invoke-Threaded functions work in PowerShell Core or Windows PowerShell. The Invoke-Threaded functions aren't more powerful than For-EachObject with -Parallel, however they may add some flexibility. Foreach-Object -Parallel is not available in Windows PowerShell, it is only available in PowerShell Core.

Invoke-Threaded is a module with two utility functions for invoking scripts or functions as threads. The function or script being invoked must accept argument 1 as the 'target' of the iteration. Additional parameters may be supplied as required. The loading of modules per thread session state is a supported parameter option, if required.

The Invoke-Threaded functions require that the function/commandlet or script being invoked is thread safe. The Invoke-Threaded functions will return what ever is returned by the function or thread. Therefore, it is best if the function or script being invoked will always return the same format of data no matter what happens in the function or script, otherwise jagged results may be returned. The Invoke-Threaded functions return a result object upon completion of all thread operations, not as the individual threads return results.

# Examples:

### Invoke-FunctionThreaded

In this example, Test-Connection is iterated against all of the computer names, via 100 threads. The $param variable simply adds "-Count 1" to Test-Connection so that only one ping is made. Assuming there are 1000 computers and 50% of the computer names timed out on a Test-Connection, this will iterate through the computer pings many times faster than a serial foreach.

$computers = Get-ADComputer -Filter *
$param = [System.Collections.Generic.Dictionary[string,object]]::new()
$param.Add("Count",1)
Invoke-FunctionThreaded "Test-Connection" $computers.name -ScriptParameters $param -MaxThreads 100 | Out-GridView

### Invoke-ScriptThreaded

In this example, test.ps1 is iterated against all of the computer names, via 8 threads (the default number). The output of anything returned is stored in $results.

$script = "C:\Scripts\test.ps1"
$computers = Get-ADComputer -Filter *
$results = Invoke-ScriptThreaded -ScriptFile $script -ScriptTargetList $computers.name
