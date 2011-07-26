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
    BOOL    _importsGraphics;
    
    BOOL    _isUpdating;
    BOOL    _isObservingText;
    
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

- (Class)attachmentsControllerClass;    // default is NSArrayController

- (void)writeUpdateHTML:(SVHTMLContext *)context;
- (void)updateWithHTMLString:(NSString *)html context:(SVWebEditorHTMLContext *)context;
- (void)willUpdateWithNewChildController:(WEKWebEditorItem *)newChildController;


#pragma mark Responding to Changes
- (DOMNode *)write:(SVParagraphedHTMLWriterDOMAdaptor *)writer
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;


#pragma mark Edit
- (void)deleteObjects:(id)sender;


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

