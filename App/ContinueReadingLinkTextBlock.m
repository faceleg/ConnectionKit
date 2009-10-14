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

- (NSString *)outerHTML
{
	NSString *result;
    if ([[self parser] HTMLGenerationPurpose] == kGeneratingPreview)
    {
		result = [NSString stringWithFormat:
                  @"<span id=\"%@\" class=\"kLine\">\n%@\n</span>",
                  [self DOMNodeID],
                  [self innerHTML]];
	}
    else
    {
        result = [NSString stringWithFormat:@"<span class=\"kLine\">\n%@\n</span>", [self innerHTML]];
    }
    
	return result;
}

/*	Convert @@ to the page title
 */
- (NSString *)innerHTML
{
	NSString *contentFormat = [self innerEditingHTML];
	NSString *titleText = [[self targetPage] titleText];
	if (nil == titleText)
	{
		titleText = @"";		// better than nil, which crashes!
	}
	NSString *result = [contentFormat stringByReplacing:@"@@" with:titleText];
	return result;
}

/*	When editing we display the exact format string
 */
- (NSString *)innerEditingHTML
{
	NSString *result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	return result;
}

#pragma mark -
#pragma mark Editing Status

- (BOOL)becomeFirstResponder
{
	BOOL result = [super becomeFirstResponder];
    
    // Insert the new HTML
    if (result)
    {
        [[self DOMNode] setInnerHTML:[self innerEditingHTML]];
    }
    
	return result;
}

- (BOOL)resignFirstResponder
{
	BOOL result = [super resignFirstResponder];
	
	if (result)
	{
		[[self DOMNode] setInnerHTML:[self innerHTML]];
	}
	
	return result;
}

@end
