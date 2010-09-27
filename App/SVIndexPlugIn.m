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

- (void)didAddToPage:(id <SVPage>)page;
{
    if (![self indexedCollection])
    {
        if ([page isCollection]) [self setIndexedCollection:page];
    }
}

@synthesize indexedCollection = _collection;
@synthesize maxItems = _maxItems;

#pragma mark Metrics

- (void)makeOriginalSize;
{
    [self setWidth:0];
    [self setHeight:0];
}

#pragma mark Child Pages

- (NSArray *)iteratablePagesOfCollection
{
    NSArray *result = nil;
    if ( self.maxItems > 0 )
    {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.maxItems];
        for ( NSUInteger i=0; i<self.maxItems; i++ )
        {
            id<SVPage> childPage = [self.indexedCollection.childPages objectAtIndex:i];
            [array addObject:childPage];
        }
        result = [NSArray arrayWithArray:array];
    }
    else
    {
        result = self.indexedCollection.childPages;
    }
    return result;
}

#pragma mark Serialization

+ (NSArray *)plugInKeys;
{
    NSArray *plugInKeys = [NSArray arrayWithObjects:@"indexedCollection", @"maxItems", nil];
    NSArray *result = [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
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
