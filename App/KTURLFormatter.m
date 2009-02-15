//
//  KTURLFormatter.m
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTURLFormatter.h"


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
            result = NO;
        }
    }
    
    return result;
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
    BOOL result = YES;
    NSURL *URL = nil;
    
    if (string && ![string isEqualToString:@""])
    {
        URL = [NSURL URLWithString:string];
        if (!URL)
        {
            result = NO;
            if (error) *error = nil;
        }
    }
    
    if (result && anObject)
    {
        *anObject = URL;
    }
        
    return result;
}

@end
