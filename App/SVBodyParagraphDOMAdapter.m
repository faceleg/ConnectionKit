//
//  SVBodyParagraphDOMAdapter.m
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraphDOMAdapter.h"

#import "SVBodyParagraph.h"


static NSString *sParagraphInnerHTMLObservationContext = @"ParagraphInnerHTMLObservationContext";


@implementation SVBodyParagraphDOMAdapter

#pragma mark Init & Dealloc

- (id)initWithHTMLElement:(DOMHTMLElement *)element;
{
    return [self initWithHTMLElement:element paragraph:nil];
}

- (id)initWithHTMLElement:(DOMHTMLElement *)domElement paragraph:(SVBodyParagraph *)paragraph;
{
    OBPRECONDITION(paragraph);
    
    
    self = [super initWithHTMLElement:domElement];
    
    
    // Observe the model
    _paragraph = [paragraph retain];
    [paragraph addObserver:self forKeyPath:@"innerHTMLArchiveString" options:0 context:sParagraphInnerHTMLObservationContext];
    
    
    // Observe our bit of the DOM
    [domElement setIdName:nil]; // don't want it cluttering up the DOM any more
    [domElement addEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
    
    _isObserving = YES;
    
    [self setWebView:[[[domElement ownerDocument] webFrame] webView]];
    
    return self;
}

- (void)stop;
{
    if (_isObserving)
    {
        [[self paragraph] removeObserver:self forKeyPath:@"innerHTMLArchiveString"];
        
        [[self HTMLElement] removeEventListener:@"DOMSubtreeModified"
                                       listener:self
                                     useCapture:NO];
        
        _editTimestamp = 0; // otherwise webview changes may still commit us
        _isObserving = NO;
    }
}

- (void)dealloc
{
    // Stop observation
    [self stop];
    
    [self setWebView:nil];
    [_paragraph release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize paragraph = _paragraph;

- (SVBodyElement *)bodyElement { return [self paragraph]; }

#pragma mark Model Changes

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sParagraphInnerHTMLObservationContext)
    {
        // Update the view to match the model.
        if (!_isUpdatingModel)
        {
            [self updateDOMFromParagraph];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateDOMFromParagraph;
{
    // TODO: Should we also supply a valid HTML context?
    [self setHTMLString:[[self paragraph] innerHTMLString]];
}

#pragma mark Editing

- (void)updateParagraphFromDOM;
{
    OBPRECONDITION(!_isUpdatingModel);
    _isUpdatingModel = YES;
    
    [[self paragraph] setHTMLStringFromElement:[self HTMLElement]];
    
    _isUpdatingModel = NO;
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
            [self updateParagraphFromDOM];
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
