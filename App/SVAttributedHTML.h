//
//  SVAttributedHTML.h
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVHTMLContext;


@interface SVAttributedHTML : NSMutableAttributedString
{
  @private
    NSMutableAttributedString *_storage;
    
}

+ (SVAttributedHTML *)attributedHTMLFromPasteboard:(NSPasteboard *)pasteboard
                              managedObjectContext:(NSManagedObjectContext *)context;


- (void)writeHTMLToContext:(SVHTMLContext *)context;


@end
