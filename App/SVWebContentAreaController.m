//
//  SVDocContentViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentAreaController.h"
#import "SVWebViewLoadController.h"


@implementation SVWebContentAreaController

- (id)init
{
    [super init];
    
    _webViewController = [[SVWebViewLoadController alloc] init];
    [_webViewController setDelegate:self];
    
    _placeholderViewController = [[NSViewController alloc] initWithNibName:@"SelectionPlaceholder"
                                                                    bundle:nil];
    
    [self setViewControllers:[NSArray arrayWithObjects:
                              _webViewController,
                              _placeholderViewController,
                              nil]
               selectedIndex:0];
    
    return self;
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

#pragma mark Load Delegate

- (void)loadController:(SVWebViewLoadController *)sender openPage:(KTPage *)page;
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
