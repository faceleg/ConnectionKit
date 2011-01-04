//
//  SVIndexPlugIn.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVIndexPlugIn.h"

#import "SVPageProtocol.h"
#import "SVPagesController.h"
#import "SVHTMLContext.h"


@interface SVPlugIn (SVIndexPlugIn)
- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
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
    [super didAddToPage:page];
    
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

- (NSArray *)indexedPages
{
    NSArray *result = nil;
    
    if ( self.indexedCollection )
    {
        NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self.indexedCollection];
        NSArray *arrangedObjects = [controller arrangedObjects];
        
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
        return [[self indexedCollection] performSelector:@selector(identifier)];
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

- (void)writePlaceholderHTML:(id <SVPlugInContext>)context;
{
    [context startElement:@"p"];
    
    if ( self.indexedCollection )
    {
        [context writeText:NSLocalizedString(@"To see the Index, please add indexable pages to the collection.","add pages to collection")];
    }
    else
    {
        [context writeText:NSLocalizedString(@"Please specify the collection to index using the PlugIn Inspector.","set index collection")];
    }
    
    [context endElement];
}

- (void)writeHTML:(id <SVPlugInContext>)context
{
    if ( self.indexedCollection )
    {
        NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self.indexedCollection];
        [context addDependencyForKeyPath:@"arrangedObjects" ofObject:controller];
    }
    
    // add dependencies
    [context addDependencyForKeyPath:@"indexedCollection" ofObject:self];
    [context addDependencyForKeyPath:@"maxItems" ofObject:self];
    [context addDependencyForKeyPath:@"enableMaxItems" ofObject:self];
    
    [super writeHTML:context];
        
    if ( [context isForEditing] )
    {
        if ( ![self.indexedPages count] ) [self writePlaceholderHTML:context];
    }
}

#pragma mark Properties

@synthesize indexedCollection = _collection;
@synthesize enableMaxItems = _enableMaxItems;

@synthesize maxItems = _maxItems;

- (void)dealloc
{
    self.indexedCollection = nil;
    [super dealloc];
}

@end
