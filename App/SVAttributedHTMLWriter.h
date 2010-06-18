//
//  SVAttributedHTMLWriter.h
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVHTMLWriter.h"



@interface SVAttributedHTMLWriter : NSObject <SVHTMLWriterDelegate, KSWriter>
{
  @private
    NSMutableAttributedString   *_attributedHTML;
    NSArray                     *_graphicControllers;   // weak, temp ref
}

+ (void)writeDOMRange:(DOMRange *)range
         toPasteboard:(NSPasteboard *)pasteboard
   graphicControllers:(NSArray *)graphicControllers;

@end
