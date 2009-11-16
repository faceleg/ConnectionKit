// 
//  SVPagelet.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPagelet.h"

#import "KTPage.h"
#import "SVPageletBody.h"
#import "SVSidebar.h"

#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"


@interface SVPagelet ()
@property(nonatomic, retain, readwrite) SVPageletBody *body;
@end


#pragma mark -


@implementation SVPagelet 

#pragma mark Initialization

+ (SVPagelet *)pageletWithManagedObjectContext:(NSManagedObjectContext *)moc;
{
	OBPRECONDITION(moc);
	
	
    // Create the pagelet
	SVPagelet *result = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
													  inManagedObjectContext:moc];
	OBASSERT(result);
	
    
	return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // UID
    [self setPrimitiveValue:[NSString shortUUIDString] forKey:@"elementID"];
    
    
    // Create a corresponding content object
    SVPageletBody *content = [NSEntityDescription
                                 insertNewObjectForEntityForName:@"PageletBody"
                                 inManagedObjectContext:[self managedObjectContext]];
    
    [self setBody:content];
}

#pragma mark Properties

@dynamic titleHTMLString;
@dynamic body;
@dynamic showBorder;

#pragma mark Sidebar

@dynamic sidebars;

- (void)moveBeforePagelet:(SVPagelet *)pagelet
{
    OBPRECONDITION(pagelet);
    
    NSArray *pagelets = [[self class] sortedPageletsInManagedObjectContext:[self managedObjectContext]];
    
    // Locate after pagelet
    NSUInteger index = [pagelets indexOfObject:pagelet];
    OBASSERT(index != NSNotFound);
    
    // Set our sort key to match
    NSNumber *pageletSortKey = [pagelet sidebarSortKey];
    OBASSERT(pageletSortKey);
    NSInteger previousSortKey = [pageletSortKey integerValue] - 1;
    [self setSidebarSortKey:[NSNumber numberWithInteger:previousSortKey]];
    
    // Bump previous pagelets along as needed
    for (NSUInteger i = index; i > 0; i--)  // odd handling of index so we can use an *unsigned* integer
    {
        SVPagelet *previousPagelet = [pagelets objectAtIndex:(i - 1)];
        if (previousPagelet != self)    // don't want to accidentally process self twice
        {
            previousSortKey--;
            
            if ([[previousPagelet sidebarSortKey] integerValue] > previousSortKey)
            {
                [previousPagelet setSidebarSortKey:[NSNumber numberWithInteger:previousSortKey]];
            }
            else
            {
                break;
            }
        }
    }
}

- (void)moveAfterPagelet:(SVPagelet *)pagelet;
{
    OBPRECONDITION(pagelet);
    
    NSArray *pagelets = [[self class] sortedPageletsInManagedObjectContext:[self managedObjectContext]];
    
    // Locate after pagelet
    NSUInteger index = [pagelets indexOfObject:pagelet];
    OBASSERT(index != NSNotFound);
    
    // Set our sort key to match
    NSNumber *pageletSortKey = [pagelet sidebarSortKey];
    OBASSERT(pageletSortKey);
    NSInteger nextSortKey = [pageletSortKey integerValue] + 1;
    [self setSidebarSortKey:[NSNumber numberWithInteger:nextSortKey]];
    
    // Bump following pagelets along as needed
    for (NSUInteger i = index+1; i < [pagelets count]; i++)
    {
        SVPagelet *nextPagelet = [pagelets objectAtIndex:i];
        if (nextPagelet != self)    // don't want to accidentally process self twice
        {
            nextSortKey++;
            
            if ([[nextPagelet sidebarSortKey] integerValue] < nextSortKey)
            {
                [nextPagelet setSidebarSortKey:[NSNumber numberWithInteger:nextSortKey]];
            }
            else
            {
                break;
            }
        }
    }
}

@dynamic sidebarSortKey;

#pragma mark Sorting

+ (NSArray *)pageletSortDescriptors
{
    static NSArray *result;
    if (!result)
    {
        result = [NSSortDescriptor sortDescriptorArrayWithKey:@"sidebarSortKey"
                                                             ascending:YES];
        [result retain];
        OBASSERT(result);
    }
    
    return result;
}

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Pagelet"
                                   inManagedObjectContext:context]];
    [request setSortDescriptors:[self pageletSortDescriptors]];
    
    NSArray *result = [context executeFetchRequest:request error:NULL];
    
    // Tidy up
    [request release];
    return result;
}

+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;
{
    NSArray *sortDescriptors = [self pageletSortDescriptors];
    NSArray *result = [[pagelets allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

@end
