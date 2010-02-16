//
//  SVHTMLValidatorController.h
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSWebViewWindowController.h"


@interface SVHTMLValidatorController : KSWebViewWindowController {

}

- (void) validateSource:(NSString *)pageSource charset:(NSString *)charset windowForSheet:(NSWindow *)aWindow;


@end
