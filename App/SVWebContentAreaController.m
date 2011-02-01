//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"
#import "SVURLPreviewViewController.h"
#import "SVWebSourceViewController.h"
#import "SVLoadingPlaceholderViewController.h"

#import "KTPage.h"



@implementation SVWebContentAreaController

- (void)prepareContent;
{
    // Create controllers
    _webEditorViewController = [[SVWebEditorViewController alloc] init];
    [_webEditorViewController setDelegate:self];
    [self addViewController:_webEditorViewController];
    
    
    _webPreviewController = [[SVURLPreviewViewController alloc] init];
    [self addViewController:_webPreviewController];
    
    _sourceViewController = [[SVWebSourceViewController alloc] initWithNibName:@"HTMLSourceView"
                                                                        bundle:nil
													   webEditorViewController:_webEditorViewController];
    [self addViewController:_sourceViewController];
    
    
    _placeholderViewController = [[SVLoadingPlaceholderViewController alloc] init];
    [self addViewController:_placeholderViewController];
    
    _multipleSelectionPlaceholder = [[NSViewController alloc] initWithNibName:@"MultipleSelectionPlaceholder" bundle:nil];
    [self addViewController:_multipleSelectionPlaceholder];
    
    [self setSelectedIndex:0];
}

- (id)init
{
    [super init];
    
    
    [self prepareContent];
    
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    [self prepareContent];
    return self;
}

- (void)dealloc
{
    [self unbind:@"selectedPages"];
    
    [_webEditorViewController release];
    [_webPreviewController release];
    [_sourceViewController release];
    [_placeholderViewController release];
    [_multipleSelectionPlaceholder release];
    
    [_selectedPages release];
    
    [super dealloc];
}

#pragma mark General 

- (void)didChangeSelectionOrViewType
{
    // Update subcontrollers
    NSArray *pages = [self selectedPages];
    switch ([pages count])
    {
        case 0:
            [[_placeholderViewController progressIndicator] stopAnimation:self];
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Nothing Selected", @"Selection placeholder")];
            [self setSelectedViewControllerWhenReady:nil];
            break;
            
        case 1:
        {
            // Figure out the right view controller to load
            SVSiteItem *item = [pages objectAtIndex:0];
            
            NSViewController *viewController = [self viewControllerForSiteItem:item];
            
            // Start the load here. Present the view if it's ready; if not wait until it is (or takes too long)
            [self setSelectedViewControllerWhenReady:viewController];
            
            break;
        }
        default:
            [[_placeholderViewController progressIndicator] stopAnimation:self];
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Multiple Pages Selected", @"Selection placeholder")];
            [self setSelectedViewControllerWhenReady:nil];
            break;
    }
}

#pragma mark Pages

- (NSArray *)selectedPages { return _selectedPages; }

- (void)setSelectedPages:(NSArray *)pages
{
    pages = [pages copy];
    [_selectedPages release];
    _selectedPages = pages;
    
    
    NSUndoManager *undoManager = [[self view] undoManager];
    if ([undoManager isUndoing] || [undoManager isRedoing])
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(didChangeSelectionOrViewType)
                                                   object:nil];
        
        [self performSelector:@selector(didChangeSelectionOrViewType) withObject:nil afterDelay:0.0f];
    }
    else
    {
        [self didChangeSelectionOrViewType];
    }
}

- (SVSiteItem *)selectedPage;   // returns nil if more than one page is selected
{
    return ([[self selectedPages] count] == 1 ? [[self selectedPages] objectAtIndex:0] : nil);
}

#pragma mark View Type

@synthesize viewType = _viewType;
- (void)setViewType:(KTWebViewViewType)type
{
    _viewType = type;
    
    if ([[self selectedPages] count] == 1)
    {
        [self didChangeSelectionOrViewType];
    }
}

- (IBAction)selectWebViewViewType:(id)sender;
{
    KTWebViewViewType viewType = [sender tag];
	if (viewType == [self viewType])
	{
		viewType = KTStandardWebView;
	}
	
	[self setViewType:viewType];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem	// WARNING: IF YOU ADD ITEMS HERE, YOU NEED TO SYNCHRONIZE WITH -[KTDocWindowController validateMenuItem:]
{
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));
    BOOL result = YES;		// default to YES so we don't have to do special validation for each action. Some actions might say NO.
    
    if ([menuItem action] == @selector(selectWebViewViewType:))
    {
        // Tick the selected state
        [menuItem setState:([menuItem tag] == [self viewType])];
        
        
        // Only allow the user to select standard and source code view for now.
        SVSiteItem *page = ([[self selectedPages] count] == 1 ?
                        [[self selectedPages] objectAtIndex:0] :
                        nil);
        
        result = ([menuItem tag] == KTStandardWebView ||
                  [menuItem tag] == KTSourceCodeView ||
				  [menuItem tag] == KTPreviewSourceCodeView ||
 				  [menuItem tag] == KTWithoutStylesView ||
                  ([menuItem tag] == KTRSSSourceView && 
                   [page isCollection] &&
                   [[(KTPage *)page collectionSyndicationType] boolValue]));
    }
    
    return result;
}

#pragma mark View controllers

@synthesize webEditorViewController = _webEditorViewController;

- (void)presentLoadingViewController;
{
    [self setSelectedViewController:_placeholderViewController];
    [[_placeholderViewController progressIndicator] startAnimation:self];
}

- (NSViewController *)viewControllerForSiteItem:(SVSiteItem *)item;
{
    NSViewController *result = nil;
    
    
    KTPage *page = [item pageRepresentation];
    if (page)
    {
        switch ([self viewType])
        {
            case KTStandardWebView:
			case KTWithoutStylesView:
           {
                // Figure out the right view controller
                result = [self webEditorViewController];
                break;
            }
            case KTSourceCodeView:
            case KTPreviewSourceCodeView:
            case KTRSSSourceView:
                result = _sourceViewController;
                break;
                
            default:
                result = nil;
        }
    }
    else
    {
        result = _webPreviewController;
    }
    
    return result;
}

#pragma mark Selected View Controller

@synthesize selectedViewControllerWhenReady = _selectedViewControllerWhenReady;
- (void)setSelectedViewControllerWhenReady:(NSViewController *) controller;
{
    // Store
    _selectedViewControllerWhenReady = controller;
    
    
    //  Either the view's ready to appear, or we need to wait until it really is
    if ([controller viewShouldAppear:NO webContentAreaController:self])
    {
        [self setSelectedViewController:controller];
    }
    else
    {
        if ([[self selectedPages] count] == 1)
        {
            [self presentLoadingViewController];
        }
        else
        {
            [self setSelectedViewController:_multipleSelectionPlaceholder];
        }
    }
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark Inspector

- (id <KSCollectionController>)objectsController;
{
    return [[self webEditorViewController] graphicsController];
}

#pragma mark Web Editor View Controller Delegate

- (void)webEditorViewController:(SVWebEditorViewController *)sender openSiteItem:(SVSiteItem *)page;
{
    // Take advantage of our binding and set that to the desired page. It will then trigger a change in our selected pages (probably)
    if (page)
    {
        NSDictionary *bindingInfo = [self infoForBinding:@"selectedPages"];
        if (bindingInfo)
        {
            id object = [bindingInfo objectForKey:NSObservedObjectKey];
            NSString *keyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
            [object setValue:[NSArray arrayWithObject:page] forKeyPath:keyPath];
        }
    }
}

@end


#pragma mark -


@implementation NSViewController (SVSiteItemViewController)

- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller;
{
    return YES;
}

@end

