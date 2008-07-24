//
//  KTKeypathURLProtocol.m
//  Marvel
//
//  Created by Terrence Talbot on 5/9/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTKeypathURLProtocol.h"

#import "KTAppDelegate.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "NSImage+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"

@implementation KTKeypathURLProtocol

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	(void) [NSURLProtocol registerClass:[KTKeypathURLProtocol class]];
	[pool release];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	NSURL *theURL = [request URL];
	NSString *scheme = [theURL scheme];
    return [scheme isEqualToString:@"keypath"];
}

+ (NSURL *)URLForDocument:(KTDocument *)aDocument keyPath:(NSString *)aKeyPath
{
	NSURL *result = [NSURL URLWithUnescapedString:[NSString stringWithFormat:
												   @"keypath:/%@/z%ld/%@",
												   [[aDocument documentInfo] siteID],		// document ID
												   [KTURLProtocol cacheConfusingNumber],	// unique junk to confuse cache
												   aKeyPath]];								// key to get to the item
	return result;
}

/*!	URL is in the form
	keypath:/documentID/junk/path.to.object.extension/ of which
	path.to.object.extension/ should be left on the scanner
*/
- (NSData*)dataWithResourceSpecifier:(NSString *)aSpecifier 
						 document:(KTDocument *)aDocument
						 mimeType:(NSString **)aMimeType 
							error:(NSError **)anError
{
	NSData *data = nil;
	NSString *errorString = nil;
	
	NSScanner *scanner = [NSScanner scannerWithString:aSpecifier];
	NSString *keyPathPlusExtension = [aSpecifier substringFromIndex:[scanner scanLocation]];
	NSString *keyPath = [keyPathPlusExtension stringByDeletingPathExtension];
	id value = nil;
	
	@try
	{
		value = [aDocument valueForKeyPath:keyPath];
	}
	@catch (NSException *exception)
	{
		errorString = [exception reason];
	}
	
	if (nil != value)
	{
		if ([value isKindOfClass:[NSData class]])
		{
			data = (NSData *)value;
		}
		else if ([value isKindOfClass:[NSString class]])
		{
			data = [((NSString *)value) dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
		}
		else if ([value isKindOfClass:[NSImage class]])
		{
			NSImage *image = (NSImage *)value;
			data = [image representationForMIMEType:*aMimeType];
		}
		else
		{
//			NSLog(@"Not sure what do to with value class %@ from %@", [value class], requestURL);
			NSLog(@"error: keypath protocol does not understand value class %@", [value className]);
		}
	}
	if (nil == data && nil == errorString)
	{
		errorString = [NSString stringWithFormat:
			NSLocalizedString(@"The following keyPath returned an empty or uncovertable value: %@", @"error message"),
			keyPath];
	}
	
	if ( nil != errorString )
	{
		*anError = [self errorWithString:errorString];
	}

	return data;
}

@end
