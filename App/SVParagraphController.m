//
//  SVParagraphController.m
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVParagraphController.h"

#import "SVBodyParagraph.h"


@implementation SVParagraphController

#pragma mark Init & Dealloc

- (id)initWithParagraph:(SVBodyParagraph *)paragraph HTMLElement:(DOMHTMLElement *)domElement;
{
    self = [self init];
    
    _paragraph = [paragraph retain];
    
    // Observer our bit of the DOM
    _HTMLElement = [domElement retain];
    [domElement setIdName:nil]; // don't want it cluttering up the DOM any more
    [domElement addEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
    
    [self setWebView:[[[domElement ownerDocument] webFrame] webView]];
    
    return self;
}

- (void)dealloc
{
    // Stop observation
    [[self HTMLElement] removeEventListener:@"DOMSubtreeModified"
                                            listener:self
                                          useCapture:NO];
    
    [self setWebView:nil];
    
    [_paragraph release];
    [_HTMLElement release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize paragraph = _paragraph;
@synthesize HTMLElement = _HTMLElement;

- (SVBodyElement *)bodyElement { return [self paragraph]; }

#pragma mark Editing

- (void)updateModelFromDOM;
{
    [[self paragraph] setHTMLStringFromElement:[self HTMLElement]];
}

@synthesize webView = _webView;
- (void)setWebView:(WebView *)webView
{
    // We wish to monitor the webview for change notifications so edits can be committed to the store
    if (_webView)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                       name:WebViewDidChangeNotification
                                                     object:_webView];
    }
    
    [webView retain];
    [_webView release], _webView = webView;
    
    if (webView)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(webViewDidChange:)
                                                     name:WebViewDidChangeNotification
                                                   object:_webView];
    }
}

- (void)webViewDidChange:(NSNotification *)notification
{
    // Commit any changes caused by the user
    if (_editTimestamp)
    {
        if ([[NSApp currentEvent] timestamp] == _editTimestamp)
        {
            [self updateModelFromDOM];
        }
        
        _editTimestamp = 0;
    }
}

- (void)handleEvent:(DOMEvent *)event
{
    // Mark as having changes
    _editTimestamp = [[NSApp currentEvent] timestamp];
}

@end
