//
//  SVRawHTMLDOMController.m
//  Sandvox
//
//  Created by Mike on 09/07/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLDOMController.h"

#import "SVTemplate.h"


@implementation SVRawHTMLDOMController

- (void)loadHTMLElementFromDocument:(DOMDocument *)document
{
    [super loadHTMLElementFromDocument:document];
    
    NSRect box = [[self HTMLElement] boundingBox];
    if (box.size.width <= 0.0f || box.size.height <= 0.0f)
    {
        // Replace with placeholder
        NSString *placeholderHTML = [[SVRawHTMLGraphic placeholderTemplate] templateString];
        [[self bodyHTMLElement] setInnerHTML:placeholderHTML];
    }
}

@end


#pragma mark -


@implementation SVRawHTMLGraphic (SVRawHTMLDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVRawHTMLDOMController alloc] initWithRepresentedObject:self];
}

@end
