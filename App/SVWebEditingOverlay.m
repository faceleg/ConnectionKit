//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditingOverlay.h"
#import "SVSelectionBorder.h"
#import <QuartzCore/QuartzCore.h>   // for CoreAnimation – why isn't it pulled in by default?


@implementation SVWebEditingOverlay

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    _selection = [[NSMutableArray alloc] init];
    
    // Create a CALayer for drawing
    CALayer *layer = [[CALayer alloc] init];
    [self setLayer:layer];
    [self setWantsLayer:YES];
    
    return self;
}

- (void)dealloc
{
    [_webView release];
    [_selection release];
    
    [super dealloc];
}

#pragma mark Basic Accessors

@synthesize webView = _webView;

@synthesize dataSource = _dataSource;

#pragma mark Selection

@synthesize selectedBorders = _selection;

- (void)insertObject:(SVSelectionBorder *)border inSelectedBordersAtIndex:(NSUInteger)index;
{
    [_selection insertObject:border atIndex:index];
    [[self layer] addSublayer:border];
}

- (void)removeObjectFromSelectedBordersAtIndex:(NSUInteger)index;
{
    // Remove layer
    SVSelectionBorder *border = [_selection objectAtIndex:index];
    [border removeFromSuperlayer];
    
    [_selection removeObjectAtIndex:index];
}

#pragma mark Event Handling

- (NSView *)hitTest:(NSPoint)aPoint
{
    // TODO: How to handle a nil webview? And a nil node?
    WebView *webView = [self webView];
    
    NSPoint webViewPoint = [webView convertPoint:aPoint fromView:[self superview]];
    NSDictionary *elementInfo = [webView elementAtPoint:webViewPoint];
    DOMNode *node = [elementInfo objectForKey:WebElementDOMNodeKey];
    
    
    // This is the key to the whole operation. We have to decide whether events make it through to the WebView based on whether they would target a selectable object
    NSView *result;
    if ([[self dataSource] webEditingView:self nodeIsSelectable:node])
    {
        result = [super hitTest:aPoint];
    }
    else
    {
        result = [webView hitTest:aPoint];  // as a sneaky optimisation, assume we share the exact same co-ordinate system as the webview so as to save trying to convert systems
    }
    
    return result;
}

@end

