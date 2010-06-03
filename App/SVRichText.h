//
//  SVPageletBody.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVGraphic.h"


@class SVTextAttachment;


@interface SVRichText : SVContentObject  

+ (SVRichText *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
+ (SVRichText *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Text

- (NSAttributedString *)attributedHTMLString;
- (void)setAttributedHTMLString:(NSAttributedString *)attributedHTML;

@property(nonatomic, copy) NSString *string;
- (void)setString:(NSString *)string attachments:(NSSet *)attachments;  // deletes old attachments

@property(nonatomic, copy, readonly) NSSet *attachments;
- (NSArray *)orderedAttachments;

- (BOOL)isEmpty;

- (void)deleteCharactersInRange:(NSRange)aRange;


#pragma mark HTML
- (void)writeText:(SVHTMLContext *)context;
- (void)writeText:(SVHTMLContext *)context range:(NSRange)range;


#pragma mark Validation
//  'If the attachment were part of the receiver, would it be allowed that placement?'
- (BOOL)validateAttachment:(SVTextAttachment *)attachment
                 placement:(SVGraphicPlacement)placement
                     error:(NSError **)error;

@end
