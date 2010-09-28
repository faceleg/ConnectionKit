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
    NSArray *plugInKeys = [NSArray arrayWithObjects:
                           @"indexedCollection", 
                           @"maxItems", 
                           @"enableMaxItems", 
                           nil];
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


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    
    // add dependencies
    [context addDependencyForKeyPath:@"maxItems" ofObject:self];
    [context addDependencyForKeyPath:@"enableMaxItems" ofObject:self];
    [context addDependencyForKeyPath:@"indexedCollection" ofObject:self];
    [context addDependencyForKeyPath:@"indexedCollection.childPages" ofObject:self];
}


#pragma mark Properties

@synthesize indexedCollection = _collection;
- (void)setIndexedCollection:(id <SVPage>)collection
{
    // when we change indexedCollection, set the containers title to the title of the collection, or to
    // KTPluginUntitledName if collection is nil
    [super setValue:collection forKey:@"indexedCollection"];
    
    if ( collection )
    {
        [self setTitle:[collection title]];
    }
    else
    {
        NSString *defaultTitle = [[self bundle] objectForInfoDictionaryKey:@"KTPluginUntitledName"];
        [self setTitle:defaultTitle];
    }
}


@synthesize enableMaxItems = _enableMaxItems;

@synthesize maxItems = _maxItems;
- (NSUInteger)maxItems
{
    // return 0 if user has disabled maximum
    return (self.enableMaxItems) ? _maxItems : 0;
}

@end
