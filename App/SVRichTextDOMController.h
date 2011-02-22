//
//  SVRichTextDOMController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"
#import "SVRichText.h"


@class SVRichText, SVGraphic, SVWebEditorHTMLContext, SVParagraphedHTMLWriterDOMAdaptor;


@interface SVRichTextDOMController : SVTextDOMController 
{
  @private
    BOOL    _importsGraphics;
    
    BOOL    _isUpdating;
    
    NSArrayController       *_graphicsController;
    DOMHTMLAnchorElement    *_selectedLink;
}

@property(nonatomic) BOOL importsGraphics;


#pragma mark Content
- (IBAction)insertFile:(id)sender;
- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;
- (void)insertGraphic:(SVGraphic *)graphic range:(DOMRange *)insertionRange;
- (DOMRange *)insertionRangeForGraphic:(SVGraphic *)graphic;


#pragma mark Updates
// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
//- (void)willUpdate;
//- (void)didUpdate;


#pragma mark Responding to Changes
- (DOMNode *)write:(SVParagraphedHTMLWriterDOMAdaptor *)writer
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;


#pragma mark Links
@property(nonatomic, retain, readonly) DOMHTMLAnchorElement *selectedLink;


@end

