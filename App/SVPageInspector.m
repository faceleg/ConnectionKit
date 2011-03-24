//
//  SVPageInspector.m
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPageInspector.h"

#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "SVGraphic.h"
#import "SVIndexPlugIn.h"
#import "SVFillController.h"
#import "SVMediaRecord.h"
#import "SVRichText.h"
#import "SVSidebar.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "KSIsEqualValueTransformer.h"

#import "NSImage+Karelia.h"

#import <Connection/Connection.h>


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
    
    [self addObserver:self
           forKeyPath:@"inspectedObjectsController.selection.thumbnailSourceGraphic.imageRepresentation"
              options:0
              context:NULL];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"inspectedObjectsController.selection.thumbnailSourceGraphic.imageRepresentation"];

    [super dealloc];
}

#pragma mark View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [oMenuTitleField bind:@"placeholderValue"
                 toObject:self
              withKeyPath:@"inspectedObjectsController.selection.menuTitle"
                  options:nil];
 
		
	// Truncation slider
	[oTruncationController bind:@"maxItemLength" toObject:self withKeyPath:@"inspectedObjectsController.selection.collectionMaxFeedItemLength" options:nil];	
    
    // Setup thumbnail picker
    [oThumbnailController bind:@"fillType" toObject:self withKeyPath:@"inspectedObjectsController.selection.thumbnailType" options:nil];
    [oThumbnailController bind:@"imageMedia" toObject:oSiteItemController withKeyPath:@"thumbnailMedia" options:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thumbnailPickerWillPopUp:) name:NSPopUpButtonWillPopUpNotification object:oThumbnailPicker];
    
    [self updatePickFromPageThumbnail];
}

#pragma mark Navigation Arrows

- (IBAction)chooseNavigationArrowsStyle:(NSPopUpButton *)sender;
{
    // When turning on arrows, make sure the page will show them. #93639
    if ([sender indexOfSelectedItem] > 0)
    {
        [[self inspectedObjectsController] setValue:[NSNumber numberWithBool:YES]
                                         forKeyPath:@"selection.includeInIndex"];
    }
}

#pragma mark Comments

- (IBAction)toggleComments:(NSButton *)sender;
{
    if ([sender state] == NSOnState)
    {
        if (![[[self inspectedObjectsController] valueForKeyPath:@"selection.master.commentsProvider"] boolValue])
        {
            [NSApp sendAction:@selector(configureComments:) to:nil from:self];
        }
    }
}

#pragma mark Timestamp

- (IBAction)selectTimestampType:(NSPopUpButton *)sender;
{
    //  When the user selects a timestamp type, want to treat it as if they hit the checkbox too
    if (![showTimestampCheckbox integerValue]) [showTimestampCheckbox performClick:self];
}

#pragma mark Presentation

- (CGFloat)contentHeightForViewInInspectorForTabViewItem:(NSTabViewItem *)tabViewItem;
{
    NSString *identifier = [tabViewItem identifier];
    
    if ([identifier isEqualToString:@"page"])
    {
        return 476.0f;
    }
    else if ([identifier isEqualToString:@"appearance"])
    {
        return 420.0f;
    }
    else if ([identifier isEqualToString:@"collection"])
    {
        return 400.0f;
    }
    else
    {
        return [super contentHeightForViewInInspectorForTabViewItem:tabViewItem];
    }
}

#pragma mark Thumbnail

- (void)updatePickFromPageThumbnail
{
    [oThumbnailController performSelector:_cmd];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"inspectedObjectsController.selection.thumbnailSourceGraphic.imageRepresentation"])
    {
        //[self updatePickFromPageThumbnail];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)addGraphicToThumbnailPickerIfSuitable:(SVGraphic *)graphic;
{
    if ([graphic imageRepresentation])
    {
        CGImageSourceRef source = IMB_CGImageSourceCreateWithImageItem(graphic, NULL);
        if (source)
        {
            NSImage *thumnailImage = [[NSImage alloc]
                                      initWithThumbnailFromCGImageSource:source
                                      maxPixelSize:32];
            CFRelease(source);
            
            if (thumnailImage)
            {
                [oThumbnailPicker addItemWithTitle:[graphic title]];
                [oThumbnailPicker.lastItem setRepresentedObject:graphic];
                [oThumbnailPicker.lastItem setImage:thumnailImage];
                [thumnailImage release];
            }
        }
    }
}

- (void)thumbnailPickerWillPopUp:(NSNotification *)notification
{
    // Dump the old menu. Curiously, NSMenu has no easy way to do this.
    [oThumbnailPicker removeAllItems];
    [oThumbnailPicker addItemWithTitle:@""];    // won't appear, as is a pulldown
    
    
    // Populate with available choices
    KTPage *page = [(NSObject *)[self inspectedObjectsController] valueForKeyPath:@"selection.self"];
    
    for (SVTextAttachment *anAttachment in [[page article] orderedAttachments])
    {
        SVGraphic *graphic = [anAttachment graphic];
        [self addGraphicToThumbnailPickerIfSuitable:graphic];
    }
    
    if ([[page showSidebar] boolValue])
    {
        for (SVGraphic *aPagelet in [[page sidebar] pagelets])
        {
            [self addGraphicToThumbnailPickerIfSuitable:aPagelet];
        }
    }
    
    
    // Placeholder
    if ([oThumbnailPicker numberOfItems] <= 1)
    {
        [oThumbnailPicker addItemWithTitle:NSLocalizedString(@"No media found directly on page", "Page thumbnail picker placeholder")];
        [[oThumbnailPicker lastItem] setEnabled:NO];
    }
    
    
    // First & Last child
    if ([page isCollection])
    {
        [[oThumbnailPicker menu] addItem:[NSMenuItem separatorItem]];
        
        
        // First page, including thumb
        [oThumbnailPicker addItemWithTitle:NSLocalizedString(@"First Child Page", "menu item")];
        [[oThumbnailPicker lastItem] setTag:SVThumbnailTypeFirstChildItem];
        
        SVPageThumbnailHTMLContext *context = [[SVPageThumbnailHTMLContext alloc] init];
        [context setDelegate:self];
        
        [page writeThumbnailImage:context
                             type:SVThumbnailTypeFirstChildItem
                            width:32
                           height:32
                          options:0];
        
        [context release];
        
        
        // Last child
        [oThumbnailPicker addItemWithTitle:NSLocalizedString(@"Last Child Page", "menu item")];
        [[oThumbnailPicker lastItem] setTag:SVThumbnailTypeLastChildItem];
        
        context = [[SVPageThumbnailHTMLContext alloc] init];
        [context setDelegate:self];
        
        [page writeThumbnailImage:context
                             type:SVThumbnailTypeLastChildItem
                            width:32
                           height:32
                          options:0];
        
        [context release];
    }
    
    
    SVThumbnailType fillType = [[oThumbnailController fillType] integerValue];
    if (fillType > SVThumbnailTypePickFromPage)
    {
        [oThumbnailPicker selectItemWithTag:fillType];
    }
    else
    {
        [oThumbnailPicker selectItemWithRepresentedObject:[page thumbnailSourceGraphic]];
    }
}

- (void)pageThumbnailHTMLContext:(SVPageThumbnailHTMLContext *)context didAddMedia:(SVMedia *)media;
{
    NSImage *result;
    if ([media mediaData])
    {
        result = [[NSImage alloc] initWithData:[media mediaData]];
    }
    else
    {
        result = [[NSImage alloc] initWithThumbnailOfURL:[media mediaURL] maxPixelSize:32];
    }
    
    [[oThumbnailPicker lastItem] setImage:result];
    [result release];
}

- (void)pageThumbnailHTMLContext:(SVPageThumbnailHTMLContext *)context
                   addDependency:(KSObjectKeyPathPair *)dependency;
{   // ignored
}

- (IBAction)pickThumbnailFromPage:(NSPopUpButton *)sender;
{
    NSMenuItem *selectedItem = [sender selectedItem];
    SVGraphic *graphic = [selectedItem representedObject];
    
    if (graphic)
    {
        [oThumbnailController setFillType:[NSNumber numberWithInteger:SVThumbnailTypePickFromPage]];
        [[self inspectedObjectsController] setValue:graphic forKeyPath:@"selection.thumbnailSourceGraphic"];
    }
    else
    {
        // They chose a different type
        [oThumbnailController setFillType:[NSNumber numberWithInteger:[sender selectedTag]]];
    }
    
    [oThumbnailController fillTypeChosen:sender];
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
    
    
    // Sidebar pagelets
    [oSidebarPageletsTable setNeedsDisplayInRect:[oSidebarPageletsTable rectOfColumn:[oSidebarPageletsTable columnWithIdentifier:@"showPagelet"]]];
    
    if ([[self inspectedObjectsController] respondsToSelector:@selector(convertToCollectionControlTitle)])
    {
        NSString *title = [[self inspectedObjectsController] valueForKey:@"convertToCollectionControlTitle"];
        [_convertToCollectionButton setTitle:title];
        [_convertToRegularPageButton setTitle:title];
    }
    
    
    // Thumbnail
    [self updatePickFromPageThumbnail];
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
            [[oSidebarPageletsController class] addPagelet:pagelet toSidebarOfPage:aPage];
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

#pragma mark Archives

- (void)addArchivePageletForCollectionIfNeeded:(KTPage *)collection
{
    SVSidebarPageletsController *sidebarController = [[SVSidebarPageletsController alloc] initWithPageletsInSidebarOfPage:collection];
    
    [sidebarController bindContentToPage];
    [sidebarController autorelease];

    
    // Is there already an archive pagelet for this? If so, do nothing
    for (SVGraphic *aGraphic in [sidebarController arrangedObjects])
    {
        if ([aGraphic respondsToSelector:@selector(plugIn)] &&
            [[aGraphic performSelector:@selector(plugInIdentifier)] isEqualToString:@"sandvox.CollectionArchiveElement"])
        {
            return;
        }
    }
    
    
    // Create the archive
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:@"sandvox.CollectionArchiveElement"];
    SVGraphic *pagelet = [factory insertNewGraphicInManagedObjectContext:
                          [collection managedObjectContext]];
    
    [pagelet setShowsTitle:YES];
    
    [sidebarController addObject:pagelet];
}

- (IBAction)toggledArchives:(NSButton *)sender;
{
    switch ([sender state])
    {
        case NSOnState:
        {
            NSArray *pages = [self inspectedObjects];
            for (KTPage *page in pages)
            {
                [self addArchivePageletForCollectionIfNeeded:page];
            }
            break;
        }
            
        case NSOffState:
        {
            // Remove any corresponding archive graphics
            NSArray *pages = [self inspectedObjects];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:
                                      @"plugInIdentifier == 'sandvox.CollectionArchiveElement' && indexedCollection IN %@",
                                      pages];
            
            NSArray *archiveGraphics = [[[pages lastObject] managedObjectContext]
                                        fetchAllObjectsForEntityForName:@"PlugInGraphic"
                                        predicate:predicate
                                        error:NULL];
            
            for (NSManagedObject *anArchive in archiveGraphics)
            {
                // Possibly a sidebar pagelets controller should be asked to do this, but no harm at present
                [[anArchive managedObjectContext] deleteObject:anArchive];
            }
        }
            
        default:
            break;
    }
}

@end
