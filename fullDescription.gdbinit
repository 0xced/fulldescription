
define pof
	if sizeof($fullDescription_dylib_handle) == 1
		set $fullDescription_dylib_handle = (void*)dlopen("/usr/local/gdb/fullDescription.dylib", 2)
		set $fullDescription_enable = (void*)dlsym($fullDescription_dylib_handle, "fullDescription_enable")
		set $fullDescription_disable = (void*)dlsym($fullDescription_dylib_handle, "fullDescription_disable")
	end

	if $argc == 0
		printf "The 'pof' command requires an argument (an Objective-C object)\n"
	else
		call (void)$fullDescription_enable()
		po $arg0
		call (void)$fullDescription_disable()
	end
end

document pof
Recursively print instance variables of an Objective-C object.
end
