//
//  SVAttributedHTML.h
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSStringStream.h"


@class SVHTMLContext;


@interface SVAttributedHTML : NSMutableAttributedString
{
  @private
    NSMutableAttributedString *_storage;
    
}

- (void)writeHTMLToContext:(SVHTMLContext *)context;


#pragma mark Pasteboard
- (void)writeToPasteboard:(NSPasteboard *)pasteboard;

+ (SVAttributedHTML *)attributedHTMLFromPasteboard:(NSPasteboard *)pasteboard
                              managedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)pageletsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

@end
