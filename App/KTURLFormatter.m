//
//  KTURLFormatter.m
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTURLFormatter.h"


#import "NSURL+Karelia.h"


@implementation KTURLFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
    NSString *result = @"";
    
    if (anObject)
    {
        if ([anObject isKindOfClass:[NSURL class]])
        {
            result = [(NSURL *)anObject absoluteString];
        }
        else
        {
            result = nil;
        }
    }
    
    return result;
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
    BOOL result = YES;
    NSURL *URL = nil;
    
    if ([string length] > 0)
    {
        URL = [NSURL URLWithUnescapedString:string fallbackScheme:@"http"];
        if (!URL)
        {
            result = NO;
            if (error) *error = nil;
        }
    }
    
    
    // Finish up
    if (result && anObject) *anObject = URL;
    return result;
}

@end
