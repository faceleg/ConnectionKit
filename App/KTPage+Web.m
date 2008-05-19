//
//  KTPage+Web.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "KTPage.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTHTMLParser.h"
#import "KTManagedObjectContext.h"
#import "KTMaster.h"

#import "NSBundle+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"

#import <WebKit/WebKit.h>

#ifdef APP_RELEASE
#import "Registration.h"
#endif


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

/*!	Given the page text, scan for all page ID references and convert to the proper relative links.
*/
- (NSString *)fixPageLinksFromString:(NSString *)originalString managedObjectContext:(KTManagedObjectContext *)context
{
	NSMutableString *buffer = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:originalString];
	while ( ![scanner isAtEnd] )
	{
		NSString *beforeLink = nil;
		BOOL found = [scanner scanUpToString:kKTPageIDDesignator intoString:&beforeLink];
		if (found)
		{
			[buffer appendString:beforeLink];
			if (![scanner isAtEnd])
			{
				[scanner scanString:kKTPageIDDesignator intoString:nil];
				NSString *idString = nil;
				BOOL foundNumber = [scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
													   intoString:&idString];
				if (foundNumber)
				{
					KTPage* thePage = [KTPage pageWithUniqueID:idString inManagedObjectContext:context];
					NSString *newPath = nil;
					if (thePage)
					{
						newPath = [thePage pathRelativeTo:self];
					}
					else
					{
						newPath = @"#";
					}
					[buffer appendString:newPath];
				}
			}
		}
	}
	return [NSString stringWithString:buffer];
}

/*!	Return the HTML.
*/
- (NSString *)contentHTMLWithParserDelegate:(id)parserDelegate isPreview:(BOOL)isPreview;
{
	BOOL isProFeature = (9 == [[[self plugin] pluginPropertyForKey:@"KTPluginPriority"] intValue]);
	if (isProFeature && ![[NSApp delegate] isPro])
	{
		return [NSString stringWithFormat:@"<html><h1>%@</h1></html>", 
			NSLocalizedString(@"Sandvox PRO is required to generate this type of page", @"")];
		// No pagelet is published if you are not registered and you are 
	}
	
	
	NSString *result = [super contentHTMLWithParserDelegate:parserDelegate isPreview:isPreview];
	
	
	// Now that we have page contents in unicode, clean up to the desired character encoding.
	result = [result escapeCharactersOutOfCharset:[[self master] valueForKey:@"charset"]];		

	if (![self isXHTML])	// convert /> to > for HTML 4.0.1 compatibility
	{
		result = [result stringByReplacing:@"/>" with:@">"];
	}
	
	
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
#pragma mark RSS

/*!	Return the HTML.
*/
- (NSString *)RSSRepresentation
{
	NSString *result = @"[PAGE, UNABLE TO GET RSS]";
	
	// Find the template
	NSString *template = [[[self plugin] bundle] templateRSSAsString];
	if (nil == template)
	{
		// No special template for this bundle, so look for the generic one in the app
		template = [[NSBundle mainBundle] templateRSSAsString];
	}
	
	
	if (nil != template)
	{
		result = [KTHTMLParser parseTemplate:template component:self];

		// We won't do any "escapeCharactersOutOfEncoding" since we are using UTF8, which means everything is OK, and we
		// don't want to introduce any entities into the XML anyhow.
	}
    return result;
}

- (NSSize)RSSFeedThumbnailsSize { return NSMakeSize(128.0, 128.0); }

#pragma mark -
#pragma mark CSS

- (NSString *)cssClassName { return [[self plugin] pageCSSClassName]; }

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
		result = [[self designDirectoryPath] stringByAppendingPathComponent:@"javascript.js"];
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

/*!	Return the string that makes up the title.  Page Title | Site Title | Author
*/
- (NSString *)comboTitleText
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *titleSeparator = [defaults objectForKey:@"TitleSeparator"];
	
	if ( [self isDeleted] || (nil == [[self documentInfo] root]) )
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
	
	
	NSString *siteTitleText = [[[self master] valueForKey:@"siteTitleHTML"] flattenHTML];
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

	@try
	{
		[self makeComponentsPerformSelector:@selector(findMinimumDocType:forPage:) withObject:&defaultDocType withPage:self recursive:NO];
	}
	@finally
	{
	}
	
	BOOL result = (KTHTML401DocType != defaultDocType);
	return result;
}

- (NSString *)DTD
{
	KTDocType defaultDocType = [[NSUserDefaults standardUserDefaults] integerForKey:@"DocType"];

	@try
	{
		[self makeComponentsPerformSelector:@selector(findMinimumDocType:forPage:) withObject:&defaultDocType withPage:self recursive:NO];
	}
	@finally
	{
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
