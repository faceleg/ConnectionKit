//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"
#import "SVWebEditorLoadController.h"


@implementation SVWebContentAreaController

- (id)init
{
    [super init];
    
    _webViewController = [[SVWebEditorLoadController alloc] init];
    [_webViewController setDelegate:self];
    [self insertViewController:_webViewController atIndex:0];
    
    _placeholderViewController = [[NSViewController alloc] initWithNibName:@"SelectionPlaceholder"
                                                                    bundle:nil];
    [self insertViewController:_placeholderViewController atIndex:1];
    
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
            [_placeholderViewController setTitle:NSLocalizedString(@"Nothing Selected", @"Selection placeholder")];
            controller = _placeholderViewController;
            break;
            
        case 1:
            [[self webViewLoadController] setPage:[pages objectAtIndex:0]];
            controller = [self webViewLoadController];
            break;
            
        default:
            [_placeholderViewController setTitle:NSLocalizedString(@"Multiple Pages Selected", @"Selection placeholder")];
            controller = _placeholderViewController;
            break;
    }
    
    [self setSelectedViewController:controller];
}

#pragma mark View controllers

@synthesize webViewLoadController = _webViewController;

- (void)setSelectedIndex:(NSUInteger)index;
{
    [super setSelectedIndex:index];
    
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
