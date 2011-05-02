//
//  NSBundle+Sandvox.h
//  Sandvox
//
//  Created by Mike on 25/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Utilities for localization. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>


@interface NSBundle (Sandvox)

- (NSString *)localizedStringForString:(NSString *)aString
                              language:(NSString *)aLocalization
                              fallback:(NSString *)aFallbackString;

- (NSString *)pathForImageResource:(NSString *)name
                          language:(NSString *)preferredLanguage;

@end
