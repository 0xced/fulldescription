define pf
	if sizeof($fullDescription_dylib_handle) == 1
		set $fullDescription_dylib_handle = (void*)dlopen("/usr/local/gdb/fullDescription.dylib", 2)
		set $fullDescription_swizzle = (void*)dlsym($fullDescription_dylib_handle, "SwizzleFullDescription")
	end
	
	if $argc == 0
		printf "The 'pf' (print-full) command requires an argument (an Objective-C object)\n"
	else
		call (void)$fullDescription_swizzle()
		po $arg0
		call (void)$fullDescription_swizzle()
	end
end

document pf
Recursively print instance variables of an Objective-C object.
end
