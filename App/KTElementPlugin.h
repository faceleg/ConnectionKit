//
//  KTElementPlugin.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractHTMLPlugin.h"


@interface KTElementPlugin : KTAbstractHTMLPlugin
{

}

- (NSString *)pageCSSClassName;
- (NSString *)pageletCSSClassName;

@end
