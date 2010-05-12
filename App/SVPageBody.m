// 
//  SVPageBody.m
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBody.h"

#import "SVGraphic.h"
#import "SVHTMLContext.h"
#import "KTPage.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"


@implementation SVPageBody 

@dynamic page;

- (void)setString:(NSString *)string attachments:(NSSet *)attachments;
{
    [super setString:string attachments:attachments];
    
    
    // Make sure out page's thumbnail source graphic matches up
    KTPage *page = [self page];
    SVGraphic *thumbnailGraphic = [page thumbnailSourceGraphic];
    if (!thumbnailGraphic || ![attachments containsObject:[thumbnailGraphic textAttachment]])
    {
        thumbnailGraphic = [[[self orderedAttachments] firstObjectKS] graphic];
        [page setThumbnailSourceGraphic:thumbnailGraphic];
    }
}

- (void)writeEarlyCallouts:(SVHTMLContext *)context;
{
    //  Piece together each of our elements to generate the HTML
    NSArray *attachments = [self orderedAttachments];
    
    SVTextAttachment *lastAttachment = nil;
    NSUInteger archiveIndex = 0;
    
    for (SVTextAttachment *anAttachment in attachments)
    {
        // What's the range of the text to write?
        if ([anAttachment range].location - archiveIndex ||
            ![[anAttachment graphic] isCallout])
        {
            break;
        }
        else
        {
            // Write the attachment
            [[anAttachment graphic] writeHTML:context];
            lastAttachment = anAttachment;
        }
        
        NSRange lastAttachmentRange = [lastAttachment range];
        archiveIndex = lastAttachmentRange.location + lastAttachmentRange.length;
    }
}

- (void)writeEarlyCallouts;
{
    [self writeEarlyCallouts:[SVHTMLContext currentContext]];
}

@end
