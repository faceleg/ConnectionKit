//
//  KTWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//


#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser+Private.h"

#import "KTDesign.h"
#import "SVMutableStringHTMLContext.h"
#import "KTMaster+Internal.h"
#import "KTAbstractPage+Internal.h"
#import "KTPage+Internal.h"
#import "SVBody.h"
#import "SVTextField.h"

#import "KTMediaManager+Internal.h"
#import "KTScaledImageContainer.h"
#import "KTGraphicalTextMediaContainer.h"
#import "KTMediaFile.h"
#import "KTMediaFileUpload.h"

#import "NSObject+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "Debug.h"
#import "Macros.h"


@implementation SVHTMLTextBlock

#pragma mark Init & Dealloc

- (id)init
{
    self = [super init];
    
    if (self)
    {
        myIsEditable = YES;
        [self setTagName:@"div"];
    }
	
	return self;
}

- (void)dealloc
{
    [_placeholder release];
	[myHTMLTag release];
    [_className release];
	[myGraphicalTextCode release];
	[myHyperlinkString release];
	[myTargetString release];
	[myHTMLSourceObject release];
	[myHTMLSourceKeyPath release];
    
	[super dealloc];
}

#pragma mark Accessors

- (NSString *)DOMNodeID
{
    id value = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	if ([value isKindOfClass:[SVContentObject class]])
    {
        return [value editingElementID];
    }
    else
    {
        NSString *result = [NSString stringWithFormat:@"k-svxTextBlock-%@-%p",
                            [self HTMLSourceKeyPath],
                            [self HTMLSourceObject]];
        
        return result;
    }
}

/*	Many bits of editable text contain a tag like so:
 *		<span class="in">.....</span>
 *	If so, this method returns YES.
 */
- (BOOL)hasSpanIn { return myHasSpanIn; }

- (void)setHasSpanIn:(BOOL)flag { myHasSpanIn = flag; }

@synthesize placeholderString = _placeholder;

@synthesize tagName = myHTMLTag;
- (void)setTagName:(NSString *)tag
{
	OBPRECONDITION(tag);
	
	tag = [tag copy];
	[myHTMLTag release];
	myHTMLTag = tag;
}

@synthesize customCSSClassName = _className;

- (NSString *)CSSClassName;
{
    NSMutableArray *classNames = [[NSMutableArray alloc] init];
    
    
    // Any custom classname specifed
    if ([[self customCSSClassName] length] > 0)
    {
        [classNames addObject:[self customCSSClassName]];
    }
    
    
    // Editing
    if ([self isEditable])
    {
        if ([[SVHTMLContext currentContext] isEditable])
        { 
            [classNames addObject:([self isRichText] ? @"kBlock" : @"kLine")];
        }
    }
    else
    {
        [classNames addObject:@"in"];
    }
    
    
    // Turn into a single string
    NSString *result = [classNames componentsJoinedByString:@" "];
    [classNames release];
    return result;
}

- (NSString *)hyperlinkString { return myHyperlinkString; }

- (void)setHyperlinkString:(NSString *)hyperlinkString
{
	// We can't have a hyperlinkString and be editable at the same time
	if ([self isEditable]) [self setEditable:NO];
	
	hyperlinkString = [hyperlinkString copy];
	[myHyperlinkString release];
	myHyperlinkString = hyperlinkString;
}

- (NSString *)targetString { return myTargetString; }

- (void)setTargetString:(NSString *)targetString
{
	targetString = [targetString copy];
	[myTargetString release];
	myTargetString = targetString;
}


- (id)HTMLSourceObject { return myHTMLSourceObject; }

- (void)setHTMLSourceObject:(id)object
{
	[object retain];
	[myHTMLSourceObject release];
	myHTMLSourceObject = object;
}

- (NSString *)HTMLSourceKeyPath { return myHTMLSourceKeyPath; }

- (void)setHTMLSourceKeyPath:(NSString *)keyPath
{
	keyPath = [keyPath copy];
	[myHTMLSourceKeyPath release];
	myHTMLSourceKeyPath = keyPath;
}

#pragma mark NSTextView clone

- (BOOL)isEditable { return myIsEditable; }

- (void)setEditable:(BOOL)flag { myIsEditable = flag; }

- (BOOL)isFieldEditor { return myIsFieldEditor; }

- (void)setFieldEditor:(BOOL)flag { myIsFieldEditor = flag; }

- (BOOL)isRichText { return myIsRichText; }

- (void)setRichText:(BOOL)flag { myIsRichText = flag; }

- (BOOL)importsGraphics { return myImportsGraphics; }

- (void)setImportsGraphics:(BOOL)flag { myImportsGraphics = flag; }


#pragma mark Graphical Text

/*	When the code is a non-nil value, if the design specifies it, we swap the text for special Quartz Composer
 *	generated images.
 */
- (NSString *)graphicalTextCode { return myGraphicalTextCode; }

- (void)setGraphicalTextCode:(NSString *)code
{
	code = [code copy];
	[myGraphicalTextCode release];
	myGraphicalTextCode = code;
}

- (KTMediaContainer *)graphicalTextMedia
{
	KTMediaContainer *result = nil;
	
	NSString *graphicalTextCode = [self graphicalTextCode];
    if (graphicalTextCode)
    {
        NSMutableString *innerHTML = [[NSMutableString alloc] init];
        SVMutableStringHTMLContext *context = [[SVMutableStringHTMLContext alloc] initWithMutableString:innerHTML];
        [context push];
        [self writeInnerHTML];
        [context pop];
        [context release];
        
        if (innerHTML && ![innerHTML isEqualToString:@""])
        {
            KTPage *page = (KTPage *)[[SVHTMLContext currentContext] currentPage];		OBASSERT(page);
            KTMaster *master = [page master];
            if ([master boolForKey:@"enableImageReplacement"])
            {
                KTDesign *design = [master design];
                NSDictionary *graphicalTextSettings = [[design imageReplacementTags] objectForKey:graphicalTextCode];
                if (graphicalTextSettings)
                {
                    // Generate the image
                    KTMediaManager *mediaManager = [[[page site] document] mediaManager];
                    result = [mediaManager graphicalTextWithString:[innerHTML stringByConvertingHTMLToPlainText]
                                                            design:design
                                              imageReplacementCode:graphicalTextCode
                                                              size:[master floatForKey:@"graphicalTitleSize"]];
                }
            }
        }
	}
    
	return result;
}

- (NSString *)graphicalTextCSSID
{
    NSString *result = nil;
    
    NSString *mediaID = [[[self graphicalTextMedia] file] valueForKey:@"uniqueID"];
    if (mediaID)
    {
        result = [@"graphical-text-" stringByAppendingString:mediaID];
    }
    
    return result;
}

/*	Returns nil if there is no graphical text in use
 */
- (NSString *)graphicalTextPreviewStyle
{
	NSString *result = nil;
	
	KTMediaContainer *image = [self graphicalTextMedia];
	KTMediaFile *mediaFile = [image file];
	if (mediaFile)
	{			
		[mediaFile cacheImageDimensionsIfNeeded];
        
        result = [NSString stringWithFormat:
			@"text-align:left; text-indent:-9999px; background:url(%@) top left no-repeat; width:%ipx; height:%ipx;",
			[[NSURL fileURLWithPath:[mediaFile currentPath]] absoluteString],
			[mediaFile integerForKey:@"width"],
			[mediaFile integerForKey:@"height"]];
	}
	
	return result;
}

#pragma mark HTML

- (void)writeInnerHTML;
{
	NSString *result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
    if ([result isKindOfClass:[SVBody class]])
    {
        [(SVBody *)result writeHTML];
    }
    else if ([result isKindOfClass:[SVTextField class]])
    {
        [[SVHTMLContext currentContext] writeHTMLString:[(SVTextField *)result textHTMLString]];
    }
    else
    {
        result = [self processHTML:result];
        if (result) [[SVHTMLContext currentContext] writeHTMLString:result];
    }
}

/*	Includes the editable tag(s) + innerHTML
 */
- (void)writeHTML;
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
	
    // Construct the actual HTML
    [context openTag:[self tagName]];
	
	
	// Open the main tag
	// In some situations we generate both the main tag, and a <span class="in">
    if ([[SVHTMLContext currentContext] isEditable])
    {
        [context writeAttribute:@"id" value:[self DOMNodeID]];
    }
    
	BOOL generateSpanIn = ([self isFieldEditor] && ![self hasSpanIn] && ![[self tagName] isEqualToString:@"span"]);
	// if (!generateSpanIn)	// Actually we want a custom class to show up even items with a span-in. 
	{
		[context writeAttribute:@"class" value:[self CSSClassName]];
	}
	
	// TODO: Add in graphical text styling if there is any
	//if ([[self parser] includeStyling])
	{
		NSString *graphicalTextStyle = [self graphicalTextPreviewStyle];
		if (graphicalTextStyle)
		{
			if ([[SVHTMLContext currentContext] isEditable])    // id has already been supplied
			{
                [context writeAttribute:@"class" value:@"replaced"];
                [context writeAttribute:@"style" value:graphicalTextStyle];
			}
			else
			{
                [context writeAttribute:@"id" value:[self graphicalTextCSSID]];
                [context writeAttribute:@"class" value:@"replaced"];
			}
		}
	}
	
	
	// Close off the main tag
	[context closeStartTag];
	
	
	
	// Place a hyperlink if required
	if ([self hyperlinkString])
	{
		[context openTag:@"a "];
        [context writeString:[self targetString]];
        [context writeAttribute:@"href" value:[self hyperlinkString]];
        [context closeStartTag];
	}
	
	// Generate <span class="in"> if desired
	if (generateSpanIn)	// For normal, single-line text the span is the editable bit
	{
        NSString *CSSClassName = @"in";
        if ([self isEditable] && [[SVHTMLContext currentContext] isEditable])
		{
			CSSClassName = [CSSClassName stringByAppendingString:([self isRichText]) ? @" kBlock" : @" kLine"];
		}
		
        [context writeStartTag:@"span" idName:nil className:CSSClassName];
	}
	
	
	// Stick in the main HTML
	[self writeInnerHTML];
	
	
	// Write end tags
	if (generateSpanIn) [context writeEndTag];
	if ([self hyperlinkString]) [context writeEndTag];
	[context writeEndTag];
}

/*!	Given the page text, scan for all page ID references and convert to the proper relative links.
 */
- (NSString *)fixPageLinksFromString:(NSString *)originalString
{
	NSMutableString *buffer = [NSMutableString string];
	if (originalString)
	{
		NSScanner *scanner = [NSScanner scannerWithString:originalString];
		while (![scanner isAtEnd])
		{
			NSString *beforeLink = nil;
			BOOL found = [scanner scanUpToString:kKTPageIDDesignator intoString:&beforeLink];
			if (found)
			{
				[buffer appendString:beforeLink];
				if (![scanner isAtEnd])
				{
					[scanner scanString:kKTPageIDDesignator intoString:nil];
					NSString *idString = nil;
					BOOL foundNumber = [scanner scanCharactersFromSet:[KTAbstractPage uniqueIDCharacters]
														   intoString:&idString];
					if (foundNumber)
					{
						KTPage *thePage = [KTPage pageWithUniqueID:idString inManagedObjectContext:[[self HTMLSourceObject] managedObjectContext]];
						NSString *newPath = nil;
						if (thePage)
						{
							newPath = [[thePage URL] stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
						}
						
						if (!newPath) newPath = @"#";	// Fallback
						[buffer appendString:newPath];
					}
				}
			}
		}
	}
	return [NSString stringWithString:buffer];
}


/*  Support method that takes a block of HTML and applies to it anything special the receiver and the parser require
 */
- (NSString *)processHTML:(NSString *)result
{
    // Perform additional processing of the text according to HTML generation purpose
	if (![[SVHTMLContext currentContext] isEditable])
	{
		// Fix page links
		result = [self fixPageLinksFromString:result];
		
		
		
		if ([self importsGraphics] && result)
		{
			// Convert media source paths
			NSScanner *scanner = [[NSScanner alloc] initWithString:result];
			NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:[result length]];
			NSString *aString;	NSString *aMediaPath;
			
			while (![scanner isAtEnd])
			{
				[scanner scanUpToString:@" src=\"" intoString:&aString];
				OBASSERT(aString);
				[buffer appendString:aString];
				if ([scanner isAtEnd]) break;
				
				[buffer appendString:@" src=\""];
				[scanner setScanLocation:([scanner scanLocation] + 6)];
				
				if ([scanner scanUpToString:@"\"" intoString:&aMediaPath])
				{
					NSURL *aMediaURI = [NSURL URLWithString:aMediaPath];
					
					// Replace the path with one suitable for the specified purpose
					KTMediaContainer *mediaContainer = [KTMediaContainer mediaContainerForURI:aMediaURI];
					if (mediaContainer)
					{
						if ([[SVHTMLContext currentContext] generationPurpose] == kGeneratingQuickLookPreview)
						{
							aMediaPath = [[mediaContainer file] quickLookPseudoTag];
						}
						else
						{
							KTMediaFile *mediaFile = [mediaContainer sourceMediaFile];
                            KTMediaFileUpload *upload = [mediaFile uploadForScalingProperties:[(KTScaledImageContainer *)mediaContainer latestProperties]];
							aMediaPath = [[upload URL] stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
							
							// TODO: Tell the parser's delegate
							//[[self parser] didEncounterMediaFile:mediaFile upload:upload];
						}
					}
					
					
					// Add the processed path back in. For external images, it should remain unchanged
					if (aMediaPath) [buffer appendString:aMediaPath];
				}
			}
			
			
			// Finish up
			result = [NSString stringWithString:buffer];
			[buffer release];
			[scanner release];
		}
	}
    
    
    
    return result;
}

@end
