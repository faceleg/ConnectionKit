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
#import "NSXMLElement+Karelia.h"


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

#pragma mark Truncation

- (NSUInteger) lengthOfEnclosedTextFromElement:(NSXMLElement *)anElement
{
	OBPRECONDITION(anElement);
	NSUInteger counter = 0;
	NSXMLNode *currentNode = anElement;		// working node we traverse
	NSXMLNode *siblingNode = [anElement nextSibling];
	while (nil != currentNode && currentNode != siblingNode)	// stop if we hit sibling
	{
		if (NSXMLTextKind == [currentNode kind])
		{
			NSString *thisString = [currentNode stringValue];	// renders &amp; etc.
			OFF((@"%D count: '%@'", [thisString length], thisString));
			counter += [thisString length];
		}
		currentNode = [currentNode nextNode];
	}
	return counter;
}

/*
	Truncate by characters (not used), words/sentences (using tokenizer) or paragraphs (by counting <p> tags.
	We pass in the target truncation character count.  For character truncation we round *down* to the nearest word, so there
	really isn't much difference between character truncation and word truncation!
	For the others, we output an entire word/sentence/paragraph and when we have gone past the limit, we stop and truncate.
	(It would be nice to have the character count be a maximum, but then we would have some "jumping" if we switch from a
	lower value with word truncation to a higher value with sentence truncation.  (Likewise for sentences to paragraphs.)
 
	This algorithm could be improved to notice that you are still in the middle of a sentence when you encounter something
	like a styling tag or hyperlink that breaks up the flow of text.  So if we have a hyperlink or bold in the middle of a
	sentence that is about to overflow the target truncation, it will truncate in the middle of the sentence rather than
	waiting for the full sentence to be complete.  Oh well.
 
 */

- (NSString *)truncateMarkup:(NSString *)markup truncation:(NSUInteger)maxItemLength truncationType:(SVTruncationType)truncationType didTruncate:(BOOL *)outDidTruncate;
{
	OFF((@"TRUNCATE TO: %d [%d]", maxItemLength, truncationType));
	OBPRECONDITION(markup);
	NSString *result = markup;
	BOOL removedAnything = NO;
	if ((kTruncateNone != truncationType) && maxItemLength)	// only do something if we want to actually truncate something
	{
		// Only want run through this if:
		// 1. We are truncating something other than characters, OR....
		// 2. We are truncating characters, and our maximum [character] count is shorter than the actual length we have.
		if (truncationType != kTruncateCharacters || maxItemLength < [result length])
		{			
			// Turn Markup into a tidied XML document
			NSError *theError = NULL;
			
			NSString *prelude = [KTPage stringFromDocType:KSHTMLWriterDocTypeXHTML_1_0_Transitional local:YES];

			NSString *wrapper = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n%@\n<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title></title></head><body>%@</body></html>", prelude, result];
			
			NSUInteger mask = 
			NSXMLNodePreserveAll 
			
			// Something in here is causing errors ... need to figure out which when I can find a test pattern
//			& ~NSXMLNodePreserveNamespaceOrder 
//			& ~NSXMLNodePreserveAttributeOrder 
//			& ~NSXMLNodePreserveEntities 
//			& ~NSXMLNodePreservePrefixes 
//			& ~NSXMLNodePreserveCDATA 
//			& ~NSXMLNodePreserveEmptyElements 
//			& ~NSXMLNodePreserveQuotes				
//			& ~NSXMLNodePreserveWhitespace			
//			& ~NSXMLNodePreserveDTD					
//			& ~NSXMLNodePreserveCharacterReferences	
//			& ~(0xFFF00000)
			;
			
			NSXMLDocument *xmlDoc = nil;
			
			@try
			{
				xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:wrapper options:mask error:&theError] autorelease];
			}
			@catch ( NSException * e )
			{
				NSLog(@"%@", e);
			}
			if (theError) OFF((@"NSXMLDocument from truncation: %@", theError));
			
			if (xmlDoc)
			{
				NSArray *theNodes = [xmlDoc nodesForXPath:@"/html/body" error:&theError];
				NSXMLNode *currentNode = [theNodes lastObject];		// working node we traverse
				NSXMLNode *lastTextNode = nil;
				NSXMLElement *theBody = [theNodes lastObject];	// the body that we we will be truncating
				int accumulator = 0;	// Character count. We stop as soon as end of our truncation unit overflows this (except by-character)
				while (nil != currentNode)
				{
					if (NSXMLTextKind == [currentNode kind])
					{
						NSString *thisString = [currentNode stringValue];	// renders &amp; etc.
						if (kTruncateCharacters == truncationType)
						{
							lastTextNode = currentNode;		// when we are done, we will add ellipses
							unsigned int newAccumulator = accumulator + [thisString length];
							if (newAccumulator >= maxItemLength)	// will we need to prune?
							{
								int truncateIndex = maxItemLength - accumulator;
								NSString *truncd = [thisString smartSubstringWithMaxLength:truncateIndex didSplitWord:nil];
								
								[currentNode setStringValue:truncd];	// re-escapes &amp; etc.
								
								break;		// we will now remove everything after "node"
							}
							accumulator = newAccumulator;
						}
						else if (kTruncateWords == truncationType || kTruncateSentences == truncationType)
						{
							// Note: Word truncation is not perfect. :-\  Ideally we would truncate after
							// the last word, not truncate to include the last word.  Otherwise we lose
							// punctuation, say, if the truncation happens to happen right after the end of a sentence.
							// However, it's certainly good enough!
							
							NSUInteger len = [thisString length];
							if (len + accumulator < maxItemLength)
							{
								accumulator += len;		// skip past all this text; it's below our truncation threshold
							}
							else	// need to tokenize this string
							{
								CFStringTokenizerRef tokenRef
								= CFStringTokenizerCreate (
														   kCFAllocatorDefault,
														   (CFStringRef)thisString,
														   CFRangeMake(0,len),
														   (kTruncateWords == truncationType
															? kCFStringTokenizerUnitWord
															: kCFStringTokenizerUnitSentence),
														   NULL	// Apparently locale is ignored anyhow when doing words?
														   );
								
								CFStringTokenizerTokenType tokenType = kCFStringTokenizerTokenNone;
								CFIndex lastWord = 0;
								BOOL stopWordScan = NO;	// don't use break, since we want breaking out of outer loop
								
								while(!stopWordScan && 
									  (kCFStringTokenizerTokenNone != (tokenType = CFStringTokenizerAdvanceToNextToken(tokenRef))) )
								{
									CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenRef);
									OFF((@"'%@' found at %d+%d", [thisString substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)], tokenRange.location, tokenRange.length));
									
									if (tokenRange.location + accumulator >= maxItemLength)
									{
										stopWordScan = YES;
										OFF((@"early exit from word count, accumulator = %d", accumulator));
									}
									lastWord = tokenRange.location;
								}
								CFRelease(tokenRef);
								OFF((@"in '%@' max=%d len=%d", thisString, lastWord, len));
								if (lastWord + accumulator >= maxItemLength)
								{
									if (lastWord < len)
									{
										NSString *partialString = [thisString substringToIndex:lastWord];
										
										OFF((@"accumulator = %d; Truncating to '%@'", accumulator, partialString));
										[currentNode setStringValue:partialString];	// re-escapes &amp; etc.
										lastTextNode = currentNode;
										removedAnything = YES;
										OFF((@"... and breaking from loop; we're done, since this is really truncating"));
										break;		// exit outer loop, so we stop scanning
									}
									else
									{
										OFF((@"We are out of words, but not breaking here in case we hit inline to follow"));
									}
								}
								else
								{
									accumulator += len;
								}
							}
						}
					}
					else if ([currentNode kind] == NSXMLElementKind)
					{
						NSXMLElement *theElement = (NSXMLElement *)currentNode;
						if (kTruncateParagraphs == truncationType)
						{
							if ([@"p" isEqualToString:[theElement name]])
							{
								NSUInteger textLengthInThisParagraph = [self lengthOfEnclosedTextFromElement:theElement];
								OFF((@"P length: %d", textLengthInThisParagraph));
								accumulator += textLengthInThisParagraph;
								if (accumulator >= maxItemLength)
								{
									OFF((@"%d >= %d", accumulator, maxItemLength));
									break;	// we will now remove everything after "node"
								}
								else
								{
									OFF((@"%d < %d", accumulator, maxItemLength));
								}
							}
						}
					}
					currentNode = [currentNode nextNode];
				}
				OBASSERT(theBody);
				removedAnything = [theBody removeAllNodesAfter:(NSXMLElement *)currentNode];
				if (removedAnything)
				{
					OFF((@"Removed some stuff"));
				}
				else
				{
					OFF((@"Did NOT remove some stuff"));
				}
				if (removedAnything)
				{
					if (lastTextNode)
					{
						// Trucate, plus add on an ellipses.
						NSString *ellipses = NSLocalizedString(@"\\U2026", @"ellipses appended to command, meaning there will be confirmation alert.  Probably spaces before in French.");
						NSString *lastNodeString = [lastTextNode stringValue];
						NSString *newString = [lastNodeString stringByAppendingString:ellipses];
						[lastTextNode setStringValue:newString];
					}
					else
					{
						// LOG((@"NEED TO ADD ELLIPSES AFTER %@", currentNode));
					}
				}
				
				result = [theBody XMLStringWithOptions:NSXMLDocumentTidyXML];
				// DON'T use NSXMLNodePreserveAll -- it converted " to ' and ' to &apos;  !!!
				
				NSRange rangeOfBodyStart = [result rangeOfString:@"<body>" options:0];
				NSRange rangeOfBodyEnd   = [result rangeOfString:@"</body>" options:NSBackwardsSearch];
				if (NSNotFound != rangeOfBodyStart.location && NSNotFound != rangeOfBodyEnd.location)
				{
					int sPos = NSMaxRange(rangeOfBodyStart);
					int len  = rangeOfBodyEnd.location - sPos;
					result = [result substringWithRange:NSMakeRange(sPos,len)];
				}
			}
		}
	}
	if (outDidTruncate)
	{
		*outDidTruncate = removedAnything;
	}
	OBPRECONDITION(result);
	return result;
}

- (NSAttributedString *)attributedHTMLStringWithTruncation:(NSUInteger)maxItemLength
                                                      type:(SVTruncationType)truncationType
                                         includeLargeMedia:(BOOL)includeLargeMedia
                                               didTruncate:(BOOL *)truncated;
{
    // take the normally generated HTML for the summary  
    
    // complete page markup would be:
    NSString *markup = [self string];
	
    
    NSString *truncatedMarkup = [self truncateMarkup:markup truncation:maxItemLength truncationType:truncationType didTruncate:truncated];
  
#ifdef DEBUG
	if ([NSUserName() isEqualToString:@"dwood"])			// DEBUGGGING OF TRUNCATION FOR DAN.
	{
		int offset = 0;
		NSRange whereAttachment = NSMakeRange(0,0);
		while (whereAttachment.location != NSNotFound)
		{
			whereAttachment = [markup rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(NSAttachmentCharacter, 1)] options:0 range:NSMakeRange(offset, [markup length] - offset) ];
			if (NSNotFound != whereAttachment.location)
			{
				DJW((@"Source: Attachment at offset %d", whereAttachment.location));
				offset = whereAttachment.location + 1;
			}
		}
		
		// Now do the same with the Trunc'd
		offset = 0;
		whereAttachment = NSMakeRange(0,0);
		while (whereAttachment.location != NSNotFound)
		{
			whereAttachment = [truncatedMarkup rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(NSAttachmentCharacter, 1)] options:0 range:NSMakeRange(offset, [truncatedMarkup length] - offset) ];
			if (NSNotFound != whereAttachment.location)
			{
				DJW((@"Truncd: Attachment at offset %d", whereAttachment.location));
				offset = whereAttachment.location + 1;
			}
		}
	}
#endif
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc]
                                         initWithString:truncatedMarkup];
    
    for (SVTextAttachment *anAttachment in [self attachments])
    {
        // Unlike when normally building an attributed string, some attachments might come after the truncation point, so we need to test for that
        
        NSRange range = [anAttachment range];
        if (range.location < [result length])
        {
            if ([[result string] characterAtIndex:range.location] == NSAttachmentCharacter)
            {
				BOOL causesWrap = [[anAttachment causesWrap] boolValue];
				if (includeLargeMedia || !causesWrap)
				{
					[result addAttribute:@"SVAttachment" value:anAttachment range:range];
				}
				else
				{
					// Hmm, do I need to remove the attachment character?
				}
            }
			else
			{
				OFF((@"Expecting an attachment character at %d", range.location));
			}
        }
    }
    
    return [result autorelease];
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
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
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
