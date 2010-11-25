//
//  NSBundle+Sandvox.h
//  Sandvox
//
//  Created by Mike on 25/11/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBundle (Sandvox)

- (NSString *)localizedStringForString:(NSString *)aString
                              language:(NSString *)aLocalization
                              fallback:(NSString *)aFallbackString;

@end
