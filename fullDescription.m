// Copyright © 2009 Cédric Luthi <http://0xced.blogspot.com>

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "JRSwizzle/JRSwizzle.h"

@interface NSObject ()
- (NSString *) debugDescription;
@end

static NSUInteger gIndentWidth = 4;
static NSUInteger gIndentLevel = 0;
static NSMutableSet *gObjects = nil;

__attribute__((constructor)) void initialize(void)
{
    CFPropertyListRef indentWidthPref = CFPreferencesCopyAppValue(CFSTR("IndentWidth"), CFSTR("com.apple.Xcode"));
    if (indentWidthPref)
    {
        gIndentWidth = [(id)indentWidthPref intValue];
        CFRelease(indentWidthPref);
    }
    
    gObjects = [[NSMutableSet alloc] initWithCapacity:256];
}

__attribute__((destructor)) void cleanup(void)
{
    [gObjects release];
}

void fullDescription_enable(void)
{
    [NSObject     jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
    [NSString     jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
    [NSArray      jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
    [NSDictionary jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
    [NSSet        jr_swizzleMethod:@selector(debugDescription) withMethod:@selector(fullDescription) error:nil];
}

void fullDescription_disable(void)
{
    [NSObject     jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
    [NSString     jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
    [NSArray      jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
    [NSDictionary jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
    [NSSet        jr_swizzleMethod:@selector(fullDescription) withMethod:@selector(debugDescription) error:nil];
}

void indent(NSMutableString *string, NSUInteger indentLevel)
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

NSMutableString* color(NSString *string, int color)
{
    return [NSMutableString stringWithFormat:@"\033[%dm%@\033[0m", color, string];
}

NSString *debugDescription(id self)
{
    if (self)
    {
        [gObjects addObject:self];
    }
    Class class = [self class];
    NSMutableString *desc = [NSMutableString stringWithFormat:@"[%p: %@]", self, class];
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(class, &ivarCount);
    
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
                } else
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

NSString *collectionDescription(id collection)
{
    BOOL isArray = NO, isDictionary = NO, isSet = NO;
    NSString *markerStart = @"[?", *markerEnd = @"?]";
    if ([collection isKindOfClass:[NSArray class]])
    {
        markerStart = @"(";
        markerEnd   = @")";
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
