// 
//  SVPageBody.m
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBody.h"

#import "SVGraphic.h"
#import "SVWebEditorHTMLContext.h"
#import "SVHTMLTextBlock.h"
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

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    // Write any early callouts
    NSUInteger writtenTo = [self writeEarlyCallouts:context];
    
    
    // Start Article Content
    [context writeStartTag:@"div" idName:nil className:@"article-content"];
    [context writeNewline];
    
    [context writeStartTag:@"div" idName:nil className:@"RichTextElement"];
    [context writeNewline];
    
    
    // Construct text block for our contents
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setHTMLSourceObject:[self page]];
    [textBlock setHTMLSourceKeyPath:@"body"];
    [textBlock setRichText:YES];
    [textBlock setFieldEditor:NO];
    [textBlock setImportsGraphics:YES];
    
    
    // Open text block
    [context willBeginWritingHTMLTextBlock:textBlock];
    [textBlock writeStartTags:context];
    [context writeNewline];
    
    
    // Write text minus early callouts
    NSRange range = NSMakeRange(writtenTo, [[self string] length] - writtenTo);
    [self writeText:context range:range];
    
    
    // End text block
    [context writeNewline];
    [textBlock writeEndTags:context];
    
    
    // End Article Content
    [context writeEndTag];
    [context writeEndTag];
    [context writeHTMLString:@" <!-- /article-content -->"];
    [context writeNewline];
}

- (NSUInteger)writeEarlyCallouts:(SVHTMLContext *)context;
{
    //  Piece together each of our elements to generate the HTML
    NSArray *attachments = [self orderedAttachments];
    NSString *archive = [self string];
    
    SVTextAttachment *lastAttachment = nil;
    NSUInteger archiveIndex = 0;
    
    for (SVTextAttachment *anAttachment in attachments)
    {
        // What's the range of the text to write?
        NSRange searchRange = NSMakeRange(archiveIndex,
                                          [anAttachment range].location - archiveIndex);
        
        // We're only interested in writing whitespace here
        NSRange range = [archive
                         rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceAndNewlineCharacterSet]
                         options:0
                         range:searchRange];
        
        if (range.location != NSNotFound || ![[anAttachment graphic] isCallout])
        {
            archiveIndex = range.location;
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
    
    
    return archiveIndex;
}

- (void)writeEarlyCallouts;
{
    [self writeEarlyCallouts:[SVHTMLContext currentContext]];
}

@end
