//
//  NSString+Amazon.h
//  Amazon Support
//
//  Created by Mike on 24/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	Convenience methods on NSString used by Amazon Support.


#import <Cocoa/Cocoa.h>


@interface NSString ( Amazon )

- (NSString*)stringByReplacingOccurrencesOfString:(NSString *)value with:(NSString *)newValue;

@end
