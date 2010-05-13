//
//  SVPageletBody.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

@class SVBodyElement;
@class SVGraphic;


@interface SVRichText : SVContentObject  

+ (SVRichText *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
+ (SVRichText *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;


@property(nonatomic, copy) NSString *string;
- (void)setString:(NSString *)string attachments:(NSSet *)attachments;  // deletes old attachments

@property(nonatomic, copy, readonly) NSSet *attachments;
- (NSArray *)orderedAttachments;

- (BOOL)isEmpty;

- (void)deleteCharactersInRange:(NSRange)aRange;


#pragma mark HTML
- (void)writeText:(SVHTMLContext *)context;
- (void)writeText:(SVHTMLContext *)context range:(NSRange)range;


@end
