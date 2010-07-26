//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"


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

#pragma mark Other

- (NSString *)elementIdName;
{
    return [NSString stringWithFormat:@"callout-controller-%p", self];
}

- (SVCalloutDOMController *)calloutDOMController;
{
    return self;
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVCalloutDOMController)

- (SVCalloutDOMController *)calloutDOMController; { return [[self parentWebEditorItem] calloutDOMController]; }

@end
