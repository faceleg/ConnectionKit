//
//  SVSidebarDOMController.m
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarDOMController.h"
#import "SVSidebar.h"


@implementation SVSidebarDOMController

- (void)dealloc;
{
    [_sidebarDiv release];
    [super dealloc];
}

@synthesize sidebarDivElement = _sidebarDiv;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Also seek out sidebar div
    [self setSidebarDivElement:[document getElementById:@"sidebar"]];
}

@end


#pragma mark -


@implementation SVSidebar (SVSidebarDOMController)

- (Class)DOMControllerClass;
{
    return [SVSidebarDOMController class];
}

@end