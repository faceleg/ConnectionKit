//
//  KTElementPlugin.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractHTMLPlugin.h"


@interface KTElementPlugin : KTAbstractHTMLPlugin
{

}

- (NSString *)pageCSSClassName;
- (NSString *)pageletCSSClassName;

+ (NSSet *)pageletPlugins;
+ (NSSet *)pagePlugins;

+ (void)populateMenu:(NSMenu *)menu atIndex:(NSUInteger)index withPlugins:(NSSet *)plugins;

@end
