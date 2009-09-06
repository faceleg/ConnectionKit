//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditingOverlay.h"


@implementation SVWebEditingOverlay

- (void)dealloc
{
    [_webView release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize webView = _webView;

@synthesize dataSource = _dataSource;

#pragma mark Hit Testing

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

