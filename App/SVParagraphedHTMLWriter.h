//
//  SVParagraphedHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVFieldEditorHTMLWriter.h"
#import "WebEditingKit.h"


@class SVRichTextDOMController, SVTextAttachment;


@interface SVParagraphedHTMLWriter : SVFieldEditorHTMLWriter
{
  @private
    BOOL    _allowsBlockGraphics;
    
    NSMutableSet    *_attachments;
    
    SVRichTextDOMController *_DOMController;
    WEKWebEditorItem        *_currentItem;  // weak ref
}

@property(nonatomic) BOOL allowsBlockGraphics;

- (NSSet *)textAttachments;
- (void)writeTextAttachment:(SVTextAttachment *)attachment;

@property(nonatomic, retain) SVRichTextDOMController *bodyTextDOMController;


@end


#pragma mark -


@interface DOMNode (SVBodyText)
- (DOMNode *)topLevelParagraphWriteToStream:(KSHTMLWriter *)context;
@end