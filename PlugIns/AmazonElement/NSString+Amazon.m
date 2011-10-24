//
//  NSString+Amazon.m
//  Amazon Support
//
//  Created by Mike on 24/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "NSString+Amazon.h"

@implementation NSString ( Amazon )

- (NSString*)stringByReplacingOccurrencesOfString:(NSString *)value with:(NSString *)newValue;
{
    NSMutableString *newString = [NSMutableString stringWithString:self];
    [newString replaceOccurrencesOfString:value
							   withString:newValue
								  options:NSLiteralSearch
									range:NSMakeRange(0, [newString length])];
    return [NSString stringWithString:newString];
}

@end
