//
//  SVRichTextDOMController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"


@class SVRichText, SVBodyElement, SVGraphic, SVWebEditorHTMLContext, SVParagraphedHTMLWriter;


@interface SVRichTextDOMController : SVTextDOMController <SVHTMLWriterDelegate>
{        
    BOOL    _isUpdating;
    
    SVWebEditorHTMLContext  *_changeHTMLContext;
    
    DOMHTMLAnchorElement    *_selectedLink;
}

#pragma mark Properties
- (BOOL)allowsBlockGraphics;


#pragma mark Content
- (IBAction)insertFile:(id)sender;
- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;


#pragma mark Subcontrollers

- (SVDOMController *)controllerForBodyElement:(SVBodyElement *)element;
- (SVDOMController *)controllerForDOMNode:(DOMNode *)node;


#pragma mark Updates
// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;


#pragma mark Responding to Changes
- (void)willWriteText:(SVParagraphedHTMLWriter *)writer;
- (BOOL)write:(SVParagraphedHTMLWriter *)writer item:(WEKWebEditorItem *)controller;


#pragma mark Links

@property(nonatomic, retain, readonly) DOMHTMLAnchorElement *selectedLink;


@end

