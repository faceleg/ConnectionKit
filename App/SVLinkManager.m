//
//  SVLinkManager.m
//  Sandvox
//
//  Created by Mike on 12/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkManager.h"
#import "SVLink.h"

#import "KSDocumentController.h"
#import "SVInspector.h"
#import "SVLinkInspector.h"

#import "NSAppleScript+Karelia.h"


@interface SVLinkManager ()
@property(nonatomic, retain, readwrite) SVLink *selectedLink;
@property(nonatomic, readwrite, getter=isEditable) BOOL editable;
- (void)refreshLinkInspectors;
@end


@implementation SVLinkManager

#pragma mark Shared Manager

+ (SVLinkManager *)sharedLinkManager
{
    static SVLinkManager *result;
    if (!result) result = [[SVLinkManager alloc] init];
    return result;
}

#pragma mark Dealloc

- (void)dealloc
{
    [_selectedLink release];
    [super dealloc];
}

#pragma mark Selected Link

- (void)setSelectedLink:(SVLink *)link editable:(BOOL)editable;
{
    [self setSelectedLink:link];
    [self setEditable:editable];
    
    // Tell all open link Inspectors
    [self refreshLinkInspectors];
}

@synthesize selectedLink = _selectedLink;
@synthesize editable = _editable;

- (void)refreshLinkInspectors;
{
    NSArray *inspectors = [[KSDocumentController sharedDocumentController] inspectors];
    for (SVInspector *anInspector in inspectors)
    {
        [[anInspector linkInspector] setInspectedLink:[self selectedLink]];
    }
}

#pragma mark Modifying the Link

- (void)modifyLinkTo:(SVLink *)link;    // sends -changeLink: up the responder chain
{
    [self setSelectedLink:link];
    [NSApp sendAction:@selector(changeLink:) to:nil from:self];
    
    // Notify Inspectors of the change
    [self refreshLinkInspectors];
}

#pragma mark UI

- (IBAction)orderFrontLinkPanel:(id)sender; // Sets the current Inspector to view links
{
    // Try to create create an example link if there isn't one already present
    if (![self selectedLink] && [self isEditable])
    {
        SVLink *link = [self guessLink];
        if (!link)
        {
            link = [[SVLink alloc] initWithURLString:@"http://example.com"
                                     openInNewWindow:YES];
            [link autorelease];
        }
        
        [self modifyLinkTo:link];
    }
    
    
    // Show the Inspector
    [[KSDocumentController sharedDocumentController] showInspectors:self];
    
    SVInspector *inspector = [[[KSDocumentController sharedDocumentController] inspectors] lastObject];
    [[inspector inspectorTabsController] setSelectedViewController:[inspector linkInspector]];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = YES;
    
    if ([anItem action] == @selector(orderFrontLinkPanel:))
    {
        result = [self isEditable];
    }
    
    return result;
}

- (SVLink *)guessLink;  // looks at the user's workspace to guess what they want. Nil if no match is found
{
    SVLink *result = nil;
    
    
    // Is there something suitable on the pasteboard?
    NSURL *URL = [WebView URLFromPasteboard:[NSPasteboard generalPasteboard]];
    if (!URL)
    {
        // Try to populate from frontmost Safari URL
        NSString *safariTitle = nil;	// someday, we could populate the link title as well!
        [NSAppleScript getWebBrowserURL:&URL title:&safariTitle source:nil];
    }
    
    if (URL)
    {
        result = [[SVLink alloc] initWithURLString:[URL absoluteString]
                                   openInNewWindow:NO];
        [result autorelease];
    }
    
    
    return result;
}

@end
