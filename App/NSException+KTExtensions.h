//
//  NSException+KTExtensions.h
//  Marvel
//
//  Created by Terrence Talbot on 12/25/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// requires ExceptionHandling.framework

extern NSString *kNoStackTraceAvailableString;

@interface NSException ( KTExtensions )

/*! returns value of NSStackTraceKey */
- (NSString *)stacktrace;

/*! returns name + first n characters of stacktrace */
- (NSString *)traceName;


- (NSString *)printStackTrace;


@end
