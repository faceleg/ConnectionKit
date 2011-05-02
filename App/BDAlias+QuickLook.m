//
//  BDAlias+QuickLook.m
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "BDAlias+QuickLook.h"

#import "NSData+Karelia.h"

@implementation BDAlias (QuickLook)

- (NSString *)quickLookPseudoTag
{
	NSString *result = [NSString stringWithFormat:@"<!svxData alias:%@>",
												  [[self aliasData] base64Encoding]];
	
	return result;
}

@end
