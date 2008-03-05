//
//  ContinueReadingLinkTextBlock.m
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "ContinueReadingLinkTextBlock.h"

#import "KTPage.h"

#import "NSString-Utilities.h"


@implementation ContinueReadingLinkTextBlock

- (void)dealloc
{
	[myTargetPage release];
	[super dealloc];
}

- (KTPage *)targetPage { return myTargetPage; }

- (void)setTargetPage:(KTPage *)page
{
	[page retain];
	[myTargetPage release];
	myTargetPage = page;
}

- (NSString *)outerHTML
{
	NSString *result = [NSString stringWithFormat:@"<span id=\"%@\" class=\"kLine\">\r%@\r</span>",
												  [self DOMNodeID],
												  [self innerHTML]];
	
	return result;
}

/*	Convert @@ to the page title
 */
- (NSString *)innerHTML
{
	NSString *contentFormat = [self innerEditingHTML];
	NSString *result = [contentFormat stringByReplacing:@"@@" with:[[self targetPage] titleText]];
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
