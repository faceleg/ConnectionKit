//
//  SVRawHTMLDOMController.m
//  Sandvox
//
//  Created by Mike on 14/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVRawHTMLDOMController.h"


@implementation SVRawHTMLDOMController

- (void)editRawHTMLInSelectedBlock:(id)sender;
{
    // This is just a placeholder method; web editor view controller takes care of the work
    NSBeep();
}

@end


#pragma mark -


@implementation SVRawHTMLGraphic (SVRawHTMLDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVRawHTMLDOMController alloc] initWithRepresentedObject:self];
}

@end
