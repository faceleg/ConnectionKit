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

- (NSString *)pageCSSClassName;
- (NSString *)pageletCSSClassName;

+ (NSSet *)pageletPlugins;
+ (NSSet *)pagePlugins;

@end
