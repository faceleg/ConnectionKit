//
//  SVAttributedHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVFieldEditorHTMLWriterDOMAdapator.h"



@interface SVAttributedHTMLWriter : NSObject <KSXMLWriterDOMAdaptorDelegate, KSWriter>
{
  @private
    NSMutableAttributedString   *_attributedHTML;
    NSArray                     *_graphicControllers;   // weak, temp ref
}

+ (void)writeDOMRange:(DOMRange *)range
         toPasteboard:(NSPasteboard *)pasteboard
   graphicControllers:(NSArray *)graphicControllers;

@end
