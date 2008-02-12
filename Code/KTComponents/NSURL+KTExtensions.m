//
//  NSURL+KTExtensions.m
//  KTComponents
//
//  Created by Mike on 05/01/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "NSURL+Karelia.h"

#import "NSFileManager+Karelia.h"
#import "NSString+Karelia.h"


@interface NSURL (KTExtensionsPrivate)

+ (void)getBookmarkDictionaryURLs:(NSArray **)URLs
						andTitles:(NSArray **)titles
				   fromPasteboard:(NSPasteboard *)pasteboard;

+ (void)getWebURLs:(NSArray **)URLs
		 andTitles:(NSArray **)titles
	fromPasteboard:(NSPasteboard *)pasteboard;

+ (void)getBasicURLs:(NSArray **)URLs
		   andTitles:(NSArray **)titles
	  fromPasteboard:(NSPasteboard *)pasteboard;

+ (void)getURLs:(NSArray **)URLs andTitles:(NSArray **)titles fromPasteboardString:(NSString *)string;

@end


# pragma mark -


@implementation NSURL (KTExtensions)

/*	Returns whether the URL conforms to RFC 1808.
 *	To conform, it must have a network location, and thus a resource specifier beginning with "//"
 *	See the NSURL docs for more info.
 */
- (BOOL)hasNetworkLocation
{
	NSString *resourceSpecifier = [self resourceSpecifier];
	
	BOOL result = (resourceSpecifier != nil &&
				   [resourceSpecifier length] > 2 &&
				   ![[self scheme] isEqualToString:@"applewebdata"] &&
				   ![[self scheme] isEqualToString:@"file"] &&
				   ![[self scheme] isEqualToString:@"svximage"] &&
				   [[resourceSpecifier substringToIndex:2] isEqualToString:@"//"]);
	
	return result;
}

#pragma mark -
#pragma mark Webloc files

/*	Gets the URL and title from the specified webloc file
 */
+ (void)getURL:(NSURL **)URL andTitle:(NSString **)title fromWeblocFile:(NSString *)path
{
	// Use the Carbon Resource Manager to read 'url ' resource #256.
	// String sems to be pre ASCII, with 2-bytes converted to % escapes
	NSData *urlData = [[NSFileManager defaultManager] readFromResourceFileAtPath:path
																			type:'url '
																		   named:nil
																			  id:256];
	
	NSString *urlString = [NSString stringWithData:urlData encoding:NSASCIIStringEncoding];
	NSURL *url = [NSURL URLWithString:[urlString encodeLegally]];
	if (url && URL != NULL) {
		*URL = url;
	}
	
	// Use the Carbon Resource Manager to read 'urln' resource #256.
	// empirically, this seems to be UTF8 encoded.
	NSData *nameData = [[NSFileManager defaultManager] readFromResourceFileAtPath:path
																			 type:'urln'
																			named:nil
																			   id:256];
	
	NSString *nameString = [NSString stringWithData:nameData encoding:NSUTF8StringEncoding];
	if (nameString && title != NULL) {
		*title = [nameString escapedEntities];
	}
}

#pragma mark -
#pragma mark Pasteboards

+ (NSArray *)KTComponentsSupportedURLPasteboardTypes
{
	return [NSArray arrayWithObjects:@"WebURLsWithTitlesPboardType",
									 @"BookmarkDictionaryListPboardType",
									 NSURLPboardType,
									 NSStringPboardType,
									 NSRTFPboardType,
									 NSRTFDPboardType,
									 nil];
}


/*	Retrieves all URLs that fall within +KTComponentsSupportedURLPasteboardTypes from the pasteboard.
 *	Does NOT discriminate against file URLs.
 *	The titles array can contain instances of NSNull if no title was found.
 */
+ (void)getURLs:(NSArray **)URLs
	  andTitles:(NSArray **)titles
 fromPasteboard:(NSPasteboard *)pasteboard
{
	// Get the URLs and titles from the best type available on the pasteboard
	NSString *bestPboardType = [pasteboard availableTypeFromArray:[self KTComponentsSupportedURLPasteboardTypes]];
	if (bestPboardType)
	{
		if ([bestPboardType isEqualToString:@"BookmarkDictionaryListPboardType"]) {
			[self getBookmarkDictionaryURLs:URLs andTitles:titles fromPasteboard:pasteboard];
		}
		else if ([bestPboardType isEqualToString:@"WebURLsWithTitlesPboardType"]) {
			[self getWebURLs:URLs andTitles:titles fromPasteboard:pasteboard];
		}
		else if ([bestPboardType isEqualToString:NSURLPboardType]) {
			[self getBasicURLs:URLs andTitles:titles fromPasteboard:pasteboard];
		}
		else {	// The fallback option is string parsing
			NSString *string = [pasteboard stringForType:bestPboardType];
			[self getURLs:URLs andTitles:titles fromPasteboardString:string];
		}
	}
	
	NSAssert([*URLs count] == [*titles count], @"URL and title arrays must be of same length");
}


/*	Collects URLs and titles from the pasteboard using +getURLs:andTitles:fromPasteboard:
 *	Results are then filtered to read in .webloc files and remove file URLs as requested
 */
+ (void)getURLs:(NSArray **)URLs
	  andTitles:(NSArray **)titles
 fromPasteboard:(NSPasteboard *)pasteboard
readWeblocFiles:(BOOL)convertWeblocs
 ignoreFileURLs:(BOOL)ignoreFileURLs
{
	// Get the unfiltered URLs
	NSArray *unfilteredURLs = nil;
	NSArray *unfilteredTitles = nil;
	[self getURLs:&unfilteredURLs andTitles:&unfilteredTitles fromPasteboard:pasteboard];
	
	
	// Run through the list
	NSMutableArray *resultURLs = [NSMutableArray arrayWithCapacity:[unfilteredURLs count]];
	NSMutableArray *resultTitles = [NSMutableArray arrayWithCapacity:[unfilteredTitles count]];
	
	unsigned int i;
	for (i = 0; i < [unfilteredURLs count]; i++ )
	{
		NSURL *URL = [unfilteredURLs objectAtIndex:i];
		NSString *title = [unfilteredTitles objectAtIndex:i];
	
		// Convert .webloc files as required
		NSString *path = [URL path];
		if (convertWeblocs && [URL isFileURL] && [[path pathExtension] isEqualToString:@"webloc"]) {
			[self getURL:&URL andTitle:&title fromWeblocFile:path];
		}
		
		// Add the URL to the list unless we've been requested to ignore file URLs
		if (!(ignoreFileURLs && [URL isFileURL])) {
			[resultURLs addObject:URL];
			[resultTitles addObject:title];
		}
	}
	
	
	// Return
	if (URLs != NULL) {
		*URLs = [NSArray arrayWithArray:resultURLs];
	}
	
	if (titles != NULL) {
		*titles = [NSArray arrayWithArray:resultTitles];
	}
}

/*	Retrieve URLs and their titles from the pasteboard for the "BookmarkDictionaryListPboardType" type
 */
+ (void)getBookmarkDictionaryURLs:(NSArray **)URLs
						andTitles:(NSArray **)titles
				   fromPasteboard:(NSPasteboard *)pasteboard
{
	// Bail if we haven't been handed decent data
	NSArray *arrayFromData = [pasteboard propertyListForType:@"BookmarkDictionaryListPboardType"];
	if (!arrayFromData || [arrayFromData count] < 1) {
		return;
	}
	
	
	NSDictionary *objectInfo = [arrayFromData objectAtIndex:0];
	
	if (URLs != NULL) {
		NSString *URLString = [objectInfo valueForKey:@"URLString"];
		NSURL *URL = [NSURL URLWithString:[URLString encodeLegally]];	/// encodeLegally to handle accented characters
		*URLs = [NSArray arrayWithObject:URL];
	}
	
	if (titles != NULL) {
		*titles = [NSArray arrayWithObject:[[objectInfo valueForKey:@"URIDictionary"] valueForKey:@"title"]];
	}
}

/*	Retrieve URLs and their titles from the pasteboard for the "WebURLsWithTitlesPboardType" type
 *	/// Rewritten 1/5/07 to account for being passed a nil URL
 */
+ (void)getWebURLs:(NSArray **)URLs
		 andTitles:(NSArray **)titles
	fromPasteboard:(NSPasteboard *)pasteboard
{
	// Bail if we haven't been handed decent data
	NSArray *rawDataArray = [pasteboard propertyListForType:@"WebURLsWithTitlesPboardType"];
	if (!rawDataArray || [rawDataArray count] < 2) {
		return;
	}
	
	
	// Get the array of URLs and their titles
	NSArray *URLStrings = [rawDataArray objectAtIndex:0];
	NSArray *URLTitles = [rawDataArray objectAtIndex:1];
	unsigned count = [URLStrings count];
	
	
	// Run through each URL
	NSMutableArray *intermediateURLs = [NSMutableArray arrayWithCapacity:count];
	NSMutableArray *intermediateTitles = [NSMutableArray arrayWithCapacity:count];
	int i;
	for (i=0; i<[URLStrings count]; i++)
	{
		// Convert the string to a proper URL. If actually valid, add it & title to the results
		NSString *URLString = [URLStrings objectAtIndex:i];
		NSURL *URL = [NSURL URLWithString:[URLString encodeLegally]];	/// encodeLegally to handle accented characters
		if (URL) {
			[intermediateURLs addObject:URL];
			[intermediateTitles addObject:[URLTitles objectAtIndex:i]];
		}
	}
	
	
	// Convert the intermediate arrays to their non-mutable counterparts
	if (URLs != NULL) {
		*URLs = [NSArray arrayWithArray:intermediateURLs];
	}
	if (titles != NULL) {
		*titles = [NSArray arrayWithArray:intermediateTitles];
	}
}

+ (void)getBasicURLs:(NSArray **)URLs
		   andTitles:(NSArray **)titles
	  fromPasteboard:(NSPasteboard *)pasteboard
{
	NSURL *URL = [NSURL URLFromPasteboard:pasteboard];
	id title = nil;
	
	// We may be able to get title from CorePasteboardFlavorType 'urln'
	if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:@"CorePasteboardFlavorType 0x75726C6E"]]) {
		title = [pasteboard stringForType:@"CorePasteboardFlavorType 0x75726C6E"];
	}
	
	// If still no title, use NSNull
	if (!title) {
		title = [NSNull null];
	}
	
	
	if (URLs != NULL) {
		*URLs = [NSArray arrayWithObject:URL];
	}
	
	if (titles != NULL) {
		*titles = [NSArray arrayWithObject:title];
	}
}

+ (void)getURLs:(NSArray **)URLs andTitles:(NSArray **)titles fromPasteboardString:(NSString *)string;
{
	if ([string length] > 2048) {	// No point processing particularly long strings
		return;
	}
	
	NSURL *URL = [NSURL URLWithString:[string encodeLegally]];	/// encodeLegally to handle accented characters
	if (URL && [URL hasNetworkLocation])
	{
		if (URLs != NULL) {
			*URLs = [NSArray arrayWithObject:URL];
		}
		
		if (titles != NULL) {
			*titles = [NSArray arrayWithObject:[NSNull null]];
		}
	}
}

@end
