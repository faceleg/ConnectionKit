// 
//  SVArticle.m
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVArticle.h"

#import "KTDesign.h"
#import "SVGraphic.h"
#import "SVHTMLContext.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "KTImageScalingSettings.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSError+Karelia.h"


@implementation SVArticle 

+ (SVArticle *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"Article"
                                         inManagedObjectContext:context];
}

@dynamic page;

- (void)setString:(NSString *)string attachments:(NSSet *)attachments;
{
    [super setString:string attachments:attachments];
    
    
    // Make sure our page's thumbnail source graphic matches up
    KTPage *page = [self page];
    SVGraphic *thumbnailGraphic = [page thumbnailSourceGraphic];
    if (!thumbnailGraphic || ![attachments containsObject:[thumbnailGraphic textAttachment]])
    {
        [page guessThumbnailSourceGraphic];
    }
    
    
    // Similarly, photocasts & podcasts want a graphic for their enclosure
    [page guessEnclosures];
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
    NSUInteger writtenTo = 0;//[self writeEarlyCallouts:context];   Turned off because stops -startElements: writing element ID attribute, and so editor can't locate it.
    
    
    // Start Article Content
    [context startElement:@"div" idName:nil className:@"article-content"];
    
    [context startElement:@"div" idName:nil className:@"RichTextElement"];
    
    
    // Open text block
    [textBlock startElements:context];
    
    
    // Write text minus early callouts
    NSRange range = NSMakeRange(writtenTo, [[self string] length] - writtenTo);
    [self writeText:context range:range];
    
    
    // End text block
    [textBlock endElements:context];
    
    
    // End Article Content
    [context endElement];
    [context endElement];
    [context writeHTMLString:@" <!-- /article-content -->"];
    
    
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
            [context writeGraphic:[anAttachment graphic]];
            lastAttachment = anAttachment;
        }
        
        NSRange lastAttachmentRange = [lastAttachment range];
        archiveIndex = lastAttachmentRange.location + lastAttachmentRange.length;
    }
    
    
    return archiveIndex;
}

- (void)writeEarlyCallouts;
{
    [self writeEarlyCallouts:[[SVHTMLTemplateParser currentTemplateParser] HTMLContext]];
}

- (void)writeText:(SVHTMLContext *)context range:(NSRange)range;
{
    [super writeText:context range:range];
    
    
    // If the last character is an attachment, want a line break so cursor can be placed after it.
    if ([self endsOnAttachment]) [context writeLineBreak];
}

#pragma mark Validation

- (BOOL)validateAttachment:(SVTextAttachment *)attachment
                 placement:(SVGraphicPlacement)placement
                     error:(NSError **)error;
{
    // We're more permissive than superclass and allow callout attachments
    if (placement != SVGraphicPlacementInline &&
        placement != SVGraphicPlacementCallout)
    {
        if (error) *error = [KSError errorWithDomain:NSCocoaErrorDomain
                                                code:NSValidationNumberTooLargeError
                                localizedDescription:@"Unsupported graphic placement in article"];
        
        return NO;
    }
    
    return YES;
}

- (BOOL)attachmentsMustBeWrittenInline; { return NO; }

- (CGFloat)maxGraphicWidth;
{
    KTPage *page = [self page];
    
    KTImageScalingSettings *settings;
    if ([[page showSidebar] boolValue])
    {
        settings = [[[page master] design] imageScalingSettingsForUse:@"KTSidebarPageMedia"];
    }
    else
    {
        settings = [[[page master] design] imageScalingSettingsForUse:@"KTPageMedia"];
    }

    CGFloat result = [settings size].width;
    return result;
}

@end
