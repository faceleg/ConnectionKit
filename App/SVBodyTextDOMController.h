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

- (id)initWithHTMLElement:(DOMHTMLElement *)element content:(NSArrayController *)content;


#pragma mark Content
@property(nonatomic, retain, readonly) NSArrayController *content;

- (BOOL)insertGraphic:(SVGraphic *)pagelet;
- (BOOL)insertPagelet:(SVPagelet *)pagelet;

#pragma mark Subcontrollers

- (SVWebEditorItem *)controllerForBodyElement:(SVBodyElement *)element;
- (SVWebEditorItem *)controllerForDOMNode:(DOMNode *)node;

- (SVWebEditorItem *)makeAndAddControllerForBodyElement:(SVBodyElement *)element
                                                   HTMLElement:(DOMHTMLElement *)element;

- (Class)controllerClassForBodyElement:(SVBodyElement *)element;

// All the selectable items within ourself
- (NSArray *)graphicControllers;


#pragma mark Updates

// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;

@end