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

+ (void)addPlugins:(NSSet *)plugins
		    toMenu:(NSMenu *)aMenu
		    target:(id)aTarget
		    action:(SEL)anAction
	     showIcons:(BOOL)showIcons
		smallIcons:(BOOL)smallIcons
		 smallText:(BOOL)smallText;

@end
