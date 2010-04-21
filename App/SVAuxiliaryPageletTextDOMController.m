//
//  SVAuxiliaryPageletTextDOMController.m
//  Sandvox
//
//  Created by Mike on 21/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAuxiliaryPageletTextDOMController.h"
#import "SVAuxiliaryPageletText.h"


@implementation SVAuxiliaryPageletTextDOMController

- (void)didUpdate;
{
    if ([[[self textHTMLElement] innerText] length] <= 1)
    {
        [[self textHTMLElement] setInnerText:NSLocalizedString(@"Double-click to edit", "placeholder")];
    }
}

- (void)setTextHTMLElement:(DOMHTMLElement *)element;
{
    [super setTextHTMLElement:element];
    [self didUpdate];
}

@end


@implementation SVAuxiliaryPageletText (SVAuxiliaryPageletTextDOMController)

- (Class)DOMControllerClass; { return [SVAuxiliaryPageletTextDOMController class]; }

@end