//
//  SVParagraphedHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVFieldEditorHTMLWriter.h"


@class SVRichTextDOMController;


@interface SVParagraphedHTMLWriter : SVFieldEditorHTMLWriter
{
  @private
    NSMutableSet    *_attachments;
    
    SVRichTextDOMController             *_DOMController;
}

- (NSSet *)textAttachments;

@property(nonatomic, retain) SVRichTextDOMController *bodyTextDOMController;


@end


#pragma mark -


@interface DOMNode (SVBodyText)
- (DOMNode *)topLevelParagraphWriteToStream:(KSHTMLWriter *)context;
@end