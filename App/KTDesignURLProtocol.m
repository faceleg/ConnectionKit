//
//  KTDesignURLProtocol.m
//  Marvel
//
//  Created by Terrence Talbot on 5/9/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDesignURLProtocol.h"

#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDesignManager.h"
#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTComponents.h"


@implementation KTDesignURLProtocol

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	//(void) [NSURLProtocol registerClass:[KTDesignURLProtocol class]];
	[pool release];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	NSURL *theURL = [request URL];
	NSString *scheme = [theURL scheme];
    return [scheme isEqualToString:@"design"];
}

+ (NSURL *)URLForDocument:(KTDocument *)aDocument designBundleIdentifier:(NSString *)aDesignBundleIdentifier
{
	NSString *string = [NSString stringWithFormat:
		@"design:/%@/z%ld/%@/",
		[aDocument documentID],					// document identifier
		[KTURLProtocol cacheConfusingNumber],	// unique junk to confuse cache
		[aDesignBundleIdentifier urlEncode]];
	NSURL *result = [NSURL URLWithString:[string encodeLegally]];						// design
	return result;
}

/*!	URL is in the form design:/documentID/junk/designBundleIdentifier/ 
	of which designBundleIdentifier/ should be left on the scanner
*/
- (NSData*)dataWithResourceSpecifier:(NSString *)aSpecifier 
							document:(KTDocument *)aDocument
							mimeType:(NSString **)aMimeType 
							   error:(NSError **)anError
{
	NSData *result = nil;
	
	// Get the path of the resource, being sure to remove leading and trailing slashes
	NSArray *pathComponents = [[aSpecifier stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] pathComponents];
	NSString *designBundleIdentifier = [[pathComponents objectAtIndex:0] urlDecode];
	
	if ([pathComponents count] <= 1)	// No design resource has been specified, assume it's the main CSS
	{
		// This rather cunningly goes and gets the css data, but using the main thread
		NSMutableData *tempData = [[NSMutableData alloc] init];
		
		NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:designBundleIdentifier, @"identifier",
																				tempData, @"data",
																				nil];
		
		[aDocument performSelectorOnMainThread:@selector(addGeneratedCSSUsingDictionary:) withObject:dictionary waitUntilDone:YES];
		[dictionary release];
		
		result = [NSData dataWithData:tempData];
		[tempData release];
		
		if (nil == result)
		{
			*anError = [self errorWithString:[NSString stringWithFormat:NSLocalizedString(@"Unable to generate CSS for identifier %@",
																						  "error message"), designBundleIdentifier]]; 
		}
		
		*aMimeType = @"text/css";
	}
	else	// Read the resource in from the file
	{
		NSString *path = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)]];
		KTDesign *design = [[[NSApp delegate] designManager] designForIdentifier:designBundleIdentifier];
		result = [design dataForResourceAtPath:path MIMEType:aMimeType error:anError];
	}
	
	return result;
}

@end


@interface KTDocument (KTDesignURLProtocolPrivate)
- (void)addGeneratedCSSUsingDictionary:(NSDictionary *)dictionary;
- (void)addGeneratedCSSForDesignIdentifier:(NSString *)identifier toData:(NSMutableData *)data;
@end


@implementation KTDocument (KTDesignURLProtocolPrivate)

/*	Little bit hackish - separates the dictionary into its components and calls the next command
 */
- (void)addGeneratedCSSUsingDictionary:(NSDictionary *)dictionary;
{
	[self addGeneratedCSSForDesignIdentifier:[dictionary objectForKey:@"identifier"] toData:[dictionary objectForKey:@"data"]];
}

/*	Generates the CSS data and adds it to the end of the passed mutable data object
 */
- (void)addGeneratedCSSForDesignIdentifier:(NSString *)identifier toData:(NSMutableData *)data;
{
	NSData *cssData = [self generatedCSSForDesignBundleIdentifier:identifier
											 managedObjectContext:(KTManagedObjectContext *)[self managedObjectContext]];
	
	[data appendData:cssData];
}

@end

