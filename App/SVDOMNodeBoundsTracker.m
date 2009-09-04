//
//  SVDOMNodeBoundingBoxTracker.m
//  Sandvox
//
//  Created by Mike on 03/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMNodeBoundsTracker.h"


@interface SVDOMNodeBoundsTracker ()

- (void)startTracking;
- (void)stopTracking;
@property(nonatomic, copy) NSArray *containingViews;  // those views containing the DOMNode that might move around
@property(nonatomic, retain) DOMDocument *DOMDocument;  // the document to observe for layout changes

@end


#pragma mark -


@implementation SVDOMNodeBoundsTracker

#pragma mark Init & Dealloc

- (id)initWithDOMNode:(DOMNode *)node
{
    OBPRECONDITION(node);
    
    [self init];
    
    // Start tracking
    _node = [node retain];
    [self startTracking];
    
    return self;
}

- (void)dealloc
{
    [self stopTracking];
    [self setDelegate:nil];
    
    [_node release];
    
    [super dealloc];
}

#pragma mark Node

@synthesize DOMNode = _node;

#pragma mark Tracking

/*  Observe all views up to the webview
 */
- (void)startTracking
{
    // Observe any in-webview scrolling as this means there is a high chance of movement
    WebFrame *frame = [[[self DOMNode] ownerDocument] webFrame];
    WebView *webview = [frame webView];
    
    NSMutableArray *containingViews = [[NSMutableArray alloc] init];
    NSView *aView = [[frame frameView] documentView];
    while (aView != webview)
    {
        [containingViews addObject:aView];
        aView = [aView superview];
    }
    
    [self setContainingViews:containingViews];
    [containingViews release];
    
    
    // Also observe the DOM document for changes as this will cause relayout and might affect the node
    [self setDOMDocument:[[self DOMNode] ownerDocument]];
}

- (void)stopTracking
{
    [self setContainingViews:nil];
    [self setDOMDocument:nil];
}

#pragma mark View Observation

@synthesize containingViews = _observedContainingViews;
- (void)setContainingViews:(NSArray *)views
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // Stop observing old views
    for (NSView *aView in [self containingViews])
    {
        [notificationCenter removeObserver:self name:NSViewFrameDidChangeNotification object:aView];
        [notificationCenter removeObserver:self name:NSViewBoundsDidChangeNotification object:aView];
    }
    
    views = [views copy];
    [_observedContainingViews release];
    _observedContainingViews = views;
    
    // Observe new views
    for (NSView *aView in views)
    {
        [notificationCenter addObserver:self 
                               selector:@selector(viewDidMove:)
                                   name:NSViewFrameDidChangeNotification
                                 object:aView];
        
        [notificationCenter addObserver:self
                               selector:@selector(viewDidMove:)
                                   name:NSViewBoundsDidChangeNotification 
                                 object:aView];
    }
    
}

/*  When this is called it means the views enclosing the node have moved in some way. Respond by recalculating the object's location
 */
- (void)viewDidMove:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SVDOMNodeBoundsTackerDidDetectChange"
                                                        object:self];
}

#pragma mark DOM Observation

@synthesize DOMDocument = _document;
- (void)setDOMDocument:(DOMDocument *)document
{
    [[self DOMDocument] removeEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
    
    [document retain];
    [_document release];
    _document = document;
    
    [document addEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
}

- (void)handleEvent:(DOMEvent *)evt;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SVDOMNodeBoundsTackerDidDetectChange"
                                                        object:self];
}

#pragma mark Delegate

/*  This should be a fairly standard template for a delegate
 */

@synthesize delegate = _delegate;
- (void)setDelegate:(id <SVDOMNodeBoundsTrackerDelegate>)delegate;
{
    id oldDelegate = [self delegate];
    if (oldDelegate)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:oldDelegate
                                                        name:@"SVDOMNodeBoundsTackerDidDetectChange"
                                                      object:self];
    }
    
    _delegate = delegate;
    
    if (delegate)
    {
        [[NSNotificationCenter defaultCenter] addObserver:delegate
                                                 selector:@selector(trackerDidDetectDOMNodeBoundsChange:)
                                                     name:@"SVDOMNodeBoundsTackerDidDetectChange"
                                                   object:self];
    }
}

@end

