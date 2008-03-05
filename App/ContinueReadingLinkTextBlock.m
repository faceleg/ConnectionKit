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

- (NSString *)HTMLRepresentation
{
	// Figure out our content
	NSString *contentFormat = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	NSString *content = [contentFormat stringByReplacing:@"@@" with:[[self targetPage] titleText]];
	
	NSString *result = [NSString stringWithFormat:@"<span id=\"%@\" class=\"kLine\">\r%@\r</span>",
												  [self DOMNodeID],
												  content];
	
	return result;
}

@end
