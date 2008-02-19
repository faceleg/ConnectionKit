//
//  KTHMTLParser+CSS.m
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTHTMLParser.h"
#import "KTHTMLParser+Private.h"

#import "KTMaster.h"

#import "NSString+KTExtensions.h"


@interface KTHTMLParser (CSSPrivate)
- (NSString *)linkToStylesheet:(NSString *)stylesheetPath title:(NSString *)title;
@end


@implementation KTHTMLParser (CSS)

- (NSString *)stylesheetWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSMutableArray *stylesheetLines = [NSMutableArray array];
	KTPage *page = [self currentPage];
	
	
	// Always include the global sandvox CSS.
	NSString *globalCSSFile = [[NSBundle mainBundle] overridingPathForResource:@"sandvox" ofType:@"css"];
	[stylesheetLines addObject:[self linkToStylesheet:[self resourceFilePathRelativeToCurrentPage:globalCSSFile] title:nil]];
	
			
	// Then the base design's CSS file.
	[stylesheetLines addObject:[self linkToStylesheet:[[self cache] valueForKey:@"cssURLPath"]
												title:[[[self cache] valueForKey:@"cssTitle"] escapedEntities]]];
	
	
	// Ask the page and it's components for extra CSS files required
	NSMutableSet *pluginCSSFiles = [NSMutableSet set];
	[page makeComponentsPerformSelector:@selector(addCSSFilePathToSet:forPage:)
							 withObject:pluginCSSFiles
							   withPage:page
							  recursive:NO];
	
	NSEnumerator *pluginCSSEnumerator = [pluginCSSFiles objectEnumerator];
	NSString *aCSSFile;
	while (aCSSFile = [pluginCSSEnumerator nextObject])
	{
		[stylesheetLines addObject:[self linkToStylesheet:[self resourceFilePathRelativeToCurrentPage:aCSSFile] title:nil]];
		
		// Tell the delegate
		[self didEncounterResourceFile:aCSSFile];
	}
	
	
	// If we're in preview mode...
	if ([self HTMLGenerationPurpose] == kGeneratingPreview)
	{
		// ...include the additional editing CSS
		NSString *editingCSSPath = [[NSBundle mainBundle] overridingPathForResource:@"additionalEditingCSS"
																			 ofType:@"txt"];
																		 
		[stylesheetLines addObject:[self linkToStylesheet:[[NSURL fileURLWithPath:editingCSSPath] absoluteString] title:nil]];
		
		
		// And inline stylesheet for master-specific properties
		NSString *masterCSS = [[[self currentPage] master] masterCSSForPurpose:[self HTMLGenerationPurpose]];
		if (masterCSS)
		{
			[stylesheetLines addObject:[NSString stringWithFormat:@"<style type=\"text/css\">\r%@\r</style>", masterCSS]];
		}
	}
	else
	{
		// Proper stylesheet for master-specific properties
		NSString *masterCSSPath = [[[self currentPage] master] publishedMasterCSSPathRelativeToSite];
		NSString *pagePath = [[self currentPage] publishedPathRelativeToSite];
		
		NSString *relativeMasterCSSPath =
			[[@"/" stringByAppendingString:masterCSSPath] pathRelativeTo:[@"/" stringByAppendingString:pagePath]];
		
		[stylesheetLines addObject:[self linkToStylesheet:relativeMasterCSSPath title:nil]];
	}
	
	NSString *result = [stylesheetLines componentsJoinedByString:@"\r"];
	return result;
}

/*	Generates a <link> tag to the specified stylesheet. Include a title attribute when possible.
 */
- (NSString *)linkToStylesheet:(NSString *)stylesheetPath title:(NSString *)title
{
	if (title)
	{
		return [NSString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\" title=\"%@\" />",
										  stylesheetPath,
										  title];
	}
	else
	{
		return [NSString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\" />",
										  stylesheetPath];
	}
}

@end
