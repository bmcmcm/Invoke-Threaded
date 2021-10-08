# Invoke-Threaded
PowerShell functions for invoking functions or scripts as threads

Invoke-Threaded is a module with two utility functions for invoking scripts or functions as threads. The function or script must accept argument 1 as the 'target' of the iteration. Additional parameters may be supplied as required. The loading of modules per thread session state is supported, if required.

These functions require that the function or script being invoked is thread safe. The Invoke-Threaded functions will return what ever is returned by the function or thread. Therefore, it is best if the function or script being invoked will always return the same format of data no matter what happens in the function or script, otherwise jagged results will be returned. The Invoke-Threaded functions return a result object upon completion, not as the individual threads return results.

