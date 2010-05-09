//
//  SVPageBodyTextDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBodyTextDOMController.h"

#import "SVGraphic.h"
#import "SVGraphicFactoryManager.h"
#import "SVHTMLContext.h"
#import "KTPage.h"


@implementation SVPageBodyTextDOMController

#pragma mark Properties

- (BOOL)allowsBlockGraphics; { return YES; }





- (IBAction)insertPagelet:(id)sender;
{
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVGraphic *graphic = [SVGraphicFactoryManager graphicWithActionSender:sender
                                           insertIntoManagedObjectContext:context];
    
    [self addGraphic:graphic placeInline:NO];
    [graphic awakeFromInsertIntoPage:(id <SVPage>)[[self HTMLContext] currentPage]];
}

#pragma mark Dragging Destination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    return NSDragOperationLink;
}

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)info;
{
    WEKWebEditorItem *result = [super hitTestDOMNode:node draggingInfo:info];
    if (!result) result = self;
    return result;
}

@end


@implementation SVPageBody (SVPageBodyTextDOMController)
- (Class)DOMControllerClass { return [SVPageBodyTextDOMController class]; }
@end