//
//  SVPageInspector.m
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageInspector.h"

#import "KTDocument.h"
#import "KTPage.h"
#import "SVGraphic.h"
#import "SVMediaRecord.h"
#import "SVSidebar.h"
#import "SVSidebarPageletsController.h"

#import "KSIsEqualValueTransformer.h"


@implementation SVPageInspector

+ (void) initialize;
{
    KSIsEqualValueTransformer *transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInteger:1]];
    [transformer setNegatesResult:YES];
    [NSValueTransformer setValueTransformer:transformer forName:@"SVIsCustomThumbnail"];
    [transformer release];
    
    transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInteger:2]];
    [transformer setNegatesResult:YES];
    [KSIsEqualValueTransformer setValueTransformer:transformer forName:@"SVIsPickFromPageThumbnail"];
    [transformer release];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mocDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:nil];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

#pragma mark View

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

#pragma mark Thumbnail

- (IBAction)chooseCustomThumbnail:(NSButton *)sender;
{
    KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        SVMediaRecord *media = [SVMediaRecord mediaWithURL:[panel URL]
                                                entityName:@"Thumbnail"
                            insertIntoManagedObjectContext:[document managedObjectContext]
                                                     error:NULL];
        
        [(NSObject *)[self inspectedObjectsController] replaceMedia:media
                                                         forKeyPath:@"selection.customThumbnail"];
    }
}

#pragma mark Sidebar Pagelets

- (void)mocDidChange:(NSNotification *)notification
{
    //  Refresh whenever the context changes. (Inherited behaviour only refreshes when selection changes)
    if ([notification object] == [(id)[self inspectedObjectsController] managedObjectContext])
    {
        [self refresh];
    }
}

- (void)refresh
{
    [super refresh];
    
    [oSidebarPageletsTable setNeedsDisplayInRect:[oSidebarPageletsTable rectOfColumn:[oSidebarPageletsTable columnWithIdentifier:@"showPagelet"]]];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    id result = nil;
    
    if ([[aTableColumn identifier] isEqualToString:@"showPagelet"])
    {
        // Build up the list of pagelets on all the pages.
        NSArray *siteItems = [self inspectedObjects];
        NSCountedSet *pagelets = [[NSCountedSet alloc] init];
        for (SVSiteItem *aSiteItem in siteItems)
        {
            @try    // must account for items which don't support sidebar pagelets
            {
                NSSet *itemPagelets = [aSiteItem valueForKeyPath:@"sidebar.pagelets"];
                if (itemPagelets != NSNotApplicableMarker) [pagelets unionSet:itemPagelets];
            }
            @catch (NSException *exception)
            {
                if (![[exception name] isEqualToString:NSUndefinedKeyException]) 
                {
                    @throw exception;
                }
            }
        }
        
        
        // The selection state depends on how many times it appears
        SVGraphic *pagelet = [[oSidebarPageletsController arrangedObjects]
                              objectAtIndex:rowIndex];
        
        NSUInteger count = [pagelets countForObject:pagelet];
        [pagelets release];
        
        if (count == 0)
        {
            result = [NSNumber numberWithInteger:NSOffState];
        }
        else if (count == [siteItems count])
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
    
    
    SVGraphic *pagelet = [[oSidebarPageletsController arrangedObjects]
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
