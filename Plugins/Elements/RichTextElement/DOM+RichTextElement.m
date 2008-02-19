//
//  DOMNode+RichTextElement.m
//  KTPlugins
//
//  Created by Mike on 23/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "DOM+RichTextElement.h"

#import <Sandvox.h>
@implementation DOMNode (RichTextElement)

- (BOOL)isFileList
{
	NSArray *divElements = [self divElements];
	if ([divElements count] == 0 || [[self childNodes] length] != [divElements count])
	{
		return NO;
	}
	
	
	NSEnumerator *divsEnumerator = [divElements objectEnumerator];
	DOMHTMLDivElement *aDiv;
	while (aDiv = [divsEnumerator nextObject])
	{
		if ([[aDiv childNodes] length] != 1 || ![[aDiv firstChild] isKindOfClass:[DOMText class]])
		{
			return NO;
		}
		
		NSURL *URL = [NSURL URLWithString:[(DOMText *)[aDiv firstChild] data]];
		if (!URL || ![URL isFileURL])
		{
			return NO;
		}
	}
	
	return YES;
}

@end