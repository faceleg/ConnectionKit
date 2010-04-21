//
//  SVSidebarPageletsController.m
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarPageletsController.h"

#import "KTPage.h"
#import "SVGraphic.h"
#import "SVSidebar.h"


@interface SVSidebarPageletsController ()
- (void)_addPagelet:(SVGraphic *)pagelet toSidebarOfDescendantsOfPageIfApplicable:(KTPage *)page;
@end


#pragma mark -


@implementation SVSidebarPageletsController

#pragma mark Init & Dealloc

- (id)initWithSidebar:(SVSidebar *)sidebar;
{
    self = [self init];
    _sidebar = [sidebar retain];
    
    [self setObjectClass:[SVGraphic class]];
    [self setManagedObjectContext:[sidebar managedObjectContext]];
    [self setEntityName:@"Graphic"];
    [self setAvoidsEmptySelection:NO];
    [self setAutomaticallyRearrangesObjects:YES];
    [self setSortDescriptors:[SVGraphic pageletSortDescriptors]];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES],
                             NSRaisesForNotApplicableKeysBindingOption,
                             nil];
    [self bind:NSContentSetBinding toObject:sidebar withKeyPath:@"pagelets" options:options];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self setSortDescriptors:[SVGraphic pageletSortDescriptors]];
    return self;
}

- (void)dealloc
{
    [_sidebar release];
    
    [super dealloc];
}

#pragma mark Managing Content

@synthesize sidebar = _sidebar;

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    [super setManagedObjectContext:managedObjectContext];
    
    //  Setting automaticallyPreparesContent to YES in IB doesn't handle there being no MOC set properly. So we hold off doing the initial fetch until there is a MOC. After that everything seems to work normally.
    if (managedObjectContext && ![self automaticallyPreparesContent])
    {
        [self setAutomaticallyPreparesContent:YES];
        [self fetch:self];
    }
}

#pragma mark Adding and Removing Objects

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index;
{
    SVGraphic *pagelet = object;
    
    
    // Position right
    if (index >= [[self arrangedObjects] count])
    {
        SVGraphic *lastPagelet = [[self arrangedObjects] lastObject];
        [pagelet moveAfterSidebarPagelet:lastPagelet];
    }
    else
    {
        SVGraphic *refPagelet = [[self arrangedObjects] objectAtIndex:index];
        [pagelet moveBeforeSidebarPagelet:refPagelet];
    }
    
    
    // Do the insert
    [super insertObject:object atArrangedObjectIndex:index];
    
    
    // Detach from text attachment
    //[pagelet detachFromBodyText];
}

- (void)addObject:(id)pagelet
{
    // Place at end of the sidebar
    SVGraphic *lastPagelet = [[self arrangedObjects] lastObject];
    [pagelet moveAfterSidebarPagelet:lastPagelet];
    
    
    // Also add to as many descendants as appropriate. Must do it before calling super otherwise inheritablePagelets will be wrong
    [self _addPagelet:pagelet toSidebarOfDescendantsOfPageIfApplicable:[[self sidebar] page]];
    
    
	[super addObject:pagelet];
}

- (void)addPagelet:(SVGraphic *)pagelet toSidebarOfPage:(KTPage *)page;
{
    [self _addPagelet:pagelet toSidebarOfDescendantsOfPageIfApplicable:page];
    [[page sidebar] addPageletsObject:pagelet];
}

- (void)_addPagelet:(SVGraphic *)pagelet
toSidebarOfDescendantsOfPageIfApplicable:(KTPage *)page;
{
    NSSet *inheritablePagelets = [[page sidebar] pagelets];
    
    for (SVSiteItem *aSiteItem in [page childItems])
    {
        // We only care about actual pages
        KTPage *aPage = [aSiteItem pageRepresentation];
        if (!aPage) continue;
        
        
        // It's reasonable to add the pagelet if one of more pagelets from the parent also appear
        SVSidebar *sidebar = [aPage sidebar];
        if ([[sidebar pagelets] intersectsSet:inheritablePagelets] ||
            [inheritablePagelets count] < 1)
        {
            [self addPagelet:pagelet toSidebarOfPage:aPage];
        }
    }
}

- (void)willRemoveObject:(id)object
{
    OBPRECONDITION([object isKindOfClass:[SVGraphic class]]);
    SVGraphic *pagelet = object;
                   
    // Recurse down the page tree removing the pagelet from their sidebars.
    [self removePagelet:pagelet fromSidebarOfPage:(KTPage *)[[self sidebar] page]];
    
    // Delete the pagelet if it no longer appears on any pages
    if ([[pagelet sidebars] count] == 0 && ![pagelet textAttachment])
    {
        [[self managedObjectContext] deleteObject:pagelet];
    }
}

- (void)removePagelet:(SVGraphic *)pagelet fromSidebarOfPage:(KTPage *)page;
{
    // No point going any further unless the page actually contains the pagelet! This can save recursing enourmous chunks of the site outline
    if ([[[page sidebar] pagelets] containsObject:pagelet])
    {
        // Remove from descendants first
        for (SVSiteItem *aSiteItem in [page childItems])
        {
            KTPage *pageRep = [aSiteItem pageRepresentation];
            if (pageRep) [self removePagelet:pagelet fromSidebarOfPage:pageRep];
        }
        
        // Remove from the receiver
        [[page sidebar] removePageletsObject:pagelet];
    }
}

@end
