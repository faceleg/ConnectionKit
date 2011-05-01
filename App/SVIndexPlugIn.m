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


@interface SVIndexPlugIn ()
@property(nonatomic, retain, readwrite) id <SVPage> indexedCollection;
@end



#pragma mark -


@implementation SVIndexPlugIn

- (void)awakeFromNew
{
    [super awakeFromNew];
    self.enableMaxItems = NO;
    self.maxItems = 10;
}

- (void)pageDidChange:(id <SVPage>)page;
{
    [super pageDidChange:page];
    
    if (![self indexedCollection])
    {
        if ([page isCollection]) 
        {
            [self setIndexedCollection:page];
        }
        else
        {
            [self setIndexedCollection:[page parentPage]];
        }
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
        NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self.indexedCollection bind:NO];
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
                           @"maxItems", 
                           @"enableMaxItems", 
                           nil];
    NSArray *result = [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
    OBPOSTCONDITION(result);
    return result;
}

#pragma mark HTML Generation

- (NSString *)placeholderString;
{
    NSString *result;
    if ( self.indexedCollection )
    {
        result = NSLocalizedString(@"To see the Index, please add indexable pages to the collection.",
                                        "add pages to collection");
    }
    else
    {
        result = NSLocalizedString(@"Use the Inspector to connect this index to a collection.",
                                        "set index collection");
    }
    
    return result;
}

- (void)writeHTML:(id <SVPlugInContext>)context
{
    if ( self.indexedCollection )
    {
        NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self.indexedCollection bind:YES];
        [context addDependencyForKeyPath:@"arrangedObjects" ofObject:controller];
        
        if ([[controller arrangedObjects] count])
        {
            [super writeHTML:context];
        }
    }
    
    // add dependencies
    [context addDependencyForKeyPath:@"indexedCollection" ofObject:self];
}

#pragma mark Properties

- (id <SVPage>)indexedCollection; { return [self valueForKeyPath:@"container.indexedCollection"]; }
- (void)setIndexedCollection:(id <SVPage>)collection; { [self setValue:collection forKeyPath:@"container.indexedCollection"]; }
+ (NSSet *)keyPathsForValuesAffectingIndexedCollection; { return [NSSet setWithObject:@"container.indexedCollection"]; }

@synthesize enableMaxItems = _enableMaxItems;

@synthesize maxItems = _maxItems;

- (void)dealloc
{
    self.indexedCollection = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Awakenings

- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
	NSInteger maxItems = 0;
    
    id collectionMaxIndexItems = [properties objectForKey:@"collectionMaxIndexItems"];
	if (collectionMaxIndexItems)
	{
		maxItems = (collectionMaxIndexItems == [NSNull null] ? 0 : [collectionMaxIndexItems intValue]);
	}
	else if (nil != [properties objectForKey:@"maxItems"])
	{
		maxItems = [[properties objectForKey:@"maxItems"] intValue];
	}
	if (maxItems > 0)
	{
		self.enableMaxItems = YES;
		self.maxItems = maxItems;
	}
	else
	{
		self.enableMaxItems = NO;
		self.maxItems = 20;		// give it a reasonable value
	}
}

@end
