//
//  SVParagraphHTMLContext.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphHTMLContext.h"
#import "SVBodyParagraph.h"


@implementation SVParagraphHTMLContext

- (id)initWithParagraph:(SVBodyParagraph *)paragraph;
{
    OBPRECONDITION(paragraph);
    
    self = [self init];
    _paragraph = [paragraph retain];
    return self;
}

@synthesize paragraph = _paragraph;

- (void)willWriteDOMElement:(DOMElement *)element
{
    
}

@end
