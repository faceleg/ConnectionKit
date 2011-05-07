//
//  SVArticleDOMController.h
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVRichTextDOMController.h"

#import "SVArticle.h"


@class SVCalloutDOMController;


@interface SVArticleDOMController : SVRichTextDOMController <DOMEventListener>
{
  @private
    SVCalloutDOMController  *_earlyCalloutController;
    
    DOMElement  *_dragCaret;
    BOOL        _displayDropOutline;
}

- (IBAction)moveToBlockLevel:(id)sender;


#pragma mark DOM
@property(nonatomic, readonly) DOMElement *mouseDownSelectionFallbackDOMElement;


#pragma mark Callouts
@property(nonatomic, retain) SVCalloutDOMController *earlyCalloutDOMController;


#pragma mark Actions
// Like -delete: but targets the children that are selected or editing
- (IBAction)cleanHTML:(NSMenuItem *)sender;


#pragma mark Drag Caret
- (void)removeDragCaret;
- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)dragInfo;
- (void)replaceDragCaretWithHTMLString:(NSString *)html;

- (DOMElement *)dropOutlineDOMElement;


@end
