//
//  NSToolbar+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/27/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSToolbar+Karelia.h"


@implementation NSToolbar ( KTExtensions )

- (NSToolbarItem *)itemWithIdentifier:(NSString *)anIdentifier
{
	NSArray *items = [self items];
	unsigned int i;
	for ( i=0; i<[items count]; i++ )
	{
		NSToolbarItem *item = [items objectAtIndex:i];
		if ( [[item itemIdentifier] isEqualToString:anIdentifier] )
		{
			return item;
		}
	}
	
	return nil;
}

@end
