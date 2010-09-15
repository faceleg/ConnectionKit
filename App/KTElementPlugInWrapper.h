//
//  KTElementPlugInWrapper.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLPlugInWrapper.h"


@interface KTElementPlugInWrapper : KTHTMLPlugInWrapper

+ (NSSet *)pageletPlugins;
+ (NSSet *)pagePlugins;

// Inserts one item per known collection preset into aMenu at the specified index.
+ (void)populateMenuWithCollectionPresets:(NSMenu *)aMenu atIndex:(NSUInteger)index;

@end
