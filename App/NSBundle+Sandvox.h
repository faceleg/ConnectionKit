//
//  NSBundle+Sandvox.h
//  Sandvox
//
//  Created by Mike on 25/11/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBundle (Sandvox)

- (NSString *)localizedStringForString:(NSString *)aString
                              language:(NSString *)aLocalization
                              fallback:(NSString *)aFallbackString;

- (NSString *)pathForImageResource:(NSString *)name
                          language:(NSString *)preferredLanguage;

@end
