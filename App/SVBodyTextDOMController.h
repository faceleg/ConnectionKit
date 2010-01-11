//
//  SVPageletBodyTextAreaController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextController.h"


@class SVBody, SVBodyElement, SVGraphic;


@interface SVBodyTextDOMController : SVWebEditorTextController <DOMEventListener>
{
    NSArrayController   *_content;
        
    BOOL    _isUpdating;    
}

- (id)initWithContentObject:(SVContentObject *)body inDOMDocument:(DOMDocument *)document;


#pragma mark Content
@property(nonatomic, retain, readonly) NSArrayController *content;

- (BOOL)insertElement:(SVBodyElement *)pagelet;
- (BOOL)insertPagelet:(SVPagelet *)pagelet; // wraps pagelet in a callout and calls -insertElement: with that

#pragma mark Subcontrollers

- (SVDOMController *)controllerForBodyElement:(SVBodyElement *)element;
- (SVDOMController *)controllerForDOMNode:(DOMNode *)node;

- (Class)controllerClassForBodyElement:(SVBodyElement *)element;

// All the selectable items within ourself
- (NSArray *)graphicControllers;


#pragma mark Updates

// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;


#pragma mark Links

- (IBAction)orderFrontLinkPanel:(id)sender;
- (BOOL)canMakeLink;

@end