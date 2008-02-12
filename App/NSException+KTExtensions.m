//
//  NSException+KTExtensions.m
//  Marvel
//
//  Created by Terrence Talbot on 12/25/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSException+KTExtensions.h"
#import <ExceptionHandling/NSExceptionHandler.h>

NSString *kNoStackTraceAvailableString = @"No stack trace available.";

@implementation NSException ( KTExtensions )


#include "MoreAddrToSym.h"
#include "MoreBacktrace.h"

enum {
	kFrameCount = 70
};

- (NSString *)backtraceAsSymbols
{
	NSString *result = nil;
	NSString *stackString = [[self userInfo] objectForKey:NSStackTraceKey];
	if (nil != stackString)
	{
		// Scan up to kFrameCount symbols into their values as an array
		MoreAToSAddr addresses[kFrameCount] = { 0 };
		int frameCount = 0;
		NSScanner *scanner = [NSScanner scannerWithString:stackString];
		while (![scanner isAtEnd])
		{
			unsigned value;
			BOOL found = [scanner scanHexInt:&value];
			if (!found)
			{
				break;
			}
			addresses[frameCount++] = value;
			if (frameCount >= kFrameCount)
			{
				break;
			}
		}
		
		int						err;
		MoreAToSSymInfo *		symbols = NULL;
		
		// Create an array of NULL CFStringRefs to hold the symbol pointers.
		err = MoreAToSCreate(frameCount, &symbols);
		if (0 == err)
		{
			err = MoreAToSCopySymbolNamesUsingDyld(frameCount, addresses, symbols);
			if (0 == err)
			{
				NSMutableString *buf = [NSMutableString string];
				int i;
				for ( i = 0 ; i < frameCount ; i++ )
				{
					NSString *symbolName;
					if (kMoreAToSNoSymbol == symbols[i].symbolType)
					{
						symbolName = [NSString stringWithFormat:@"0x%08llx", addresses[i]];
					}
					else
					{
						symbolName = [NSString stringWithUTF8String:symbols[i].symbolName];
					}
					[buf appendFormat:@"%@  ", symbolName];
				}
				if ([buf length] >= 2)
				{
					[buf deleteCharactersInRange:NSMakeRange([buf length]-2, 2)];
				}
				result = buf;
			}
			// Clean up.
			MoreAToSDestroy(frameCount, symbols);
		}
			
	}
	return result;
}

- (NSString *)stacktrace
{
	NSString *stack = [self backtraceAsSymbols];
	if ( (nil == stack) || [stack isEqualToString:@""] )
	{
		stack = kNoStackTraceAvailableString;
	}
	
	return stack;
}


- (NSString *)traceName
{
    NSString *result = nil;
    
	NSString *aReason = [self reason];
	if (nil ==  aReason)
	{
		aReason = @"";
	}
	// Now, trim down reason so that we only keep alpha/space, and replace digits with #
	
	NSMutableCharacterSet *keepSet = [[[NSCharacterSet alphanumericCharacterSet] mutableCopy] autorelease];
	[keepSet removeCharactersInRange:NSMakeRange('0',10)];
	[keepSet addCharactersInString:@" "];
		
	NSMutableString *newReason = [NSMutableString stringWithCapacity: [aReason length]];
	NSScanner *scanner = [NSScanner scannerWithString:aReason];
	[scanner setCharactersToBeSkipped:[keepSet invertedSet]];
	while (![scanner isAtEnd])
	{
		NSString *keptString = nil;
		BOOL found = [scanner scanCharactersFromSet:keepSet intoString:&keptString];
		if (found)
		{
			[newReason appendString:keptString];
		}
	}
	aReason = [newReason substringToIndex:MIN([newReason length], (unsigned)50)];
	
	NSString *appVersionString = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"];
	
	NSString *trace = [self stacktrace];
    if ( ![trace isEqualToString:kNoStackTraceAvailableString] )
    {
		
		// Skip the first two (handler and throw); show top 3 below that.
		NSArray *traceArray = [trace componentsSeparatedByString:@"  "];
		if ([traceArray count] >= 5)
		{
			NSArray *top3 = [traceArray subarrayWithRange:NSMakeRange(2,3)];
			
			// Now abbreviate these guys a bit
			NSMutableString *buf = [NSMutableString string];
			NSEnumerator *theEnum = [top3 objectEnumerator];
			NSString *str;

			while (nil != (str = [theEnum nextObject]) )
			{
#define MAX_PER_SYMBOL 24
				if ([str length] > MAX_PER_SYMBOL)
				{
					str = [str substringWithRange:NSMakeRange(0,MAX_PER_SYMBOL)];
				}
				[buf appendString:str];
				[buf appendString:@"  "];
			}
			[buf deleteCharactersInRange:NSMakeRange([buf length]-2,2)];
			trace = buf;
		}
        result = [NSString stringWithFormat:@"%@: %@, %@: %@", appVersionString, [self name], aReason, trace];
    }
    else
    {
        result = [NSString stringWithFormat:@"%@: %@, %@", appVersionString, [self name], aReason];
    }
	result = [result condenseWhiteSpace];	// single spaces instead

    return result;
}


// used to be debug only

- (NSString *)printStackTrace;
{
	NSString *stack = [self stacktrace]; // [[self userInfo] objectForKey:NSStackTraceKey];
	if (nil == stack) return kNoStackTraceAvailableString;
	
	NSTask *task=[[[NSTask alloc] init] autorelease];
	NSString *pid = [[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]] stringValue];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
	
	[args addObject:@"-p"];
	[args addObject:pid];
	[args addObjectsFromArray:[stack componentsSeparatedByString:@"  "]];
	// Note: function addresses are separated by double spaces, not a single space.
	
	[task setLaunchPath:@"/usr/bin/atos"];
	[task setArguments:args];
	
	NSPipe *outPipe = [NSPipe pipe];
	NSFileHandle *outHandle = [outPipe fileHandleForReading];
	
	[task setStandardOutput:outPipe];
	[task launch];
	[task waitUntilExit];
	
	NSData *outData = [outHandle readDataToEndOfFile];
	NSString *result = [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] autorelease];
	NSMutableArray *array = [NSMutableArray arrayWithArray:[result componentsSeparatedByString:@"\n"]];
	
	// Delete last 3 (_main start start) and first two (handler and the raise)
	if ([array count] > 8)
	{
		[array removeObjectsInRange:NSMakeRange(0,2)];
		[array removeObjectsInRange:NSMakeRange([array count] - 6, 6)];
	}
	result = [array componentsJoinedByString:@"\n"];
	
	return result;
}


@end
