//
//  SVParagraphDOMController.m
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVParagraphDOMController.h"

#import "SVParagraphedHTMLWriter.h"
#import "SVHTMLContext.h"


static NSString *sParagraphInnerHTMLObservationContext = @"ParagraphInnerHTMLObservationContext";


@implementation SVParagraphDOMController

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
    
    NSMutableString *markupString = [[NSMutableString alloc] init];
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithStringWriter:markupString];
    
    [context push];
    [paragraph writeInnerHTML];
    [context pop];
    [context release];
    
    [htmlElement setInnerHTML:markupString];
    [markupString release];
    
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
    

    // Replace text contents
    NSMutableString *markup = [[NSMutableString alloc] init];
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithStringWriter:markup];
    
    [context copyPropertiesFromContext:[self HTMLContext]];
    [context push];
    
    SVBodyParagraph *paragraph = [self representedObject];
    [paragraph writeInnerHTML];
    
    [context pop];
    [context release];
    
    [[self HTMLElement] setInnerHTML:markup];
    [markup release];
    
    // Paragraph style overrides
    [[self HTMLElement] setAttribute:@"style"
                               value:[[self representedObject] styleAttribute]];
}

#pragma mark Editing

- (void)persistHTMLElementToModel
{
    SVBodyParagraph *paragraph = [self representedObject];
    
    // Clean up style
    NSString *alignment = [[[self HTMLElement] style] textAlign];
    [paragraph setCustomTextAlign:([alignment length] > 0 ? alignment : nil)];
    
    [[self HTMLElement] setAttribute:@"style" value:[paragraph styleAttribute]];
    
    
    // Easiest way to archive string, is to use a context – see, they do all sorts!
    SVParagraphedHTMLWriter *context = [[SVParagraphedHTMLWriter alloc] init];
    [[self HTMLElement] writeInnerHTMLToContext:context];
    
    NSString *string = [context markupString];
    [paragraph setArchiveString:string];
    
    [context release];
}


- (void)enclosingBodyControllerWebViewDidChange:(SVBodyTextDOMController *)bodyController;
{
    // Commit any changes caused by the user. Caller will take care of undo coalescing and other behaviour
    BOOL edited = _editTimestamp && [[NSApp currentEvent] timestamp] == _editTimestamp;
    if (!edited)
    {
        NSString *domStyle = [[self HTMLElement] getAttribute:@"style"];
        if ([domStyle length] == 0) domStyle = nil;
        NSString *modelStyle = [[self representedObject] styleAttribute];
        edited = !KSISEQUAL(domStyle, modelStyle);
    }
    
    
    if (edited)
    {
        [bodyController didChangeText]; // let it know
        
        // Persist paragraph contents
        OBPRECONDITION(!_isUpdatingModel);
        _isUpdatingModel = YES;
        
        [self persistHTMLElementToModel];
        
        _isUpdatingModel = NO;
        
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
- (void)enclosingBodyControllerWebViewDidChange:(SVBodyTextDOMController *)bodyController;
{
    // I don't care
}
@end
