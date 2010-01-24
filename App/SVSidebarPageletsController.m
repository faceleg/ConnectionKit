//
//  SVSidebarPageletsController.m
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarPageletsController.h"

#import "KTPage.h"
#import "SVPagelet.h"
#import "SVSidebar.h"


@interface SVSidebarPageletsController ()
- (void)_addPagelet:(SVPagelet *)pagelet toSidebarOfDescendantsOfPageIfApplicable:(KTAbstractPage *)page;
- (void)_removePagelet:(SVPagelet *)pagelet fromPageAndDescendants:(KTAbstractPage *)page;
@end


#pragma mark -


@implementation SVSidebarPageletsController

- (id)initWithSidebar:(SVSidebar *)sidebar;
{
    self = [self init];
    _sidebar = [sidebar retain];
    
    [self setObjectClass:[SVPagelet class]];
    [self setManagedObjectContext:[sidebar managedObjectContext]];
    [self setEntityName:@"Pagelet"];
    [self setAvoidsEmptySelection:NO];
    [self setSortDescriptors:[SVPagelet pageletSortDescriptors]];
    
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
    [self setSortDescriptors:[SVPagelet pageletSortDescriptors]];
    return self;
}

- (void)dealloc
{
    [_sidebar release];
    
    [super dealloc];
}

@synthesize sidebar = _sidebar;

- (void)addObject:(id)pagelet
{
    // Place at end of the sidebar
    SVPagelet *lastPagelet = [[self arrangedObjects] lastObject];
    [pagelet moveAfterPagelet:lastPagelet];
    
    
    // Also add to as many descendants as appropriate. Must do it before calling super otherwise inheritablePagelets will be wrong
    [self _addPagelet:pagelet toSidebarOfDescendantsOfPageIfApplicable:[[self sidebar] page]];
    
    
	[super addObject:pagelet];
}

- (void)_addPagelet:(SVPagelet *)pagelet
toSidebarOfDescendantsOfPageIfApplicable:(KTAbstractPage *)page;
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
            [self _addPagelet:pagelet toSidebarOfDescendantsOfPageIfApplicable:aPage];
            [sidebar addPageletsObject:pagelet];
        }
    }
}

- (void)willRemoveObject:(id)object
{
    OBPRECONDITION([object isKindOfClass:[SVPagelet class]]);
    SVPagelet *pagelet = object;
                   
    // Recurse down the page tree removing the pagelet from their sidebars.
    [self _removePagelet:pagelet fromPageAndDescendants:[[self sidebar] page]];
    
    // Delete the pagelet if it no longer appears on any pages
    if ([[pagelet sidebars] count] == 0 && ![pagelet callout])
    {
        [[self managedObjectContext] deleteObject:pagelet];
    }
}

- (void)_removePagelet:(SVPagelet *)pagelet fromPageAndDescendants:(KTAbstractPage *)page;
{
    // No point going any further unless the page actually contains the pagelet! This can save recursing enourmous chunks of the site outline
    if ([[[page sidebar] pagelets] containsObject:pagelet])
    {
        // Remove from descendants first
        for (SVSiteItem *aSiteItem in [page childItems])
        {
            KTPage *pageRep = [aSiteItem pageRepresentation];
            if (pageRep) [self _removePagelet:pagelet fromPageAndDescendants:pageRep];
        }
        for (KTAbstractPage *anArchivePage in [page archivePages])
        {
            [self _removePagelet:pagelet fromPageAndDescendants:anArchivePage];
        }
        
        // Remove from the receiver
        [[page sidebar] removePageletsObject:pagelet];
    }
}

@end
