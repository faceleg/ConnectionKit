//
//  SVLinkInspector.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkInspector.h"

#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"

#import "DOMRange+Karelia.h"


@implementation SVLinkInspector

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewDidChangeSelection:) name:WebViewDidChangeSelectionNotification object:nil];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WebViewDidChangeSelectionNotification object:nil];
    
    [super dealloc];
}

#pragma mark Inspection

@synthesize inspectedWindow = _inspectedWindow;
@synthesize inspectedLink = _inspectedLink;

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    // Ignore any webview that isn't the one we're interested in
    WebView *webView = [[[[[self inspectedWindow] windowController] webContentAreaController] webEditorViewController] webView];
    if ([notification object] != webView) return;
    
    
    // If there is link selected, we can find it by searching out from the selecte DOM range
    DOMRange *selection = [webView selectedDOMRange];
    DOMHTMLAnchorElement *link = [selection editableAnchorElement];
    [self setInspectedLink:link];
}

#pragma mark Link View

- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[[[self inspectedWindow] windowController] document] site];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:kKTLocalLinkPboardType] owner:self];
	[pboard setString:@"LocalLink" forType:kKTLocalLinkPboardType];
	
	return pboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	// set up a link to the local page
    NSString *pageID = [pboard stringForType:kKTLocalLinkPboardType];
    if ( (pageID != nil) && ![pageID isEqualToString:@""] )
    {
        KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[[[self inspectedWindow] windowController] document] managedObjectContext]];
        if ( nil != target )
        {
            NSString *titleText = [[target title] text];
            if ( (nil != titleText) && ![titleText isEqualToString:@""] )
            {
                //[oLinkLocalPageField setStringValue:titleText];
                //[oLinkDestinationField setStringValue:@""];
                //[oLinkLocalPageField setHidden:NO];
                //[oLinkDestinationField setHidden:YES];
                
                //[info setValue:[NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, pageID] forKey:@"KTLocalLink"];
                [link setConnected:YES];
                
            }
        }
    }
}

- (IBAction)clearLinkDestination:(id)sender;
{
	//[oLinkLocalPageField setStringValue:@""];
	//[oLinkDestinationField setStringValue:@""];
	//[oLinkLocalPageField setHidden:YES];
	//[oLinkDestinationField setHidden:NO];
	//[oLinkView setConnected:NO];
    
    [[[self inspectedWindow] firstResponder] doCommandBySelector:@selector(clearLinkDestination:)];
}


@end
