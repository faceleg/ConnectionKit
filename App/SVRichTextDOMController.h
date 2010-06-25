//
//  SVRichTextDOMController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"
#import "SVFieldEditorHTMLWriter.h"


@class SVRichText, SVGraphic, SVWebEditorHTMLContext, SVParagraphedHTMLWriter;


@interface SVRichTextDOMController : SVTextDOMController <SVFieldEditorHTMLWriterDelegate>
{        
    BOOL    _isUpdating;
    
    SVWebEditorHTMLContext  *_changeHTMLContext;
    
    DOMHTMLAnchorElement    *_selectedLink;
}

#pragma mark Properties
- (BOOL)allowsPagelets;


#pragma mark Content
- (IBAction)insertFile:(id)sender;
- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;


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


@end

