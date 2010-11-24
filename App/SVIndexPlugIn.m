//
//  SVIndexPlugIn.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIndexPlugIn.h"

#import "SVPageProtocol.h"
#import "SVPagesController.h"
#import "SVHTMLContext.h"


@interface SVIndexPlugIn ()
@property(nonatomic, retain) NSArrayController *indexablePagesController;
@end


#pragma mark -


@implementation SVIndexPlugIn

- (void)awakeFromNew
{
    [super awakeFromNew];
    self.enableMaxItems = YES;
    self.maxItems = 10;
}

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
    [self setWidth:nil height:nil];
}


#pragma mark Indexed Pages

// this needs to be adjusted to return only those pages marked as indexable by parent
// but we need to be KVO-compliant and so need a controller to vend this array?
- (NSArray *)indexablePagesOfCollection
{
//    NSArray *result = nil;
//    if ( self.enableMaxItems && self.maxItems > 0 )
//    {
//        NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.maxItems];
//        NSUInteger numberOfChildPages = [[self.indexedCollection childPages] count];
//        NSUInteger arrayMax = (numberOfChildPages < self.maxItems) ? numberOfChildPages : self.maxItems;
//        for ( NSUInteger i=0; i<arrayMax; i++ )
//        {
//            id<SVPage> childPage = [[self.indexedCollection childPages] objectAtIndex:i];
//            [array addObject:childPage];
//        }
//        result = [NSArray arrayWithArray:array];
//    }
//    else
//    {
//        result = self.indexedCollection.childPages;
//    }
//    return result;
    
    NSArray *result = nil;
    
    if ( self.indexablePagesController )
    {
        NSArray *arrangedObjects = [self.indexablePagesController arrangedObjects];
        if ( self.enableMaxItems && self.maxItems > 0 )
        {
            NSUInteger arrayMax = ([arrangedObjects count] < self.maxItems) ? [arrangedObjects count] : self.maxItems;
            NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, arrayMax)];
            result = [arrangedObjects objectsAtIndexes:indexes];
        }
        else
        {
            result = arrangedObjects;
        }

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
    // set up indexable pages controller
    if ( self.indexedCollection )
    {
        //FIXME: should we really be hanging on to the controller in an ivar? if not, how do we reference it outside this method?
        //FIXME: remove reference to KTPage someday
        self.indexablePagesController = [SVPagesController controllerWithPagesToIndexInCollection:(KTPage *)self.indexedCollection];
        [context addDependencyForKeyPath:@"arrangedObjects" ofObject:self.indexablePagesController];
    }
    
    // add dependencies
    [context addDependencyForKeyPath:@"indexedCollection" ofObject:self];
    [context addDependencyForKeyPath:@"maxItems" ofObject:self];
    [context addDependencyForKeyPath:@"enableMaxItems" ofObject:self];
    
    [super writeHTML:context];
        
    if ( [context isForEditing] )
    {
        if ( self.indexedCollection )
        {
            if ( ![self.indexablePagesOfCollection count] )
            {
                [[context HTMLWriter] startElement:@"p"];
                [[context HTMLWriter] writeText:NSLocalizedString(@"To see the Index, please add indexable pages to the collection.","add pages to collection")];
                [[context HTMLWriter] endElement];
            }
        }
        else
        {
            [[context HTMLWriter] startElement:@"p"];
            [[context HTMLWriter] writeText:NSLocalizedString(@"Please specify the collection to index using the PlugIn Inspector.","set index collectionb")];
            [[context HTMLWriter] endElement];
        }
    }
}


#pragma mark Properties

@synthesize indexedCollection = _collection;
@synthesize enableMaxItems = _enableMaxItems;

@synthesize maxItems = _maxItems;
- (NSUInteger)maxItems
{
    // return 0 if user has disabled maximum
    return (self.enableMaxItems) ? _maxItems : 0;
}

@synthesize indexablePagesController = _indexablePagesController;

- (void)dealloc
{
    self.indexablePagesController = nil;
    self.indexedCollection = nil;
    [super dealloc];
}

@end
