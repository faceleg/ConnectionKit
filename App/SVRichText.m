// 
//  SVPageletBody.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVRichText.h"

#import "SVTextAttachment.h"
#import "SVGraphic.h"
#import "SVRichTextDOMController.h"
#import "SVHTMLContext.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"


@interface SVRichText ()
@property(nonatomic, copy, readwrite) NSSet *attachments;
@end


#pragma mark -


@implementation SVRichText 

#pragma mark Init

+ (SVRichText *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"PageBody"
                                         inManagedObjectContext:context];
}

+ (SVRichText *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"TextBoxBody"
                                         inManagedObjectContext:context];
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Should we take the opportinity to create a starter paragraph?
}

@dynamic string;

- (void)setString:(NSString *)string attachments:(NSSet *)attachments;
{
    [self setString:string];
    
    NSMutableSet *removedAttachments = [[self attachments] mutableCopy];
    [removedAttachments minusSet:attachments];
    [self setAttachments:attachments];
    
    for (SVTextAttachment *anAttachment in removedAttachments)
    {
        [[self managedObjectContext] deleteObject:anAttachment];
    }
    [removedAttachments release];
}

@dynamic attachments;

- (NSArray *)orderedAttachments;
{
    NSArray *attachments = [[self attachments] KS_sortedArrayUsingDescriptors:
                            [NSSortDescriptor sortDescriptorArrayWithKey:@"location"
                                                               ascending:YES]];
    
    return attachments;
}

- (BOOL)isEmpty;
{
    NSString *text = [[self string] stringByConvertingHTMLToPlainText];
    BOOL result = ([text length] == 0 || [text isEqualToString:@"\n"]);
    return result;
}

- (void)deleteCharactersInRange:(NSRange)range;
{
    // Delete the characters
    NSMutableString *string = [[self string] mutableCopy];
    [string deleteCharactersInRange:range];
    [self setString:string];
    
    
    // Knock down all attachment ranges. Delete any attachments within the range
    NSEnumerator *attachmentsEnumerator = [[self orderedAttachments] reverseObjectEnumerator];
    SVTextAttachment *anAttachment;
    while (anAttachment = [attachmentsEnumerator nextObject])
    {
        // An attachment after the range can be just bumped down
        NSRange aRange = [anAttachment range];
        if (aRange.location >= (range.location + range.length))
        {
            [anAttachment setLocation:[NSNumber numberWithUnsignedInteger:(aRange.location - range.length)]];
        }
        
        // An attachment in the range should be deleted
        else if (aRange.location >= range.location)
        {
            [[self managedObjectContext] deleteObject:anAttachment];
        }
        
        // Once we hit before the range no more work to do
        else
        {
            break;
        }
    }
}

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    //  Piece together each of our elements to generate the HTML
    NSArray *attachments = [self orderedAttachments];
    NSString *archive = [self string];
    
    SVTextAttachment *lastAttachment = nil;
    NSUInteger archiveIndex = 0;
    
    for (SVTextAttachment *anAttachment in attachments)
    {
        // What's the range of the text to write?
        NSRange range = NSMakeRange(archiveIndex, [anAttachment range].location - archiveIndex);
                                    
        // Write it
        NSString *aString = [archive substringWithRange:range];
        [context writeString:aString];
        
        // Write the attachment
        [[anAttachment graphic] writeHTML:context];
        lastAttachment = anAttachment;
        
        NSRange lastAttachmentRange = [lastAttachment range];
        archiveIndex = lastAttachmentRange.location + lastAttachmentRange.length;
    }
        
    // Write remaining text
    [context writeString:[archive substringFromIndex:archiveIndex]];
}

@end
