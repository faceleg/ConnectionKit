//
//  KTExternalMediaFile.h
//  Marvel
//
//  Created by Mike on 11/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractMediaFile.h"

@class BDAlias;
@interface KTExternalMediaFile : KTAbstractMediaFile
{
}

- (BDAlias *)alias;
- (void)setAlias:(BDAlias *)alias;

@end
