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

- (id)initWithBodyElement:(SVBodyElement *)element DOMDocument:(DOMDocument *)document;
{
    self = [self init];
    
    _DOMDocument = [document retain];
    [self setRepresentedObject:element];
    
    return self;
}

- (void)dealloc
{
    // Stop observation
    [self setRepresentedObject:nil];
    [self setHTMLElement:nil];
    
    OBASSERT(!_webView);
    
    [super dealloc];
}

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    // Stop & reset old observation
    if ([self isHTMLElementLoaded])
    {
        [[self HTMLElement] removeEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
    }
    _editTimestamp = 0; // otherwise webview changes may still try to commit us
    
    // Store element and WebView
    [super setHTMLElement:element];
    [self setWebView:[[[element ownerDocument] webFrame] webView]];
    
    // Observe our bit of the DOM
    [element addEventListener:@"DOMSubtreeModified" listener:self useCapture:NO];
}

- (void)loadHTMLElement
{
    SVBodyParagraph *paragraph = [self representedObject];
    NSString *tagName = [paragraph tagName];
    
    DOMHTMLElement *htmlElement = (DOMHTMLElement *)[_DOMDocument createElement:tagName];
    [htmlElement setInnerHTML:[paragraph innerHTMLString]];
    
    [self setHTMLElement:htmlElement];
}

#pragma mark Model Changes

- (void)setRepresentedObject:(id)paragraph
{
    // Stop observation
    [[self representedObject] removeObserver:self forKeyPath:@"innerHTMLArchiveString"];
    
    [super setRepresentedObject:paragraph];
    
    // Observe paragraph
    [[self representedObject] addObserver:self
                               forKeyPath:@"innerHTMLArchiveString"
                                  options:0
                                  context:sParagraphInnerHTMLObservationContext];
}

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
