//
//  NSTextView+KTExtensions.h
//  Marvel
//
//  Created by Dan Wood on 4/13/07.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define TD_SYNTAX_COLORING_MODE_ATTR		@"UKTextDocumentSyntaxColoringMode"		// Anything we colorize gets this attribute.
#define TD_USER_DEFINED_IDENTIFIERS			@"SyntaxColoring:UserIdentifiers"		// Key in user defaults holding user-defined identifiers to colorize.

@interface NSTextView ( KTExtensions )

-(void)		recolorRange: (NSRange)range;

-(void) turnOffWrapping;

- (void) setDesiredAttributes:(NSDictionary *)attr;

+ (void) startRecordingFontChanges;

@end
