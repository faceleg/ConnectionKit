// 
//  SVPageletBody.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBody.h"

#import "SVTextAttachment.h"
#import "SVGraphic.h"
#import "SVBodyElement.h"
#import "SVBodyTextDOMController.h"
#import "SVHTMLContext.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSSortDescriptor+Karelia.h"


@interface SVBody ()
@end

@interface SVBody (CoreDataGeneratedAccessors)
- (void)addElementsObject:(SVBodyElement *)value;
- (void)removeElementsObject:(SVBodyElement *)value;
- (void)addElements:(NSSet *)value;
- (void)removeElements:(NSSet *)value;
@end


#pragma mark -


@implementation SVBody 

#pragma mark Init

+ (SVBody *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"PageBody"
                                         inManagedObjectContext:context];
}

+ (SVBody *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
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
@dynamic attachments;

#pragma mark HTML

- (void)writeHTML
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    
    //  Piece together each of our elements to generate the HTML
    NSArray *attachments = [[self attachments] KS_sortedArrayUsingDescriptors:
                            [NSSortDescriptor sortDescriptorArrayWithKey:@"location"
                                                               ascending:YES]];
    
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
        [[anAttachment pagelet] writeHTML];
        lastAttachment = anAttachment;
        
        NSRange lastAttachmentRange = [lastAttachment range];
        archiveIndex = lastAttachmentRange.location + lastAttachmentRange.length;
    }
        
    // Write remaining text
    [context writeString:[archive substringFromIndex:archiveIndex]];
}

#pragma mark Editing

- (Class)DOMControllerClass; { return [SVBodyTextDOMController class]; }

@end
