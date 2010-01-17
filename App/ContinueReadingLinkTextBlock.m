//
//  ContinueReadingLinkTextBlock.m
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "ContinueReadingLinkTextBlock.h"

#import "SVHTMLTemplateParser.h"
#import "KTPage.h"

#import "NSString+Karelia.h"


@implementation ContinueReadingLinkTextBlock

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[myTargetPage release];
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTPage *)targetPage { return myTargetPage; }

- (void)setTargetPage:(KTPage *)page
{
	[page retain];
	[myTargetPage release];
	myTargetPage = page;
}

#pragma mark -
#pragma mark HTML

- (NSString *)HTMLString
{
	NSString *result;
    if ([[SVHTMLContext currentContext] generationPurpose] == kGeneratingPreview)
    {
		result = [NSString stringWithFormat:
                  @"<span id=\"%@\" class=\"kLine\">\n%@\n</span>",
                  [self DOMNodeID],
                  [self innerHTMLString]];
	}
    else
    {
        result = [NSString stringWithFormat:@"<span class=\"kLine\">\n%@\n</span>", [self innerHTMLString]];
    }
    
	return result;
}

/*	Convert @@ to the page title
 */
- (NSString *)innerHTMLString
{
	NSString *contentFormat = [self innerEditingHTML];
	NSString *title = [[[self targetPage] titleBox] text];
	if (nil == title)
	{
		title = @"";		// better than nil, which crashes!
	}
	NSString *result = [contentFormat stringByReplacing:@"@@" with:title];
	return result;
}

/*	When editing we display the exact format string
 */
- (NSString *)innerEditingHTML
{
	NSString *result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	return result;
}

@end
