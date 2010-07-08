//
//  SVHTMLValidatorController.h
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSWebViewWindowController.h"

@class KTPage;

@interface SVValidatorWindowController : KSWebViewWindowController {

	NSString *_validationReportString;
}

@property (copy) NSString *validationReportString;


- (BOOL) validateSource:(NSString *)pageSource isFullPage:(BOOL)isFullPage charset:(NSString *)charset docTypeString:(NSString *)docTypeString windowForSheet:(NSWindow *)aWindow;
- (BOOL) validatePage:(KTPage *)page windowForSheet:(NSWindow *)aWindow;


@end
