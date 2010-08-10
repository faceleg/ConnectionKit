//
//  SVIndexPlugIn.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIndexPlugIn.h"

#import "SVPageProtocol.h"


@implementation SVIndexPlugIn

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // Indexes should generally fill full width
    [[self container] setContainerWidth:nil];
}

@synthesize indexedCollection = _collection;

#pragma mark Serialization

+ (NSArray *)plugInKeys;
{
    NSArray *result = [[super plugInKeys] arrayByAddingObject:@"indexedCollection"];
    OBPOSTCONDITION(result);
    return result;
}

- (id)serializedValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"indexedCollection"])
    {
        return [[self indexedCollection] identifier];
    }
    else
    {
        return [super serializedValueForKey:key];
    }
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;
{
    if ([key isEqualToString:@"indexedCollection"])
    {
        [self setIndexedCollection:(serializedValue ?
                                    [self pageWithIdentifier:serializedValue] :
                                    nil)];
    }
    else
    {
        [super setSerializedValue:serializedValue forKey:key];
    }
}

@end
