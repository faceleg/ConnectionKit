//
//  BDAlias+QuickLook.h
//  SandvoxQuickLook
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDAlias.h"


@interface BDAlias (QuickLook)
+ (BDAlias *)aliasWithQuickLookPseudoTagPath:(NSString *)path;
@end
