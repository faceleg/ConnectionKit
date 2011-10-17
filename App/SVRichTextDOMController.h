//
//  SVRichTextDOMController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"
#import "SVRichText.h"


@class SVRichText, SVGraphic, SVWebEditorHTMLContext, SVParagraphedHTMLWriterDOMAdaptor, SVElementInfo;


@interface SVRichTextDOMController : SVTextDOMController 
{
  @private
    SVRichText  *_storage;
    
    BOOL    _importsGraphics;
    
    BOOL    _isUpdating;
    BOOL    _isObservingText;
    
    NSArrayController       *_graphicsController;
    DOMHTMLAnchorElement    *_selectedLink;
}


#pragma mark Lifecycle
// The text is set as .representedObject but you can change after
- (id)initWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)node textStorage:(SVRichText *)text;


#pragma mark Properties
@property(nonatomic, retain, readonly) SVRichText *richTextStorage;
@property(nonatomic) BOOL importsGraphics;


#pragma mark Content
- (IBAction)insertFile:(id)sender;
- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;
- (void)insertGraphic:(SVGraphic *)graphic range:(DOMRange *)insertionRange;
- (DOMRange *)insertionRangeForGraphic:(SVGraphic *)graphic;


#pragma mark Updates

// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;

- (Class)attachmentsControllerClass;    // default is NSArrayController


#pragma mark Responding to Changes
- (DOMNode *)write:(SVParagraphedHTMLWriterDOMAdaptor *)writer
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;


#pragma mark Selection
// Like Web Editor method but ignores items outside self. Text ranges and editing items are analyzed to find corresponding item inside self.
- (NSArray *)selectedItems;


#pragma mark Links
@property(nonatomic, retain, readonly) DOMHTMLAnchorElement *selectedLink;


#pragma mark Queries
// Returns the paragraph in question if it is at the start, otherwise nil
- (DOMNode *)isDOMRangeStartOfParagraph:(DOMRange *)range;
- (DOMNode *)isDOMRangeEndOfParagraph:(DOMRange *)range;


@end

