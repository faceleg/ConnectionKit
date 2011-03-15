//
//  SVAttributedHTML.m
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVAttributedHTML.h"

#import "SVGraphic.h"
#import "SVHTMLContext.h"
#import "KTPage.h"
#import "SVTextAttachment.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSString+Karelia.h"
#import "NSXMLElement+Karelia.h"


@implementation NSAttributedString (SVAttributedHTML)

#pragma mark Serialization

- (NSData *)serializedProperties
{
    // Create a clone where SVTextAttachment is replaced by its serialized form
    NSMutableAttributedString *archivableAttributedString = [self mutableCopy];
    
    NSRange range = NSMakeRange(0, [archivableAttributedString length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVTextAttachment *textAttachment = [archivableAttributedString attribute:@"SVAttachment"
                                                              atIndex:location
                                                longestEffectiveRange:&effectiveRange
                                                              inRange:range];
        
        if (textAttachment)
        {
            NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
            
            // Replace the attachment. Ignore range as it's not relevant any more
            [textAttachment populateSerializedProperties:plist];
            [plist removeObjectForKey:@"location"];
            [plist removeObjectForKey:@"length"];
            
            [archivableAttributedString removeAttribute:@"SVAttachment"
                                                  range:effectiveRange];
            
            [archivableAttributedString addAttribute:@"Serialized SVAttachment"
                                               value:plist
                                               range:effectiveRange];
            
            [plist release];
        }
        
        
        // Advance the search
        location = effectiveRange.location + effectiveRange.length;
    }
    
    NSData *result = [NSKeyedArchiver archivedDataWithRootObject:archivableAttributedString];
    [archivableAttributedString release];
    
    return result;
}

- (void)attributedHTMLStringWriteToPasteboard:(NSPasteboard *)pasteboard;
{
    // Write to the pboard in archive form
    [pasteboard setData:[self serializedProperties] forType:@"com.karelia.html+graphics"];
}

#pragma mark Deserialization

+ (NSAttributedString *)attributedHTMLFromPasteboard:(NSPasteboard *)pasteboard;
{
    NSData *data = [pasteboard dataForType:@"com.karelia.html+graphics"];
    if (!data) return nil;
    
    
    NSAttributedString *result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return result;
}

+ (NSAttributedString *)attributedHTMLStringFromPasteboard:(NSPasteboard *)pasteboard
                                insertAttachmentsIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSData *data = [pasteboard dataForType:@"com.karelia.html+graphics"];
    if (!data) return nil;
    
    
    NSAttributedString *result = [self attributedHTMLStringWithPropertyList:data
                                  insertAttachmentsIntoManagedObjectContext:context];
    return result;
}

+ (NSAttributedString *)attributedHTMLStringWithPropertyList:(NSData *)data
                   insertAttachmentsIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    OBPRECONDITION(data);
    NSAttributedString *archivedAttributedString = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (!archivedAttributedString) return nil;
    
    
    NSMutableAttributedString *result = [[archivedAttributedString mutableCopy] autorelease];
    
    
    // Create attachment objects for each serialized one
    NSRange range = NSMakeRange(0, [result length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        id serializedProperties = [result attribute:@"Serialized SVAttachment"
                                            atIndex:location
                              longestEffectiveRange:&effectiveRange
                                            inRange:range];
        
        if (serializedProperties)
        {
            // Replace the attachment
            SVTextAttachment *attachment = [SVTextAttachment insertNewTextAttachmentInManagedObjectContext:context];
            [attachment awakeFromPropertyList:serializedProperties];
            
            [result removeAttribute:@"Serialized SVAttachment"
                              range:effectiveRange];
            
            [result addAttribute:@"SVAttachment"
                           value:attachment
                           range:effectiveRange];
        }
        
        // Advance the search
        location = effectiveRange.location + effectiveRange.length;
    }
    
    
    return result;
}

+ (NSArray *)pageletsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSMutableArray *result = [NSMutableArray array];
    NSAttributedString *archive = [self attributedHTMLFromPasteboard:pasteboard];
    
    
    // Create attachment objects for each serialized one
    NSRange range = NSMakeRange(0, [archive length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        id serializedProperties = [archive attribute:@"Serialized SVAttachment"
                                             atIndex:location
                               longestEffectiveRange:&effectiveRange
                                             inRange:range];
        
        if (serializedProperties)
        {
            // Replace the attachment
            id serializedGraphic = [serializedProperties valueForKey:@"graphic"];
            
            SVGraphic *graphic = [SVGraphic graphicWithSerializedProperties:serializedGraphic
                                             insertIntoManagedObjectContext:context];
            
            [result addObject:graphic];
        }
        
        // Advance the search
        location = location + effectiveRange.length;
    }
    
    
    return result;
}

#pragma mark Pboard support

+ (NSArray *)attributedHTMStringPasteboardTypes;
{
    return [NSArray arrayWithObject:@"com.karelia.html+graphics"];
}

#pragma mark Convenience

+ (NSAttributedString *)attributedHTMLStringWithAttachment:(id)attachment;
{
    NSAttributedString *result = [[NSAttributedString alloc]
      initWithString:[NSString stringWithUnichar:NSAttachmentCharacter]
      attributes:[NSDictionary dictionaryWithObject:attachment forKey:@"SVAttachment"]];
                                  
    return [result autorelease];
}

+ (NSAttributedString *)attributedHTMLStringWithGraphic:(SVGraphic *)graphic;
{
    OBPRECONDITION(graphic);
    
    // Create attachment for the graphic
    SVTextAttachment *textAttachment = [SVTextAttachment textAttachmentWithGraphic:graphic];
    //[textAttachment setBody:text];
    
    
    // Finish up
    return [self attributedHTMLStringWithAttachment:textAttachment];
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
	LOG((@"TRUNCATE TO: %d [%d]", maxItemLength, truncationType));
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
			if (theError) LOG((@"NSXMLDocument err from truncation: %@", theError));
			
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

- (void)collapseHTMLStringAttachments:(NSMutableAttributedString *)result;
{
	// Go through attributed strings, looking for range with attachment, and substitute a single attachment character
	[result beginEditing];
	
	NSString *oneAttachmentCharString = [NSString stringWithUnichar:NSAttachmentCharacter];
	
	NSUInteger cursor = 0;
	while (cursor < [result length]) 
	{
		NSRange effectiveRange;
		
		// - (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)aRange inRange:(NSRange)rangeLimit
        
		SVTextAttachment *att = [result attribute:@"SVAttachment" atIndex:cursor effectiveRange:&effectiveRange];
		if(att)
		{
			[result replaceCharactersInRange:effectiveRange withString:oneAttachmentCharString];
			cursor+=1;
		}
		else
		{
			cursor = NSMaxRange(effectiveRange);
		}
	}
    
	[result endEditing];
}



- (NSAttributedString *)attributedHTMLStringWithTruncation:(NSUInteger)maxItemLength
                                                      type:(SVTruncationType)truncationType
                                         includeLargeMedia:(BOOL)includeLargeMedia
                                               didTruncate:(BOOL *)truncated;
{
    // take the normally generated HTML for the summary  
    
    // complete page markup would be:
    NSMutableAttributedString *untruncatedHTML = [[self mutableCopy] autorelease];
    [self collapseHTMLStringAttachments:untruncatedHTML];
    
    NSString *truncatedMarkup = [self truncateMarkup:[untruncatedHTML string]
                                          truncation:maxItemLength
                                      truncationType:truncationType
                                         didTruncate:truncated];
    
#if 0
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
    
    
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:truncatedMarkup];
    
    // Scan the result for attachments, grabbing them from untruncated HTML
    NSString *oneAttachmentCharString = [NSString stringWithUnichar:NSAttachmentCharacter];
    
    NSRange sRange = NSMakeRange(0, [untruncatedHTML length]);
	NSRange dRange = NSMakeRange(0, [result length]);
    
    while (dRange.length)
    {
        // Seek an attachment in the result
        NSRange dAttachmentRange = [[result string] rangeOfString:oneAttachmentCharString
                                                          options:0
                                                            range:dRange];
        
        if (dAttachmentRange.location == NSNotFound) break;
        
        NSUInteger increment = NSMaxRange(dAttachmentRange) - dRange.location;
        dRange.location += increment; dRange.length -= increment;
        
        
        // Seek corresponding attachment in the source
        NSRange sAttachmentRange = [[untruncatedHTML string] rangeOfString:oneAttachmentCharString
                                                                   options:0
                                                                     range:sRange];
        
        if (sAttachmentRange.location == NSNotFound) break;
        
        increment = NSMaxRange(sAttachmentRange) - sRange.location;
        sRange.location += increment; sRange.length -= increment;
        
        SVTextAttachment *attachment = [untruncatedHTML attribute:@"SVAttachment"
                                                          atIndex:sAttachmentRange.location
                                                   effectiveRange:NULL];
        
        // Copy the actual attachment across to the result
        if (attachment)
        {
            BOOL causesWrap = [[attachment causesWrap] boolValue];
            if (includeLargeMedia || !causesWrap)
            {    
                [result addAttribute:@"SVAttachment" value:attachment range:dAttachmentRange];
            }
        }
    }
    
    
    return [result autorelease];
}

@end
