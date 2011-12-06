all:
	gcc -arch ppc -arch ppc64 -arch i386 -arch x86_64 -fobjc-gc -std=c99 fullDescription.m -framework Foundation -dynamiclib -o fullDescription.dylib

debug:
	gcc -fobjc-gc -std=c99 fullDescription.m -framework Foundation -dynamiclib -o fullDescription.dylib
