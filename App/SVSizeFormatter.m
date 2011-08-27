//
//  SVSizeFormatter.m
//  Sandvox
//
//  Created by Mike on 16/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVSizeFormatter.h"


@implementation SVSizeFormatter

- (BOOL)getObjectValue:(id *)obj
             forString:(NSString *)string
                 range:(NSRange *)rangep
                 error:(NSError **)error;
{
    BOOL result = [super getObjectValue:obj forString:string range:rangep error:error];
    
    // Handle invalid value by treating as nil
    if (!result)
    {
        *obj = nil;
        result = YES;
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVIndentLevelFormatter

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error
{
    if (![self numberFromString:*partialStringPtr])
    {
        *partialStringPtr = @"";
        *proposedSelRangePtr = NSMakeRange(0, 0);
        return NO;
    }
    
    return YES;
}

@end
