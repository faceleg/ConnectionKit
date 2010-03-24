//
//  SVPageletBodyTextAreaController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"


@class SVRichText, SVBodyElement, SVGraphic, SVParagraphedHTMLWriter;


@interface SVBodyTextDOMController : SVTextDOMController
{        
    BOOL    _isUpdating;    
    
    DOMHTMLAnchorElement    *_selectedLink;
}

#pragma mark Content
- (IBAction)insertElement:(id)sender;
- (IBAction)insertPagelet:(id)sender;
- (IBAction)insertFile:(id)sender;


#pragma mark Subcontrollers

- (SVDOMController *)controllerForBodyElement:(SVBodyElement *)element;
- (SVDOMController *)controllerForDOMNode:(DOMNode *)node;

// All the selectable items within ourself
- (void)writeGraphicController:(SVDOMController *)controller
                withHTMLWriter:(SVParagraphedHTMLWriter *)context;


#pragma mark Updates

// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;


#pragma mark Links

@property(nonatomic, retain, readonly) DOMHTMLAnchorElement *selectedLink;


@end