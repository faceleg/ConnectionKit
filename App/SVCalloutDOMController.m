//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"


@interface DOMElement (SVCalloutDOMController)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVCalloutDOMController

#pragma mark Init & Dealloc

- (void)dealloc
{
    [_calloutContent release];
    [super dealloc];
}

#pragma mark DOM

@synthesize calloutContentElement = _calloutContent;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    DOMNodeList *nodes = [[self HTMLElement] getElementsByClassName:@"callout-content"];
    [self setCalloutContentElement:(DOMElement *)[nodes item:0]];
}

- (void)createHTMLElement;
{
    DOMHTMLDocument *document = [self HTMLDocument];
    
    // This logic is vry similar to SVHTMLContext. Wonder if there's a way to bring them together
    
    DOMElement *calloutContainer = [document createElement:@"DIV"];
    [calloutContainer setAttribute:@"class" value:@"callout-container"];
    
    DOMElement *callout = [document createElement:@"DIV"];
    [callout setAttribute:@"class" value:@"callout"];
    [calloutContainer appendChild:callout];
    
    DOMElement *calloutContent = [document createElement:@"DIV"];
    [calloutContent setAttribute:@"class" value:@"callout-content"];
    [callout appendChild:calloutContent];
    
    
    [self setHTMLElement:(DOMHTMLElement *)calloutContainer];
    [self setCalloutContentElement:calloutContent];
}

#pragma mark Other

- (NSString *)elementIdName;
{
    return [NSString stringWithFormat:@"callout-controller-%p", self];
}

- (SVCalloutDOMController *)calloutDOMController;
{
    return self;
}

- (BOOL)allowsPagelets; { return YES; }

@end


#pragma mark -


@implementation WEKWebEditorItem (SVCalloutDOMController)

- (SVCalloutDOMController *)calloutDOMController; { return [[self parentWebEditorItem] calloutDOMController]; }

@end
