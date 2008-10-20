//
//  KTAbstractElement+Inspector.m
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractElement+Inspector.h"

#import "KTPage.h"

#import "KSPlugin.h"


@implementation KTAbstractElement (Inspector)

#pragma mark -
#pragma mark Inspector

/*	For all of these methods if we have no Inspector nib, then instead point to the main
 *	element's nib.
 */
- (id)inspectorObject { return self; }

- (NSBundle *)inspectorNibBundle
{
	NSBundle *result = [[self plugin] bundle];
	return result;
}

- (NSString *)inspectorNibName
{
	NSString *key = @"KTPluginNibFile";
	if ([self isKindOfClass:[KTPage class]])
	{
		key = @"KTPageNibFile";
	}
	
	NSString *result = [[self plugin] pluginPropertyForKey:key];
	return result;
}

- (id)inspectorNibOwner
{
	id result = self;
	if ([result delegate])
	{
		result = [result delegate];
	}
	return result;
}

@end
