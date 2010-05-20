// 
//  SVArticle.m
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArticle.h"

#import "SVGraphic.h"
#import "SVWebEditorHTMLContext.h"
#import "SVHTMLTextBlock.h"
#import "KTPage.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"
#import "NSCharacterSet+Karelia.h"


@implementation SVArticle 

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
    // Construct text block for our contents
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setHTMLSourceObject:[self page]];
    [textBlock setHTMLSourceKeyPath:@"article"];
    [textBlock setRichText:YES];
    [textBlock setFieldEditor:NO];
    [textBlock setImportsGraphics:YES];
    
    
    // Tell context that text is due to be written so it sets up DOM Controller. Want that controller in place to contain the early callouts
    [context willBeginWritingHTMLTextBlock:textBlock];
    
    
    // Write any early callouts
    NSUInteger writtenTo = [self writeEarlyCallouts:context];
    
    
    // Start Article Content
    [context writeStartTag:@"div" idName:nil className:@"article-content"];
    [context writeNewline];
    
    [context writeStartTag:@"div" idName:nil className:@"RichTextElement"];
    [context writeNewline];
    
    
    // Open text block
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
    
    
    // Finish
    [context didEndWritingHTMLTextBlock];
    [textBlock release];
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
        
        if (range.location != NSNotFound)
        {
            // Non-whitespace was found, so continue writing from that
            archiveIndex = range.location;
            break;
        }
        else if (![[anAttachment graphic] isCallout])
        {
            // The attachment is not a callout, so continue by writing that attachment in regular location
            archiveIndex = searchRange.location + searchRange.length;
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
