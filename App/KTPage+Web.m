//
//  KTPage+Web.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "SVHTMLTemplateParser.h"
#import "KTMaster+Internal.h"

#import "NSBundle+KTExtensions.h"
#import "NSBundle+QuickLook.h"

#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSObject+Karelia.h"

#import <WebKit/WebKit.h>

#import "Registration.h"


@implementation KTPage ( Web )

#pragma mark -
#pragma mark Class Methods

+ (NSString *)pageTemplate
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

#pragma mark -
#pragma mark HTML Generation

/*!	Return the HTML.
*/
- (NSString *)HTMLString;
{
	BOOL isProFeature = (9 == [[[self plugin] pluginPropertyForKey:@"KTPluginPriority"] intValue]);
	if (isProFeature && ![[NSApp delegate] isPro])
	{
		return [NSString stringWithFormat:@"<html><h1>%@</h1></html>", 
			NSLocalizedString(@"Sandvox PRO is required to generate this type of page", @"")];
		// No pagelet is published if you are not registered and you are 
	}
	
	
	NSString *result = [super HTMLString];
	
	
	return result;
}

- (BOOL)pluginHTMLIsFullPage;
{
	return [self wrappedBoolForKey:@"pluginHTMLIsFullPage"];
}

- (void)setPluginHTMLIsFullPage:(BOOL)fullPage
{
	[self setWrappedBool:fullPage forKey:@"pluginHTMLIsFullPage"];
}

/*	Some page types (e.g. File Download) do not want to publish the HTML, it's just for peviewing.
 */
- (BOOL)shouldPublishHTMLTemplate
{
	BOOL result = YES;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(pageShouldPublishHTMLTemplate:)])
	{
		result = [delegate pageShouldPublishHTMLTemplate:self];
	}
	
	return result;
}

#pragma mark -
#pragma mark CSS

- (NSString *)cssClassName { return [[self plugin] pageCSSClassName]; }

/*	Generates a <link> tag to the specified stylesheet. Include a title attribute when possible.
 */
- (NSString *)stylesheetLink:(NSString *)stylesheetPath title:(NSString *)title media:(NSString *)media
{
	NSMutableString *result = [NSMutableString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\"",
                               stylesheetPath];
	
	if (title)
	{
		[result appendFormat:@" title=\"%@\"", [title stringByEscapingHTMLEntities]];
	}
	
	if (media)
	{
		[result appendFormat:@" media=\"%@\"", media];
	}
	
	[result appendString:@" />"];	// Close the tag
	
	// Tidy up
	return result;
}

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSString *)pathToDesignFile:(NSString *)filename
{
	NSString *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [[self master] design];
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:filename];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		switch ([[SVHTMLContext currentContext] generationPurpose])
		{
			case kGeneratingPreview:
				result = [[NSURL fileURLWithPath:localPath] absoluteString];
				break;
				
			case kGeneratingQuickLookPreview:
				result = [[design bundle] quicklookDataForFile:filename];
				break;
				
			default:
			{
				KTMaster *master = [(KTPage *)[[SVHTMLContext currentContext] currentPage] master];
				NSURL *designFileURL = [NSURL URLWithString:filename relativeToURL:[master designDirectoryURL]];
				result = [designFileURL stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
				break;
			}
		}
	}
	
	return result;
}

/*  Used by KTPageTemplate.html to generate links to the stylesheets needed by this page. Used to be a dedicated [[stylesheet]] parser function
 */
- (NSString *)stylesheetsHTMLString
{
    NSMutableArray *stylesheetLines = [NSMutableArray array];
	
	
	// Always include the global sandvox CSS.
	if ([[SVHTMLContext currentContext] isPublishing])
	{
		NSString *globalCSSFile = [[NSBundle mainBundle] overridingPathForResource:@"sandvox" ofType:@"css"];
		[stylesheetLines addObject:[self stylesheetLink:[[SVHTMLContext currentContext] URLStringForResourceFile:[NSURL fileURLWithPath:globalCSSFile]] title:nil media:nil]];
	}
    else
	{
		NSString *globalCSSFile = [[NSBundle mainBundle] quicklookDataForFile:@"Contents/Resources/sandvox.css"];
		[stylesheetLines addObject:[self stylesheetLink:globalCSSFile title:nil media:nil]];
	}
	
    
	// Ask the page and its components for extra general-purpose CSS files required
	NSMutableSet *pluginCSSFiles = [NSMutableSet set];
	[self makeComponentsPerformSelector:@selector(addCSSFilePathToSet:forPage:)
							 withObject:pluginCSSFiles
							   withPage:self
							  recursive:NO];
	
	NSEnumerator *pluginCSSEnumerator = [pluginCSSFiles objectEnumerator];
	NSString *aCSSFile;
	while (aCSSFile = [pluginCSSEnumerator nextObject])
	{
		NSURL *CSSURL = [NSURL fileURLWithPath:aCSSFile];
        [stylesheetLines addObject:[self stylesheetLink:[[SVHTMLContext currentContext] URLStringForResourceFile:CSSURL] title:nil media:nil]];
	}
	
	
	// Then the base design's CSS file -- the most specific
	NSString *mainCSS = [self pathToDesignFile:@"main.css"];
	[stylesheetLines addObject:[self stylesheetLink:mainCSS
											  title:[[[self master] design] title]
											  media:nil]];
	
	
	// design's print.css but not for Quick Look
    if ([[SVHTMLContext currentContext] generationPurpose] != kGeneratingQuickLookPreview)
	{
		NSString *printCSS = [self pathToDesignFile:@"print.css"];
		if (printCSS) [stylesheetLines addObject:[self stylesheetLink:printCSS title:nil media:@"print"]];
	}
	
	
	// If we're in preview mode include additional editing CSS
	if (![[SVHTMLContext currentContext] isPublishing])
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] overridingPathForResource:@"design-time"
																			 ofType:@"css"];
		[stylesheetLines addObject:[self stylesheetLink:[[NSURL fileURLWithPath:editingCSSPath] absoluteString] title:nil media:nil]];
	}
	
    
	// For preview/quicklook mode, the banner CSS
	NSString *masterCSS = [[self master] bannerCSSForPurpose:[[SVHTMLContext currentContext] generationPurpose]];
    if (masterCSS)
    {
        // For Quick Look and previewing the master-specific stylesheet should be inline.
        // When publishing it is lumped into main.css
        if (![[SVHTMLContext currentContext] isPublishing])
        {
            [stylesheetLines addObject:[NSString stringWithFormat:@"<style type=\"text/css\">\n%@\n</style>", masterCSS]];
        }
	}
    
	
	// Tidy up
	NSString *result = [stylesheetLines componentsJoinedByString:@"\n"];
	return result;
}

#pragma mark -
#pragma mark Other

/*!	Generate path to javascript.  Nil if not there */
- (NSString *)javascriptURLPath
{
	NSString *result = nil;
	
	NSBundle *designBundle = [[[self master] design] bundle];
	BOOL scriptExists = ([designBundle pathForResource:@"javascript" ofType:@"js"] != nil);
	if (scriptExists)
	{
		NSURL *javascriptURL = [NSURL URLWithString:@"javascript.js" relativeToURL:[[self master] designDirectoryURL]];
		result = [javascriptURL stringRelativeToURL:[self URL]];
	}
	
	return result;
}


- (BOOL)isNewPage
{
    return myIsNewPage;
}

- (void)setNewPage:(BOOL)flag
{
    myIsNewPage = flag;
}

/*!	Return the string that makes up the title.  Page Title | Site Title | Author ... this is the DEFAULT if not set by windowTitle property.
*/
- (NSString *)comboTitleText
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *titleSeparator = [defaults objectForKey:@"TitleSeparator"];
	
	if ( [self isDeleted] || (nil == [[self site] root]) )
	{
		return @"Bad Page!";
	}
	
	NSMutableString *buf = [NSMutableString string];
	
	BOOL needsSeparator = NO;
	NSString *titleText = [self titleText];
	if ( nil != titleText && ![titleText isEqualToString:@""])
	{
		[buf appendString:titleText];
		needsSeparator = YES;
	}
	
	
	NSString *siteTitleText = [[[self master] valueForKey:@"siteTitleHTML"] stringByConvertingHTMLToPlainText];
	if ( (nil != siteTitleText) && ![siteTitleText isEqualToString:@""] && ![siteTitleText isEqualToString:titleText] )
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:siteTitleText];
		needsSeparator = YES;
	}
	
	NSString *author = [[self master] valueForKey:@"author"];
	if (nil != author
		&& ![author isEqualToString:@""]
		&& ![author isEqualToString:siteTitleText]
		)
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:author];
	}
	
	if ([buf isEqualToString:@""])
	{
		buf = [NSMutableString stringWithString:NSLocalizedString(@"Untitled Page","fallback page title if no title is otherwise found")];
	}
	
	return buf;
}

#pragma mark -
#pragma mark DRD

- (BOOL)isXHTML	// returns true if our page is XHTML of some type, false if old HTML
{
	KTDocType defaultDocType = [[NSUserDefaults standardUserDefaults] integerForKey:@"DocType"];

	[self makeComponentsPerformSelector:@selector(findMinimumDocType:forPage:) withObject:&defaultDocType withPage:self recursive:NO];
	BOOL result = (KTHTML401DocType != defaultDocType);
	return result;
}

- (NSString *)DTD
{
	KTDocType defaultDocType = [[NSUserDefaults standardUserDefaults] integerForKey:@"DocType"];

	[self makeComponentsPerformSelector:@selector(findMinimumDocType:forPage:) withObject:&defaultDocType withPage:self recursive:NO];
	
	// if wantsJSKit comments, use transitional doc type (or worse, if already known)
	if ( defaultDocType > KTXHTMLTransitionalDocType )
	{
		if ( ![self disableComments] && [self boolForKey:@"allowComments"] && [[self master] wantsJSKit] )
		{
			defaultDocType = KTXHTMLTransitionalDocType; // if this changes to KTHTML401DocType, also change isXHTML
		}
	}
	
	NSString *result = nil;
	switch (defaultDocType)
	{
		case KTHTML401DocType:
			result = @"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">";
			break;
		case KTXHTMLTransitionalDocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">";
			break;
		case KTXHTMLStrictDocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">";
			break;
		case KTXHTML11DocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">";
			break;
	}
	return result;
}

@end
