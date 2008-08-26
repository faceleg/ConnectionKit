//
//  LeopardStuff.m
//  LeopardStuff
//
//  Created by Dan Wood on 8/14/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "LeopardStuff.h"
#import "Symbolicator.h"
#import <ExceptionHandling/NSExceptionHandler.h>

@implementation LeopardStuff

// Do the leopard-only version of this. ATSApplicationFontsPath doesn't seem to be working for us.
- (void)loadLocalFontsInBundle:(NSBundle *)aBundle;
{
	NSString *fontsFolder = [aBundle resourcePath];		// make sure this actually works for flat bundles.
	if (fontsFolder)
	{
		NSURL *fontsURL = [NSURL fileURLWithPath:fontsFolder];
		if (fontsURL)
		{
			FSRef fsRef;
			(void)CFURLGetFSRef((CFURLRef)fontsURL, &fsRef);
			
			OSStatus error = ATSFontActivateFromFileReference(&fsRef, kATSFontContextLocal, kATSFontFormatUnspecified, 
													 NULL, kATSOptionFlagsProcessSubdirectories, NULL);
			
			if (noErr != error) NSLog(@"Error %s activating fonts in %@", GetMacOSStatusErrorString(error), aBundle);
		}
	}
}

- (NSString *)symbolizeBacktrace:(NSException *)exception;
{
	NSString *result = nil;

	//
	// THE CODE IN THIS BLOCK IS DUPLICATED IN NSEXCEPTION+KARELIA.M -- PLEASE KEEP IN SYNC.
	//
	// If we can't invoke the VMUSymbolicator, this will return nil.
	Class VMUSymbolicatorClass = NSClassFromString(@"VMUSymbolicator");
	if ([VMUSymbolicatorClass respondsToSelector:@selector(symbolicatorForPid:)])
	{
		NSMutableString *buf = [NSMutableString string];
		VMUSymbolicator *symbolicator = [VMUSymbolicatorClass symbolicatorForPid:[[NSProcessInfo processInfo] processIdentifier]];
		if ([symbolicator respondsToSelector:@selector(symbolForAddress:)])
		{
			// Note: I'd like to use [exception callStackReturnAddresses] but it's returning nil!
			NSEnumerator *enumerator = [[[[exception userInfo] objectForKey:NSStackTraceKey] componentsSeparatedByString:@"  "] objectEnumerator];
			//NSNumber *addrNumber;
			NSString *addrString;
			
			while ((addrString = [enumerator nextObject]) != nil)
			{
				unsigned long long value = 0 ; // [addrNumber unsignedLongLongValue];
				NSScanner *hexScanner = [NSScanner scannerWithString:addrString];
				if ([hexScanner scanHexLongLong:&value])
				{
					VMUSymbol *sym = [symbolicator symbolForAddress:value];
					if (sym)
					{
						[buf appendString:[sym name]];
					}
					else
					{
						//[buf appendString:[addrNumber stringValue]];	// couldn't find symbol; just keep address string
						[buf appendString:addrString];	// couldn't find symbol; just keep address string
					}
				}
				else
				{
					[buf appendString:addrString];	// couldn't convert to number; just keep address string
				}
				[buf appendString:@"\n"];
			}
			result = [NSString stringWithString:buf];
		}
	}	

	//
	// END BLOCK
	//
	
	return result;
}

@end
