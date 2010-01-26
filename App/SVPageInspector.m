//
//  SVPageInspector.m
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageInspector.h"

#import "KTPage.h"
#import "SVPagelet.h"
#import "SVSidebar.h"
#import "SVSidebarPageletsController.h"


@implementation SVPageInspector

- (void)loadView
{
    [super loadView];
    
    [oMenuTitleField bind:@"placeholderValue"
                 toObject:self
              withKeyPath:@"inspectedObjectsController.selection.menuTitle"
                  options:nil];
}

- (IBAction)selectTimestampType:(NSPopUpButton *)sender;
{
    //  When the user selects a timestamp type, want to treat it as if they hit the checkbox too
    if (![showTimestampCheckbox integerValue]) [showTimestampCheckbox performClick:self];
}

#pragma mark Sidebar Pagelets

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    id result = nil;
    
    if ([[aTableColumn identifier] isEqualToString:@"showPagelet"])
    {
        SVPagelet *pagelet = [[oSidebarPageletsController arrangedObjects]
                              objectAtIndex:rowIndex];
        
        
        // Build up the list of pagelets on all the pages.
        NSArray *pages = [self inspectedObjects];
        NSCountedSet *pagelets = [[NSCountedSet alloc] init];
        for (KTPage *aPage in pages)
        {
            [pagelets unionSet:[[aPage sidebar] pagelets]];
        }
        
        
        // The selection state depends on how many times it appears
        NSUInteger count = [pagelets countForObject:pagelet];
        [pagelets release];
        
        if (count == 0)
        {
            result = [NSNumber numberWithInteger:NSOffState];
        }
        else if (count == [pages count])
        {
            result = [NSNumber numberWithInteger:NSOnState];
        }       
        else
        {
            result = [NSNumber numberWithInteger:NSMixedState];
        }
    }
    
    return result;
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex
{
    if (![[aTableColumn identifier] isEqualToString:@"showPagelet"]) return;
    
    
    SVPagelet *pagelet = [[oSidebarPageletsController arrangedObjects]
                          objectAtIndex:rowIndex];
    
    NSArray *pages = [self inspectedObjects];
    if ([anObject boolValue])
    {
        for (KTPage *aPage in pages)
        {
            [oSidebarPageletsController addPagelet:pagelet toSidebarOfPage:aPage];
        }
    }
    else
    {
        for (KTPage *aPage in pages)
        {
            [oSidebarPageletsController removePagelet:pagelet fromSidebarOfPage:aPage];
        }
    }
}

@end
