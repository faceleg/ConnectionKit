//
//  NSCharacterSet+QuickLook.m
//  SandvoxQuickLook
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "NSCharacterSet+QuickLook.h"


@implementation NSCharacterSet (QuickLook)

- (NSCharacterSet *)setByAddingCharactersInString:(NSString *)aString
{
	NSMutableCharacterSet *mutableSet = [self mutableCopyWithZone:[self zone]];
	[mutableSet addCharactersInString:aString];
	NSCharacterSet *result = [[mutableSet copy] autorelease];
	[mutableSet release];
	return result;
}

+ (NSCharacterSet *)svxDataPseudoTagEndCharacterSet
{
	static NSCharacterSet *result;
	
	if (!result)
	{
		result = [self whitespaceCharacterSet];
		result = [[result setByAddingCharactersInString:@">"] copy];
	}
	
	return result;
}

@end
