//
//  BDAlias+QuickLook.m
//  SandvoxQuickLook
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "BDAlias+QuickLook.h"

#import "NSData+Karelia.h"


@implementation BDAlias (QuickLook)

+ (BDAlias *)aliasWithQuickLookPseudoTagPath:(NSString *)path
{
	NSData *aliasData = [NSData dataWithBase64EncodedString:path];
	BDAlias *result = [self aliasWithData:aliasData];
	return result;
}

@end
