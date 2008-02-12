//
//  KTAbstractHTMLPlugin.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAppPlugin.h"


@interface KTAbstractHTMLPlugin : KTAppPlugin
{
	NSImage *myIcon;
	NSString *myTemplateHTML;
}

- (NSString *)pluginName;
- (NSImage *)pluginIcon;            // derived from pluginIconName
- (NSString *)CSSClassName;
- (NSString *)templateHTMLAsString;

@end
