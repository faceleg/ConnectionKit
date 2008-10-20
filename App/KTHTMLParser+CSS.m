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
#import "KTMaster+Internal.h"
#import "KTPage.h"
#import "KTArchivePage.h"

#import "NSBundle+QuickLook.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSURL+Karelia.h"

#import "assertions.h"


@interface KTHTMLParser (CSSPrivate)
- (NSString *)pathToDesignFile:(NSString *)filename;
- (KTDesign *)design;

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
		[stylesheetLines addObject:[self stylesheetLink:[self resourceFilePath:globalCSSFile relativeToPage:[self currentPage]] title:nil media:nil]];
	}
	
			
	// Then the base design's CSS file.
	NSString *mainCSS = [self pathToDesignFile:@"main.css"];
	[stylesheetLines addObject:[self stylesheetLink:mainCSS
											  title:[[self design] title]
											  media:nil]];
	
	
	// Ask the page and its components for extra CSS files required
	NSMutableSet *pluginCSSFiles = [NSMutableSet set];
	[page makeComponentsPerformSelector:@selector(addCSSFilePathToSet:forPage:)
							 withObject:pluginCSSFiles
							   withPage:page
							  recursive:NO];
	
	NSEnumerator *pluginCSSEnumerator = [pluginCSSFiles objectEnumerator];
	NSString *aCSSFile;
	while (aCSSFile = [pluginCSSEnumerator nextObject])
	{
		[stylesheetLines addObject:[self stylesheetLink:[self resourceFilePath:aCSSFile relativeToPage:[self currentPage]] title:nil media:nil]];
		
		// Tell the delegate
		[self didEncounterResourceFile:aCSSFile];
	}
	
	
	// If we're in preview mode include additional editing CSS
	if ([self HTMLGenerationPurpose] == kGeneratingPreview)
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] overridingPathForResource:@"additionalEditingCSS"
																			 ofType:@"txt"];
		[stylesheetLines addObject:[self stylesheetLink:[[NSURL fileURLWithPath:editingCSSPath] absoluteString] title:nil media:nil]];
	}
	
	
	NSString *masterCSS = [[page master] masterCSSForPurpose:[self HTMLGenerationPurpose]];
    if (masterCSS)
    {
        // For Quick Look and previewing the master-specific stylesheet should be inline. When publishing it is external
        if ([self HTMLGenerationPurpose] == kGeneratingPreview || [self HTMLGenerationPurpose] == kGeneratingQuickLookPreview)
        {
            [stylesheetLines addObject:[NSString stringWithFormat:@"<style type=\"text/css\">\n%@\n</style>", masterCSS]];
        }
        else
        {
            NSURL *masterCSSURL = [NSURL URLWithString:@"master.css" relativeToURL:[[page master] designDirectoryURL]];
            NSString *relativeMasterCSSPath = [masterCSSURL stringRelativeToURL:[[self currentPage] URL]];
            
            [stylesheetLines addObject:[self stylesheetLink:relativeMasterCSSPath title:nil media:nil]];
        }
	}
    
	
	// Don't bother to include print.css for Quick Look
	if ([self HTMLGenerationPurpose] != kGeneratingQuickLookPreview)
	{
		NSString *printCSS = [self pathToDesignFile:@"print.css"];
		if (printCSS) [stylesheetLines addObject:[self stylesheetLink:printCSS title:nil media:@"print"]];
	}
	
	
	// Tidy up
	NSString *result = [stylesheetLines componentsJoinedByString:@"\n"];
	return result;
}

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSString *)pathToDesignFile:(NSString *)filename
{
	NSString *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [self design];
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
			{
				KTMaster *master = [(KTPage *)[self currentPage] master];
				NSURL *designFileURL = [NSURL URLWithString:filename relativeToURL:[master designDirectoryURL]];
				result = [designFileURL stringRelativeToURL:[[self currentPage] URL]];
				break;
			}
		}
	}
	
	return result;
}

- (KTDesign *)design
{
	KTAbstractPage *page = [self currentPage];
	if ([page isKindOfClass:[KTArchivePage class]]) page = [page parent];
	OBASSERT([page isKindOfClass:[KTPage class]]);
	KTDesign *result = [[(KTPage *)page master] design];
	
	return result;
}

/*	Generates a <link> tag to the specified stylesheet. Include a title attribute when possible.
 */
- (NSString *)stylesheetLink:(NSString *)stylesheetPath title:(NSString *)title media:(NSString *)media
{
	// HACK: Preview paths need a fake query to fool webkit's caching.
    if ([self HTMLGenerationPurpose] == kGeneratingPreview)
    {
        //stylesheetPath = [stylesheetPath stringByAppendingFormat:@"?%@", [self parserID]];
    }
    
    NSMutableString *buffer = [NSMutableString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"",
																stylesheetPath];
	
	if (title)
	{
		[buffer appendFormat:@" title=\"%@\"", [title stringByEscapingHTMLEntities]];
	}
	
	if (media)
	{
		[buffer appendFormat:@" media=\"%@\"", media];
	}
	
	[buffer appendString:@" />"];	// Close the tag
	
	// Tidy up
	NSString *result = [[buffer copy] autorelease];
	return result;
}

@end
