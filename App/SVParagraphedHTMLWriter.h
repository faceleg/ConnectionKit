//
//  SVParagraphedHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVFieldEditorHTMLStream.h"


@class SVBodyTextDOMController;


@interface SVParagraphedHTMLWriter : SVFieldEditorHTMLStream
{
  @private
    NSMutableSet    *_attachments;
    
    SVBodyTextDOMController             *_DOMController;
}

- (NSSet *)textAttachments;

@property(nonatomic, retain) SVBodyTextDOMController *bodyTextDOMController;


@end


#pragma mark -


@interface DOMNode (SVBodyText)
- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
@end