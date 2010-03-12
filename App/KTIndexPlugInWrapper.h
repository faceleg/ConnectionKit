//
//  KTIndexPluginWrapper.h
//  Marvel
//
//  Created by Mike on 14/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLPlugInWrapper.h"


@interface KTIndexPlugInWrapper : KTHTMLPlugInWrapper

// Inserts one item per known collection preset into aMenu at the specified index.
+ (void)populateMenuWithCollectionPresets:(NSMenu *)aMenu atIndex:(NSUInteger)index;


@end
