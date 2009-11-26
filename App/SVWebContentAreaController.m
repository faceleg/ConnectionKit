//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"

#import "SVWebEditorLoadController.h"
#import "SVLoadingPlaceholderViewController.h"


@implementation SVWebContentAreaController

- (id)init
{
    [super init];
    
    
    // Create controllers
    _webViewController = [[SVWebEditorLoadController alloc] init];
    [_webViewController setDelegate:self];
    [self insertViewController:_webViewController atIndex:0];
    
    
    _sourceViewController = [[NSViewController alloc] initWithNibName:@"HTMLSourceView"
                                                               bundle:nil];
    [self addViewController:_sourceViewController];
    
    
    _placeholderViewController = [[SVLoadingPlaceholderViewController alloc] init];
    [self addViewController:_placeholderViewController];
    
    
    [self setSelectedIndex:0];
    
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    // We don't support loading any properties from a nib (yet), so jump straight to normal initialisation
    return [self init];
}

- (void)dealloc
{
    [_webViewController release];
    [_placeholderViewController release];
    
    [_selectedPages release];
    
    [super dealloc];
}

#pragma mark Pages

- (NSArray *)selectedPages { return _selectedPages; }

- (void)setSelectedPages:(NSArray *)pages
{
    pages = [pages copy];
    [_selectedPages release];
    _selectedPages = pages;
    
    
    // Update subcontrollers
    NSViewController *controller;
    switch ([pages count])
    {
        case 0:
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Nothing Selected", @"Selection placeholder")];
            controller = _placeholderViewController;
            break;
            
        case 1:
            [[[self webViewLoadController] webEditorViewController] setPage:[pages objectAtIndex:0]];
            controller = [self viewControllerForViewType:[self viewType]];
            break;
            
        default:
            [[_placeholderViewController label] setStringValue:NSLocalizedString(@"Multiple Pages Selected", @"Selection placeholder")];
            controller = _placeholderViewController;
            break;
    }
    
    [self setSelectedViewController:controller];
}

#pragma mark View Type

@synthesize viewType = _viewType;
- (void)setViewType:(KTWebViewViewType)type
{
    _viewType = type;
    
    if ([[self selectedPages] count] == 1)
    {
        [self setSelectedViewController:[self viewControllerForViewType:type]];
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

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    BOOL result = YES;
    
    if ([menuItem action] == @selector(selectWebViewViewType:))
    {
        // Tick the selected state
        [menuItem setState:([menuItem tag] == [self viewType])];
        
        // Only allow the user to select standard and source code view for now.
        result = [menuItem tag] == KTStandardWebView || [menuItem tag] == KTSourceCodeView;
    }
    
    return result;
}

- (NSViewController *)viewControllerForViewType:(KTWebViewViewType)viewType;
{
    NSViewController *result;
    switch (viewType)
    {
        case KTStandardWebView:
            result = [self webViewLoadController];
            break;
            
        case KTSourceCodeView:
        case KTPreviewSourceCodeView:
            result = _sourceViewController;
            break;
            
        default:
            result = nil;
    }
    
    return result;
}

#pragma mark View controllers

@synthesize webViewLoadController = _webViewController;

- (void)didSelectViewController;
{
    [super didSelectViewController];
    
    // Inform delegate of change to title
    NSString *title = nil;
    if ([self selectedViewController] == [self webViewLoadController])
    {
        title = [[self webViewLoadController] title];
    }
    [[self delegate] webContentAreaControllerDidChangeTitle:self];
}

#pragma mark Delegate

@synthesize delegate = _delegate;

#pragma mark Inspector

- (id <KSCollectionController>)objectsController;
{
    return [_webViewController selectableObjectsController];
}

#pragma mark Load Delegate

- (void)loadControllerDidChangeTitle:(SVWebEditorLoadController *)controller;
{
    [[self delegate] webContentAreaControllerDidChangeTitle:self];
}

- (void)loadController:(SVWebEditorLoadController *)sender openPage:(KTPage *)page;
{
    // Take advantag of our binding and set that to the desired page. It will then trigger a change in our selected pages (probably)
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
