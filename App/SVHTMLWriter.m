//
//  SVTextDOMControllerHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVHTMLWriter.h"


@implementation SVHTMLWriter

@synthesize delegate = _delegate;

- (BOOL)HTMLWriter:(KSHTMLWriter *)writer writeDOMElement:(DOMElement *)element;
{
    return [[self delegate] HTMLWriter:writer writeDOMElement:element];
}

@end
