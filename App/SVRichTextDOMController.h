//
//  SVRichTextDOMController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"
#import "SVFieldEditorHTMLWriter.h"
#import "SVRichText.h"


@class SVRichText, SVGraphic, SVWebEditorHTMLContext, SVParagraphedHTMLWriter;


@interface SVRichTextDOMController : SVTextDOMController <SVDOMToHTMLWriterDelegate>
{        
    BOOL    _isUpdating;
    
    SVWebEditorHTMLContext  *_changeHTMLContext;
    
    DOMHTMLAnchorElement    *_selectedLink;
}

#pragma mark Content
- (IBAction)insertFile:(id)sender;
- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;
- (void)insertGraphic:(SVGraphic *)graphic range:(DOMRange *)insertionRange;


#pragma mark Updates
// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;


#pragma mark Responding to Changes
- (void)willWriteText:(SVParagraphedHTMLWriter *)writer;
- (DOMNode *)write:(SVParagraphedHTMLWriter *)writer
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;


#pragma mark Links
@property(nonatomic, retain, readonly) DOMHTMLAnchorElement *selectedLink;


#pragma mark Items
- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;


@end


#pragma mark -


@interface WEKWebEditorItem (SVRichTextDOMController)

#pragma mark Properties
- (BOOL)allowsPagelets;

#pragma mark Attributed HTML
// Return YES if manages to write self. Otherwise return NO to treat as standard HTML
- (BOOL)writeAttributedHTML:(SVParagraphedHTMLWriter *)writer;

@end

