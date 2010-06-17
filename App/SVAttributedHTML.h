//
//  SVAttributedHTML.h
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSStringStream.h"


@class SVHTMLContext, SVGraphic;


/*  There used to be a method for asking attributed HTML to write itself. Instead use -[SVHTMLContext writeAttriubutedHTMLString:]
 */


@interface NSAttributedString (SVAttributedHTML)

#pragma mark Pasteboard

- (void)attributedHTMLStringWriteToPasteboard:(NSPasteboard *)pasteboard;
- (NSData *)serializedProperties;

+ (NSAttributedString *)attributedHTMLStringFromPasteboard:(NSPasteboard *)pasteboard
                 insertAttachmentsIntoManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSAttributedString *)attributedHTMLStringWithPropertyList:(NSData *)data
                   insertAttachmentsIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)pageletsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)attributedHTMStringPasteboardTypes;


#pragma mark Convenience
+ (NSAttributedString *)attributedHTMLStringWithAttachment:(id)attachment;
+ (NSAttributedString *)calloutAttributedHTMLStringWithGraphic:(SVGraphic *)graphic;

@end
