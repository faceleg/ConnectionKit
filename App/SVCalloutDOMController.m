//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"
#import "SVCallout.h"

#import "SVGraphic.h"


@implementation SVCalloutDOMController

- (id)initWithContentObject:(SVContentObject *)contentObject inDOMDocument:(DOMDocument *)document
{
    [super initWithContentObject:contentObject inDOMDocument:document];
    
    // Create subcontrollers for each of our pagelets
    SVCallout *callout = [self representedObject];
    for (SVGraphic *aPagelet in [callout pagelets])
    {
        SVDOMController *pageletController = [[[aPagelet DOMControllerClass] alloc] initWithContentObject:aPagelet inDOMDocument:document];
        
        [self addChildWebEditorItem:pageletController];
        [pageletController release];
    }
    
    
    return self;
}

- (BOOL)isSelectable { return NO; }

@end
