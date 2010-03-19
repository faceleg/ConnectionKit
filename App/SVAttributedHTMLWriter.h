//
//  SVAttributedHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVHTMLWriter.h"


@class SVTextDOMController, SVRichText;


@interface SVAttributedHTMLWriter : NSObject <SVHTMLWriterDelegate>
{
  @private
    SVTextDOMController *_textDOMController;
    
    NSMutableString     *_htmlWritten;
    NSMutableSet        *_attachmentsWritten;
}

- (void)writeContentsOfTextDOMController:(SVTextDOMController *)domController
                        toAttributedHTML:(SVRichText *)textObject;

@end
