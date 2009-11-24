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
    [self setRepresentedObject:paragraph];
    
    [[self representedObject] addObserver:self
                               forKeyPath:@"innerHTMLArchiveString"
                                  options:0
                                  context:sParagraphInnerHTMLObservationContext];
    
    
    // Observe our bit of the DOM
    [domElement addEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
    
    _isObserving = YES;
    
    return self;
}

- (id)initWithBodyElement:(SVBodyParagraph *)paragraph DOMDocument:(DOMDocument *)document;
{
    DOMHTMLElement *htmlElement = (DOMHTMLElement *)[document createElement:[paragraph tagName]];
    [htmlElement setInnerHTML:[paragraph innerHTMLString]];
    
    return [self initWithHTMLElement:htmlElement paragraph:paragraph];
}

- (void)stop;
{
    if (_isObserving)
    {
        [[self representedObject] removeObserver:self forKeyPath:@"innerHTMLArchiveString"];
        
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
    
    [super dealloc];
}

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setWebView:[[[element ownerDocument] webFrame] webView]];
}

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
    SVBodyParagraph *paragraph = [self representedObject];
    [self setHTMLString:[paragraph innerHTMLString]];
}

#pragma mark Editing

- (void)updateParagraphFromDOM;
{
    OBPRECONDITION(!_isUpdatingModel);
    _isUpdatingModel = YES;
    
    SVBodyParagraph *paragraph = [self representedObject];
    [paragraph setHTMLStringFromElement:[self HTMLElement]];
    
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
