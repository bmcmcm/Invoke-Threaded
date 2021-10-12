# Invoke-Threaded
PowerShell functions for invoking functions or scripts as threads

Invoke-Threaded is a module with two utility functions for invoking scripts or functions as threads. The function or script must accept argument 1 as the 'target' of the iteration. Additional parameters may be supplied as required. The loading of modules per thread session state is supported, if required.

The Invoke-Threaded functions require that the function/commandlet or script being invoked is thread safe. The Invoke-Threaded functions will return what ever is returned by the function or thread. Therefore, it is best if the function or script being invoked will always return the same format of data no matter what happens in the function or script, otherwise jagged results may be returned. The Invoke-Threaded functions return a result object upon completion of all thread operations, not as the individual threads return results.

Function Examples:

Invoke-FunctionThreaded

   $computers = Get-ADComputer -Filter *                                  #Get all computers in the domain
   $param = [System.Collections.Generic.Dictionary[string,object]]::new() #Use a generic dictionary to supply additional parameters
   $param.Add("Count",1)                                                  #repeat .Add as many times as nessessary to add all parameters
   Invoke-FunctionThreaded "Test-Connection" $computers.name -ScriptParameters $param -MaxThreads 100 | Out-GridView #Invokes Test-Connection against the computer names collected
   
What will happen is Test-Connection will be iterated against all of the computer names, via 100 threads. The $param variable simply adds "-Count 1" to Test-Connection so that only one ping is made. Assuming there are 1000 computers and 50% of the computer names timed out on a Test-Connection, this will iterate through the computer pings many times faster than a serial foreach. The isn't particularly more powerful than For-EachObject with -Parallel, however it is more resiliant to errors. Foreach-Object 
