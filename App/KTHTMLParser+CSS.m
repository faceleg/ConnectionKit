//
//  KTHMTLParser+CSS.m
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTHTMLParser.h"
#import "KTHTMLParser+Private.h"

#import "KTAbstractPluginDelegate.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "KTArchivePage.h"

#import "NSBundle+QuickLook.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"

#import "assertions.h"


@interface KTHTMLParser (CSSPrivate)
- (NSString *)pathToDesignFile:(NSString *)filename;
- (NSString *)stylesheetLink:(NSString *)stylesheetPath title:(NSString *)title media:(NSString *)media;
@end


@implementation KTHTMLParser (CSS)

- (NSString *)stylesheetWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSMutableArray *stylesheetLines = [NSMutableArray array];
	KTPage *page = (KTPage *)[self component];
	
	
	// Always include the global sandvox CSS.
	if ([self HTMLGenerationPurpose] == kGeneratingQuickLookPreview)
	{
		NSString *globalCSSFile = [[NSBundle mainBundle] quicklookDataForFile:@"Contents/Resources/sandvox.css"];
		[stylesheetLines addObject:[self stylesheetLink:globalCSSFile title:nil media:nil]];
	}
	else
	{
		NSString *globalCSSFile = [[NSBundle mainBundle] overridingPathForResource:@"sandvox" ofType:@"css"];
		[stylesheetLines addObject:[self stylesheetLink:[self resourceFilePathRelativeToCurrentPage:globalCSSFile] title:nil media:nil]];
	}
	
			
	// Then the base design's CSS file.
	NSString *mainCSS = [self pathToDesignFile:@"main.css"];
	[stylesheetLines addObject:[self stylesheetLink:mainCSS title:[[[self cache] valueForKey:@"cssTitle"] escapedEntities] media:nil]];
	
	
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
		[stylesheetLines addObject:[self stylesheetLink:[self resourceFilePathRelativeToCurrentPage:aCSSFile] title:nil media:nil]];
		
		// Tell the delegate
		[self didEncounterResourceFile:aCSSFile];
	}
	
	
	// If we're in preview mode include additional edting CSS
	if ([self HTMLGenerationPurpose] == kGeneratingPreview)
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] overridingPathForResource:@"additionalEditingCSS"
																			 ofType:@"txt"];
		[stylesheetLines addObject:[self stylesheetLink:[[NSURL fileURLWithPath:editingCSSPath] absoluteString] title:nil media:nil]];
	}
	
	
	// For Quick Look and previewing the master-specific stylesheet should be inline. When publishing it is external
	if ([self HTMLGenerationPurpose] == kGeneratingPreview || [self HTMLGenerationPurpose] == kGeneratingQuickLookPreview)
	{
		NSString *masterCSS = [[page master] masterCSSForPurpose:[self HTMLGenerationPurpose]];
		if (masterCSS)
		{
			[stylesheetLines addObject:[NSString stringWithFormat:@"<style type=\"text/css\">\r%@\r</style>", masterCSS]];
		}
	}
	else
	{
		NSString *masterCSSPath = [[page master] publishedMasterCSSPathRelativeToSite];
		NSString *pagePath = [[self currentPage] pathRelativeToSite];
		
		NSString *relativeMasterCSSPath =
			[[@"/" stringByAppendingString:masterCSSPath] pathRelativeTo:[@"/" stringByAppendingString:pagePath]];
		
		[stylesheetLines addObject:[self stylesheetLink:relativeMasterCSSPath title:nil media:nil]];
	}
	
	
	// Don't bother to include print.css for Quick Look
	if ([self HTMLGenerationPurpose] != kGeneratingQuickLookPreview)
	{
		NSString *printCSS = [self pathToDesignFile:@"print.css"];
		if (printCSS) [stylesheetLines addObject:[self stylesheetLink:printCSS title:nil media:@"print"]];
	}
	
	
	// Tidy up
	NSString *result = [stylesheetLines componentsJoinedByString:@"\r"];
	return result;
}

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSString *)pathToDesignFile:(NSString *)filename
{
	NSString *result = nil;
	
	// Return nil if the file doesn't actually exist
	KTAbstractPage *page = [self currentPage];
	if ([page isKindOfClass:[KTArchivePage class]]) page = [page parent];
	OBASSERT([page isKindOfClass:[KTPage class]]);
	KTDesign *design = [[(KTPage *)page master] design];
	
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:filename];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		switch ([self HTMLGenerationPurpose])
		{
			case kGeneratingPreview:
				result = [[NSURL fileURLWithPath:localPath] absoluteString];
				break;
				
			case kGeneratingQuickLookPreview:
				result = [[design bundle] quicklookDataForFile:filename];
				break;
				
			default:
				result = [[[self currentPage] designDirectoryPath] stringByAppendingPathComponent:filename];
				break;
		}
	}
	
	return result;
}

/*	Generates a <link> tag to the specified stylesheet. Include a title attribute when possible.
 */
- (NSString *)stylesheetLink:(NSString *)stylesheetPath title:(NSString *)title media:(NSString *)media
{
	NSMutableString *buffer = [NSMutableString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\" />",
																stylesheetPath];
	
	if (title)
	{
		[buffer appendFormat:@" title=\"%@\"", title];
	}
	
	if (media)
	{
		[buffer appendFormat:@" media=\"%@\"", media];
	}
	
	NSString *result = [[buffer copy] autorelease];
	return result;
}

@end
