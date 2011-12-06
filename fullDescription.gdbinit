define pf
	if sizeof($fullDescription_dylib_handle) == 1
		set $fullDescription_dylib_handle = (void*)dlopen("/usr/local/gdb/fullDescription.dylib", 2)
		if $fullDescription_dylib_handle == 0
			echo Could not load fullDescription.dylib\n
		end
		set $fullDescription_swizzle = (void*)dlsym($fullDescription_dylib_handle, "SwizzleFullDescription")
		if $fullDescription_swizzle == 0
			echo Could not find SwizzleFullDescription function\n
		end
	end
	
	if $argc == 0
		printf "The 'pf' (print-full) command requires an argument (an Objective-C object)\n"
	else
		if $fullDescription_swizzle != 0
			call (void)$fullDescription_swizzle()
		end
		po $arg0
		if $fullDescription_swizzle != 0
			call (void)$fullDescription_swizzle()
		end
	end
end

document pf
Recursively print instance variables of an Objective-C object.
end
