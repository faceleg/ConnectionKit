//
//  SVBodyParagraphDOMAdapter.m
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraphDOMAdapter.h"

#import "SVBodyParagraph.h"
#import "SVMutableStringHTMLContext.h"


static NSString *sParagraphInnerHTMLObservationContext = @"ParagraphInnerHTMLObservationContext";


@implementation SVBodyParagraphDOMAdapter

#pragma mark Init & Dealloc

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
    if ([self isHTMLElementCreated])
    {
        [[self HTMLElement] removeEventListener:@"DOMSubtreeModified"
                                       listener:[self eventsListener]
                                     useCapture:NO];
    }
    _editTimestamp = 0; // otherwise webview changes may still try to commit us
    
    // Store element and WebView
    [super setHTMLElement:element];
    [self setWebView:[[[element ownerDocument] webFrame] webView]];
    
    // Observe our bit of the DOM
    [element addEventListener:@"DOMSubtreeModified"
                     listener:[self eventsListener]
                   useCapture:NO];
}

- (void)createHTMLElement
{
    SVBodyParagraph *paragraph = [self representedObject];
    NSString *tagName = @"P";
    
    DOMHTMLElement *htmlElement = (DOMHTMLElement *)[[self HTMLDocument] createElement:tagName];
    
    SVMutableStringHTMLContext *context = [[SVMutableStringHTMLContext alloc] init];
    [context push];
    [paragraph writeInnerHTML];
    [context pop];
    
    [htmlElement setInnerHTML:[context markupString]];
    [context release];
    
    [self setHTMLElement:htmlElement];
}

#pragma mark Model Changes

- (void)setRepresentedObject:(id)paragraph
{
    // Stop observation
    [[self representedObject] removeObserver:self forKeyPath:@"archiveString"];
    
    [super setRepresentedObject:paragraph];
    
    // Observe paragraph
    [[self representedObject] addObserver:self
                               forKeyPath:@"archiveString"
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
            [self setNeedsUpdate];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)update;
{
    [super update];
    

    SVMutableStringHTMLContext *context = [[SVMutableStringHTMLContext alloc] initWithContext:[self HTMLContext]];
    [context push];
    
    SVBodyParagraph *paragraph = [self representedObject];
    [paragraph writeInnerHTML];
    
    [context pop];
    [[self HTMLElement] setInnerHTML:[context mutableString]];
}

#pragma mark Editing

- (void)enclosingBodyControllerDidChangeText
{
    // Commit any changes caused by the user. Caller will take care of undo coalescing and other behaviour
    if (_editTimestamp)
    {
        if ([[NSApp currentEvent] timestamp] == _editTimestamp)
        {
            OBPRECONDITION(!_isUpdatingModel);
            _isUpdatingModel = YES;
            
            SVBodyParagraph *paragraph = [self representedObject];
            [paragraph readHTMLFromElement:[self HTMLElement]];
            
            _isUpdatingModel = NO;;
        }
        
        _editTimestamp = 0;
    }
}

@synthesize webView = _webView;

- (void)handleEvent:(DOMEvent *)event
{
    // Mark as having changes
    _editTimestamp = [[NSApp currentEvent] timestamp];
}

- (BOOL)isSelectable { return NO; }

#pragma mark Debugging

- (NSString *)blurb
{
    return [[self HTMLElement] innerText];
}

@end


#pragma mark -



@implementation KSDOMController (enclosingBodyControllerDidChangeText)
- (void)enclosingBodyControllerDidChangeText
{
    // I don't care
}
@end
