//
//  SVParagraphedHTMLWriterDOMAdaptor.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVFieldEditorHTMLWriterDOMAdapator.h"
#import "WebEditingKit.h"


@class SVRichTextDOMController, SVTextAttachment;


@interface SVParagraphedHTMLWriterDOMAdaptor : SVFieldEditorHTMLWriterDOMAdapator
{
  @private
    BOOL    _allowsBlockGraphics;
    
    NSMutableSet    *_attachments;
}

@property(nonatomic) BOOL allowsPagelets;

- (NSSet *)textAttachments;
- (void)writeTextAttachment:(SVTextAttachment *)attachment;

// Pulls out the computed style values that are valid for use
- (NSDictionary *)dictionaryWithCSSStyle:(DOMCSSStyleDeclaration *)style
                                 tagName:(NSString *)tagName;


@end


#pragma mark -


@interface DOMNode (SVBodyText)
- (DOMNode *)writeTopLevelParagraph:(SVParagraphedHTMLWriterDOMAdaptor *)context;
@end