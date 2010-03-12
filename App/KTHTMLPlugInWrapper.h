//
//  KTHTMLPlugInWrapper.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSPlugInWrapper.h"


@interface KTHTMLPlugInWrapper : KSPlugInWrapper
{
	NSImage     *_icon;
	NSString    *_templateHTML;
}

- (NSString *)pluginName;
- (NSImage *)pluginIcon;            // derived from pluginIconName
- (NSString *)CSSClassName;
- (NSString *)templateHTMLAsString;

@end
