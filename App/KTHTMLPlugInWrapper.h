//
//  KTHTMLPlugInWrapper.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KSPlugInWrapper.h"
#import "SVPageletManager.h"


@interface KTHTMLPlugInWrapper : KSPlugInWrapper <SVGraphicFactory>
{
	NSImage     *_icon;
	NSString    *_templateHTML;
}

- (NSString *)name;
- (NSImage *)pluginIcon;            // derived from pluginIconName
- (NSUInteger)priority;

- (NSString *)CSSClassName;
- (NSString *)templateHTMLAsString;

@end
