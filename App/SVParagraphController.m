//
//  SVParagraphController.m
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVParagraphController.h"


@implementation SVParagraphController

- (id)initWithParagraph:(SVBodyParagraph *)paragraph HTMLElement:(DOMHTMLElement *)domElement;
{
    self = [self init];
    
    _paragraph = [paragraph retain];
    _HTMLElement = [domElement retain];
    [domElement setIdName:nil]; // don't want it cluttering up the DOM any more
    
    return self;
}

- (void)dealloc
{
    [_paragraph release];
    [_HTMLElement release];
    
    [super dealloc];
}

@synthesize paragraph = _paragraph;
@synthesize paragraphHTMLElement = _HTMLElement;

@end
