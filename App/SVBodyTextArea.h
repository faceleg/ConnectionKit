//
//  SVPageletBodyTextAreaController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextController.h"


@class SVBodyElement;
@class SVBody;

@interface SVBodyTextArea : SVWebEditorTextController <DOMEventListener>
{
    NSArrayController   *_content;
    
    NSMutableSet    *_elementControllers;
    
    BOOL    _isUpdating;    
}

- (id)initWithHTMLElement:(DOMHTMLElement *)element content:(NSArrayController *)content;


#pragma mark Content
@property(nonatomic, retain, readonly) NSArrayController *content;


#pragma mark Subcontrollers

- (void)addElementController:(SVHTMLElementController *)controller;
- (void)removeElementController:(SVHTMLElementController *)controller;

- (SVHTMLElementController *)controllerForBodyElement:(SVBodyElement *)element;
- (SVHTMLElementController *)controllerForHTMLElement:(DOMHTMLElement *)element;

- (SVHTMLElementController *)makeAndAddControllerForBodyElement:(SVBodyElement *)element
                                                   HTMLElement:(DOMHTMLElement *)element;

- (Class)controllerClassForBodyElement:(SVBodyElement *)element;

// All the selectable items within ourself
- (NSArray *)contentItems;


#pragma mark Updates

// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;

@end