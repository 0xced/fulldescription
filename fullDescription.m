// Copyright © 2009-2011 Cédric Luthi <http://0xced.blogspot.com>

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import "JRSwizzle/JRSwizzle.h"

@interface NSObject ()
- (NSString *) debugDescription;
@end

static BOOL gColorize = YES;
static NSUInteger gIndentWidth = 4;
static NSUInteger gIndentLevel = 0;
static NSMutableSet *gObjects = nil;

BOOL enableFullDescription(void)
{
	BOOL swizzleOK = YES;
	swizzleOK = swizzleOK && [NSObject       jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
	swizzleOK = swizzleOK && [NSString       jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
	swizzleOK = swizzleOK && [NSArray        jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
	swizzleOK = swizzleOK && [NSPointerArray jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
	swizzleOK = swizzleOK && [NSDictionary   jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
	swizzleOK = swizzleOK && [NSSet          jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
	return swizzleOK;
}

void disableFullDescription(void)
{
	[NSObject       jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
	[NSString       jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
	[NSArray        jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
	[NSPointerArray jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
	[NSDictionary   jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
	[NSSet          jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
}

__attribute__((constructor)) void initialize(void)
{
	CFPropertyListRef indentWidthPref = CFPreferencesCopyAppValue(CFSTR("DVTTextIndentWidth"), CFSTR("com.apple.dt.Xcode"));
	if (!indentWidthPref)
		indentWidthPref = CFPreferencesCopyAppValue(CFSTR("IndentWidth"), CFSTR("com.apple.Xcode"));
	
	if (indentWidthPref)
	{
		gIndentWidth = [(id)indentWidthPref intValue];
		CFRelease(indentWidthPref);
	}
	
	for (uint32_t i = 0; i < _dyld_image_count(); i++)
	{
		if (strstr(_dyld_get_image_name(i), "DevToolsBundleInjection"))
		{
			gColorize = NO;
			break;
		}
	}
	
	gObjects = [[NSMutableSet alloc] initWithCapacity:256];
	
	BOOL enabled = enableFullDescription();
	if (enabled)
		NSLog(@"FullDescription successfully loaded");
	else
		NSLog(@"FullDescription failed to load");
}

__attribute__((destructor)) void cleanup(void)
{
	[gObjects release];
	disableFullDescription();
}

static void indent(NSMutableString *string, NSUInteger indentLevel)
{
	for (NSUInteger i = 0; i < indentLevel * gIndentWidth; i++)
	{
		[string appendString:@" "];
	}
}

enum {
	black = 30,
	red,
	green,
	yellow,
	blue,
	magenta,
	cyan,
	white
};

#define pathColor blue
#define referenceColor green
#define emptyColor magenta
#define keyColor cyan
#define idColor red

static NSString* color(NSString *string, int color)
{
	if (gColorize)
		return [NSString stringWithFormat:@"\033[%dm%@\033[0m", color, string];
	else
		return string;
}

static BOOL hasMeaningfulDescription(id self)
{
	IMP selfDescriptionIMP = method_getImplementation(class_getInstanceMethod([self class], @selector(description)));
	IMP nsObjectDescriptionIMP = method_getImplementation(class_getInstanceMethod([NSObject class], @selector(description)));
	return selfDescriptionIMP != nsObjectDescriptionIMP;
}

static NSString *debugDescription(id self)
{
	if (self)
	{
		[gObjects addObject:self];
	}
	Class class = [self class];
	NSMutableString *desc = [NSMutableString stringWithFormat:@"[%p: %@]", self, class];
	unsigned int ivarCount;
	Ivar *ivars = class_copyIvarList(class, &ivarCount); // instance variables declared by superclasses are not included
	
	[desc appendString:(ivarCount <= 1) ? @" " : @"\n"];
	
	for(int i = 0; i < ivarCount; i++)
	{
		Ivar ivar = ivars[i];
		NSString *ivarName = [NSString stringWithFormat:@"%s", ivar_getName(ivar)];
		id obj;
		const char *typeEncoding = ivar_getTypeEncoding(ivar);
		
		if (ivarCount > 1)
			indent(desc, gIndentLevel);
		
		switch (typeEncoding[0]) 
		{
			case '@':
				obj = [self valueForKey:ivarName];
				if (![gObjects containsObject:obj] || [obj isKindOfClass:[NSString class]])
				{
					[desc appendFormat:@"%@: %@", ivarName, [obj debugDescription]];
				}
				else
				{
					[desc appendFormat:@"%@: => ", ivarName];
					[desc appendString:color([NSString stringWithFormat:@"%p", obj], referenceColor)];
					[desc appendString:@""];
				}
				break;
			default:
				[desc appendFormat:@"%@: %p", ivarName, object_getIvar(self, ivar)];
				break;
		}
		if (i < ivarCount-1)
		{
			[desc appendString:@"\n"];
		}
	}
	free(ivars);
	return [NSString stringWithString:desc];
}

static NSString *collectionDescription(id collection)
{
	BOOL isArray = NO, isDictionary = NO, isSet = NO;
	NSString *markerStart = @"[?", *markerEnd = @"?]";
	if ([collection isKindOfClass:[NSArray class]] || [collection isKindOfClass:[NSPointerArray class]])
	{
		if ([collection isKindOfClass:[NSPointerArray class]])
		{
			markerStart = @"<(";
			markerEnd   = @")>";
			collection = [collection allObjects];
		}
		else
		{
			markerStart = @"(";
			markerEnd   = @")";
		}
		isArray = YES;
	}
	else if ([collection isKindOfClass:[NSDictionary class]])
	{
		markerStart = @"{";
		markerEnd   = @"}";
		isDictionary = YES;
	}
	else if ([collection isKindOfClass:[NSSet class]])
	{
		markerStart = @"{(";
		markerEnd   = @")}";
		isSet = YES;
	}
	
	if ([collection count] == 0)
	{
		return [NSString stringWithFormat:@"%p:%@ %@ %@", collection, markerStart, color(@"empty", emptyColor), markerEnd];
	}
	else if ([collection count] == 1)
	{
		NSString *debugDescription = nil;
		if (isArray)
		{
			debugDescription = [[collection lastObject] debugDescription];
		}
		else if (isDictionary)
		{
			NSString *key = [[collection allKeys] lastObject];
			debugDescription = [NSString stringWithFormat:@"%@: %@", color(key, keyColor), [[collection objectForKey:key] debugDescription]];
		}
		else if (isSet)
		{
			debugDescription = debugDescription = [[collection anyObject] debugDescription];
		}
		return [NSString stringWithFormat:@"%p:%@ %@ %@", collection, markerStart, debugDescription, markerEnd];
	}
	else
	{
		NSMutableString *desc = [NSMutableString stringWithFormat:@"%p:%@\n", collection, markerStart];
		NSUInteger i = 0;
		
		for(id object in (isDictionary ? [collection allKeys] : collection))
		{
			indent(desc, gIndentLevel + 1);
			if (isArray)
			{
				[desc appendFormat:[NSString stringWithFormat:@"%%%dd) ", [[NSString stringWithFormat:@"%d", [collection count]] length]], i++];				
			}
			else if (isDictionary)
			{
				[desc appendString:color(object, keyColor)];
				[desc appendString:@": "];
			}
			gIndentLevel++;
			[desc appendString:[(isDictionary ? [collection objectForKey:object] : object) debugDescription]];
			gIndentLevel--;
			[desc appendString:@"\n"];
		}
		
		indent(desc, gIndentLevel);
		[desc appendFormat:@"%@", markerEnd];
		return [NSString stringWithString:desc];
	}
}

@implementation NSObject (fullDescription)

- (NSString *) fullDescription
{
	if (hasMeaningfulDescription(self))
	{
		NSMutableString *desc = [NSMutableString stringWithString:gIndentLevel > 0 ? @"!! " : @""];
		NSArray *descriptionLines = [[self description] componentsSeparatedByString:@"\n"];
		NSUInteger i = 0;
		for (NSString *line in descriptionLines)
		{
			if ([line length] > 0)
			{
				if (i > 0)
				{
					[desc appendString:@"\n"];
					indent(desc, gIndentLevel);
				}
				[desc appendString:line];
			}
			i++;
		}
		return desc;
	}
	else
	{
		NSString *desc;
		gIndentLevel++;
		desc = debugDescription(self);
		gIndentLevel--;
		if (gIndentLevel == 0)
		{
			[gObjects removeAllObjects];
		}
		return desc;
	}
}

@end

@implementation NSString (fullDescription)

- (NSString *) fullDescription
{
	BOOL isPath = [self isKindOfClass:NSClassFromString(@"NSPathStore2")];
	return color([self description], isPath ? pathColor : black);
}

@end

@implementation NSArray (fullDescription)

- (NSString *) fullDescription
{
	return collectionDescription(self);
}

@end

@implementation NSPointerArray (fullDescription)

- (NSString *) fullDescription
{
	return collectionDescription(self);
}

@end

@implementation NSDictionary (fullDescription)

- (NSString *) fullDescription
{
	return collectionDescription(self);
}

@end

@implementation NSSet (fullDescription)

- (NSString *) fullDescription
{
	return collectionDescription(self);
}

@end
