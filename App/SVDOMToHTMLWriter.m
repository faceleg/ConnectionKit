//
//  SVDOMToHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDOMToHTMLWriter.h"


@implementation SVDOMToHTMLWriter

#pragma mark Delegate

@synthesize delegate = _delegate;

- (DOMNode *)willWriteDOMElement:(DOMElement *)element
{
    return [[self delegate] HTMLWriter:self willWriteDOMElement:element];
}

@end
