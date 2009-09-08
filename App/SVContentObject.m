//
//  SVWebContentItem.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"


@interface SVContentObject ()
- (void)updateView;
- (NSView *)overlayContainerView;
@end


#pragma mark -


@implementation SVContentObject

#pragma mark Init & Dealloc

- (id)init
{
    return [self initWithDOMElement:nil];
}

- (id)initWithDOMElement:(DOMHTMLElement *)element;
{
    OBPRECONDITION(element);
    
    self = [super init];
    
    _element = [element retain];
    
    _nodeTracker = [[SVDOMNodeBoundsTracker alloc] initWithDOMNode:element];
    [_nodeTracker setDelegate:self];
    
    return self;
}

- (void)dealloc
{
    [_nodeTracker stopTracking];
    [_nodeTracker setDelegate:nil];
    [_nodeTracker release];
    
    [_element release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize DOMElement = _element;

#pragma mark Overlay View

- (void)loadView
{
    NSView *view = [[NSView alloc] init];
    //[view setBoxType:NSBoxCustom];
    //[view setBorderColor:[NSColor selectedControlColor]];
    //[view setFillColor:[[NSColor redColor] colorWithAlphaComponent:0.5]];
    
    [self setView:view];
    [view release];
}

/*  Support method that places our view in the right place above the webview
 */
- (void)updateView
{
    return;
    
    NSView *overlay = [self view];
    NSView *overlayContainer = [self overlayContainerView];
    
    if (overlayContainer)
    {
        // The trick is to convert the object's bounding box (in WebView co-ordinates) to match our own
        NSRect elementRect = [[self DOMElement] boundingBox];
        NSView *elementView = [[[[[self DOMElement] ownerDocument] webFrame] frameView] documentView];
        NSRect overlayRect = [overlayContainer convertRect:elementRect fromView:elementView];
        [overlay setFrame:overlayRect];
        
        [overlayContainer addSubview:overlay];
    }
    else
    {
        [overlay removeFromSuperview];
    }
}

// To capture mouse events we install a custom view above the webview. This method returns the view in which to place such overlays. Returns nil if the DOM node is not presently on screen.
- (NSView *)overlayContainerView
{
    // Figure out the correct view from our DOM element.
    WebView *webView = [[[[self DOMElement] ownerDocument] webFrame] webView];
    NSView *result = [webView superview];
    
    return result;
}

- (void)trackerDidDetectDOMNodeBoundsChange:(NSNotification *)notification;
{
    [self updateView];
}

#pragma mark Selection

@synthesize selected = _isSelected;

@end
