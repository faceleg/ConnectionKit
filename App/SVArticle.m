// 
//  SVArticle.m
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArticle.h"

#import "SVGraphic.h"
#import "SVHTMLContext.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
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
        thumbnailGraphic = [[[self orderedAttachments] firstObjectKS] graphic];
        [page setThumbnailSourceGraphic:thumbnailGraphic];
    }
    
    
    // Similarly, photocasts & podcasts want a graphic for their enclosure
    [page guessEnclosures];
}

#pragma mark Truncation

- (NSString *)truncateMarkup:(NSString *)markup truncation:(NSUInteger)maxCount truncationType:(SVTruncationType)truncationType didTruncate:(BOOL *)outDidTruncate;
{
	OBPRECONDITION(markup);
	NSString *result = markup;
	BOOL removedAnything = NO;
	if ((kTruncateNone != truncationType) && maxCount)	// only do something if we want to actually truncate something
	{
		// Only want run through this if:
		// 1. We are truncating something other than characters, OR....
		// 2. We are truncating characters, and our maximum [character] count is shorter than the actual length we have.
		if (truncationType != kTruncateCharacters || maxCount < [result length])
		{			
			// Turn Markup into a tidied XML document
			NSError *theError = NULL;
			
			NSString *prelude = [KTPage stringFromDocType:KTXHTMLTransitionalDocType local:YES];

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
						
			NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:wrapper options:mask error:&theError] autorelease];
			if (theError) DJW((@"NSXMLDocument from truncation: %@", theError));
			NSArray *theNodes = [xmlDoc nodesForXPath:@"/html/body" error:&theError];
			NSXMLNode *currentNode = [theNodes lastObject];		// working node we traverse
			NSXMLNode *previousNode = nil;
			NSXMLNode *lastTextNode = nil;
			NSXMLElement *theBody = [theNodes lastObject];	// the body that we we will be truncating
			int accumulator = 0;
			int charCount = 0;
			BOOL inlineTag = NO;	// for word scanning; if inline, we may count next text as part of previous
			BOOL endedWithWhitespace = YES;	// for word scanning; if last word ends with whitespace, next token is a word.
			BOOL didSplitWord = NO;	// for character scanning; this lets us know if a word was truncated midway.  Doesn't really work in cases like abso<i>lutely</i>
			while (nil != currentNode)
			{
				if (NSXMLTextKind == [currentNode kind])
				{
					NSString *thisString = [currentNode stringValue];	// renders &amp; etc.
					if (kTruncateCharacters == truncationType)
					{
						lastTextNode = currentNode;		// when we are done, we will add ellipses
						unsigned int newAccumulator = accumulator + [thisString length];
						if (newAccumulator >= maxCount)	// will we need to prune?
						{
							int truncateIndex = maxCount - accumulator;
							NSString *truncd = [thisString smartSubstringWithMaxLength:truncateIndex didSplitWord:&didSplitWord];
							
							[currentNode setStringValue:truncd];	// re-escapes &amp; etc.
							
							break;		// we will now remove everything after "node"
						}
						charCount = accumulator = newAccumulator;
					}
					else if (kTruncateWords == truncationType || kTruncateSentences == truncationType)
					{
						// Note: Word truncation is not perfect. :-\  Ideally we would truncate after
						// the last word, not truncate to include the last word.  Otherwise we lose
						// punctuation, say, if the truncation happens to happen right after the end of a sentence.
						// However, it's certainly good enough!
						
						NSUInteger len = [thisString length];
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
						BOOL firstWord = YES;
						
						while(!stopWordScan && 
							  (kCFStringTokenizerTokenNone != (tokenType = CFStringTokenizerAdvanceToNextToken(tokenRef))) )
						{
							CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenRef);
							DJW((@"'%@' found at %d+%d", [thisString substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)], tokenRange.location, tokenRange.length));
							if (firstWord)
							{
								firstWord = NO;
								// Check for space BEFORE first word - we may need to increment previous counter.
								if (tokenRange.location > 0 && accumulator >= maxCount)
								{
									stopWordScan = YES;
									DJW((@"String starts with whitespace.  Early exit from word count, accumulator = %d", accumulator));
								}
								else if (inlineTag && !endedWithWhitespace && 0 == tokenRange.location)
								{
									DJW((@"#### Not incrementing accumulator (%d) since we are still inline.", accumulator));
								}
								else
								{
									++accumulator;
									DJW((@"First word; ++accumulator = %d", accumulator));
								}
							}
							else	// other words, just increment the accumulator
							{
								++accumulator;
								DJW((@"++accumulator = %d", accumulator));
							}
                            
							if (!stopWordScan)	// don't increment if we early-exited above
							{
								lastWord = tokenRange.location + tokenRange.length;
								lastTextNode = currentNode;		// If this is the last node we are scanning, we will add ellipses to this
							}
                            
							if (accumulator >= maxCount)
							{
								stopWordScan = YES;
								DJW((@"early exit from word count, accumulator = %d", accumulator));
							}
						}
						CFRelease(tokenRef);
						DJW((@"in '%@' max=%d len=%d", thisString, lastWord, len));
						endedWithWhitespace = (lastWord < len);
						if (accumulator >= maxCount)
						{
							if (lastWord < len)
							{
								NSString *partialString = [thisString substringToIndex:lastWord];
								DJW((@"accumulator = %d; Truncating to '%@'", accumulator, partialString));
								[currentNode setStringValue:partialString];	// re-escapes &amp; etc.
								DJW((@"... and breaking from loop; we're done, since this is really truncating"));
								break;		// exit outer loop, so we stop scanning
							}
							else
							{
								DJW((@"We are out of words, but not breaking here in case we hit inline to follow"));
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
							if (++accumulator >= maxCount)
							{
								break;	// we will now remove everything after "node"
							}
						}
					}
					else if (kTruncateWords == truncationType || kTruncateSentences == truncationType)
					{
						DJW((@"<%@>", [theElement name]));
						static NSSet *sInlineTags = nil;
						if (!sInlineTags)
						{
							// TODO: Unify with -[KSHTMLWriter canWriteElementInline]. Class method?
							sInlineTags = [[NSSet alloc] initWithObjects:
                                           @"a", @"b", @"i", @"br", @"em", @"img", @"sup", @"sub", @"big", @"span", @"font", @"small", @"strong", nil];
						}
						inlineTag = [sInlineTags containsObject:[theElement name]];
						if (!inlineTag)
						{
							// Not an inline tag; see if we should just stop now.
							DJW((@"Not an inline tag, so consider this a word break"));
							if (accumulator >= maxCount)
							{
								currentNode = previousNode;	// Back up - that's the node we should remove things after!
								DJW((@"accumulator = %d; at following non-inline tag, time to STOP", accumulator));
								break;
							}
						}
					}
				}
				previousNode = currentNode;
				currentNode = [currentNode nextNode];
			}
			
			removedAnything = [theBody removeAllNodesAfter:(NSXMLElement *)currentNode];
			if (removedAnything)
			{
				DJW((@"Removed some stuff"));
			}
			else
			{
				DJW((@"Did NOT remove some stuff"));
			}
			if (removedAnything)
			{
				if (lastTextNode)
				{
					// Trucate, plus add on an ellipses.  (Space before ellipses if we didn't break a word up.)
					NSString *theFormat = NSLocalizedString(@"%@…", @"something followed by ellipses to show that we cut it off");
					NSString *lastNodeString = [lastTextNode stringValue];
					NSString *newString = [NSString stringWithFormat:theFormat,
										   lastNodeString];
					[lastTextNode setStringValue:newString];
				}
				else
				{
					LOG((@"NEED TO ADD ELLIPSES AFTER %@", currentNode));
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
                [result addAttribute:@"SVAttachment" value:anAttachment range:range];
            }
			else
			{
				DJW((@"Expecting an attachment character at %d", range.location));
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

@end
