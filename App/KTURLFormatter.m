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
        
        
        // Does the URL have no useful resource specified? If so, generate nil URL
        if (URL)
        {
            NSString *resource = [URL resourceSpecifier];
            if ([resource length] == 0 ||
                [resource isEqualToString:@"/"] ||
                [resource isEqualToString:@"//"])
            {
                URL = nil;
            }
        }
        
        // URLs should also really have a host and a path
        if (URL)
        {
            NSString *host = [URL host];
			NSString *path = [URL path];
			if ((!host && !path) ||
				(host && NSNotFound == [host rangeOfString:@"."].location))
			{
				URL = nil;
            }
        }
    }
    
    
    // Finish up
    if (result && anObject) *anObject = URL;
    return result;
}

- (NSURL *)URLFromString:(NSString *)string;
{
    NSURL *result = nil;
    
    NSURL *URL;
    if ([self getObjectValue:&URL forString:string errorDescription:NULL]) result = URL;
    
    return result;
}

@end
