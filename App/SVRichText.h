//
//  SVPageletBody.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVGraphic.h"
#import "SVComponent.h"


@class SVTextAttachment;


@interface SVRichText : SVContentObject <SVComponent>

+ (SVRichText *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Text
- (NSAttributedString *)attributedHTMLString;
- (void)setAttributedHTMLString:(NSAttributedString *)attributedHTML;
- (void)setAttributedHTMLString:(NSAttributedString *)attributedHTML wasModified:(BOOL)modified;


#pragma mark Primitive Text
// In general you should be working with attributed HTML strings from the above API, rather than this lower level support. e.g. I make no guarantee that -string and -attributedHTMLString.string will be equal

@property(nonatomic, copy) NSString *string;
- (void)setString:(NSString *)string attachments:(NSSet *)attachments;  // deletes old attachments
- (void)setString:(NSString *)string attachments:(NSSet *)attachments wasModified:(BOOL)modified;

- (BOOL)isEmpty;

- (void)deleteCharactersInRange:(NSRange)aRange;


#pragma mark Attachments

@property(nonatomic, copy, readonly) NSSet *attachments;
- (NSArray *)orderedAttachments;
- (BOOL)endsOnAttachment;

+ (NSArray *)attachmentSortDescriptors;
- (BOOL)attachmentsMustBeWrittenInline;
- (CGFloat)maxGraphicWidth;


#pragma mark HTML
- (void)writeText:(SVHTMLContext *)context;
- (void)writeText:(SVHTMLContext *)context range:(NSRange)range;
- (void)writeText;  // uses +currentContext

#pragma mark Validation
//  'If the attachment were part of the receiver, would it be allowed that placement?'
- (BOOL)validateAttachment:(SVTextAttachment *)attachment
                 placement:(SVGraphicPlacement)placement
                     error:(NSError **)error;

@end
