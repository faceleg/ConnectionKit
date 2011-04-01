//
//  SVHTMLValidatorController.h
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSWebViewWindowController.h"

@class KTPage;

@interface SVValidatorWindowController : KSWebViewWindowController {

	NSString *_validationReportString;
}

typedef enum { kNonSandvoxHTMLPage, kSandvoxPage, kSandvoxFragment } PageValidationType;

@property (nonatomic, copy) NSString *validationReportString;


- (BOOL) validatePage:(KTPage *)page
	   windowForSheet:(NSWindow *)aWindow;

- (BOOL) validateSource:(NSString *)pageSource
			 pageValidationType:(PageValidationType)pageValidationType
disabledPreviewObjectsCount:(NSUInteger)disabledPreviewObjectsCount
				charset:(NSString *)charset
		  docTypeString:(NSString *)docTypeString
		 windowForSheet:(NSWindow *)aWindow;


@end
