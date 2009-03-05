//
//  KTIndexPlugin.h
//  Marvel
//
//  Created by Mike on 14/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractHTMLPlugin.h"


@interface KTIndexPlugin : KTAbstractHTMLPlugin
{
}

+ (void)addPresetPluginsToMenu:(NSMenu *)aMenu
						target:(id)aTarget
						action:(SEL)anAction
					 pullsDown:(BOOL)isPullDown
					 showIcons:(BOOL)showIcons
					smallIcons:(BOOL)smallIcons
					 smallText:(BOOL)smallText
			 allowNewPageTypes:(BOOL)allowNewPageTypes;

@end
