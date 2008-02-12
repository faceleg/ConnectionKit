//
//  NSDictionary+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

#import "NSDictionary+KTExtensions.h"
#import "Debug.h"

@implementation NSDictionary ( KTExtensions )

+ (id)objectWithClassSpecifiedInDictionary:(NSDictionary *)inDictionary
{
    NSString *className = [inDictionary objectForKey:@"className"];
    
    if ( nil != className ) {
        id object = [[NSClassFromString(className) alloc] init];
        
        if ( nil != object ) {
            [object addEntriesFromDictionary:inDictionary];
            return [object autorelease];
        }
        else {
            LOG((@"NSDictionary+BX: unable to create object from dictionary."));
            return nil;
        }
    }
    
    return nil;
}

- (NSData *)dataUsingNSMacOSRomanStringEncoding
{
    return [[self description] dataUsingEncoding:NSMacOSRomanStringEncoding];
}



@end
