//
//  KTWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//


#import "SVHTMLTemplateTextBlock.h"
#import "SVHTMLTemplateParser+Private.h"


#import "DOM+KTWebViewController.h"
#import "DOMNode+KTExtensions.h"

#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocWebViewController.h"
#import "KTMaster+Internal.h"
#import "KTAbstractPage+Internal.h"
#import "KTPage+Internal.h"

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

@interface SVHTMLTemplateTextBlock ()

+ (void)convertFileListElement:(DOMHTMLDivElement *)div toImageWithSettingsNamed:(NSString *)settingsName forPlugin:(KTAbstractElement *)element;

@end


@implementation SVHTMLTemplateTextBlock

#pragma mark -
#pragma mark Init & Dealloc

- (id)init
{
    return [self initWithParser:nil];
}

- (id)initWithParser:(SVHTMLTemplateParser *)parser;
{
	OBPRECONDITION(parser);
    
    self = [super init];
    
    if (self)
    {
        myParser = [parser retain];
        
        myIsEditable = YES;
        [self setHTMLTag:@"div"];
    }
	
	return self;
}

- (void)dealloc
{
	OBASSERT(!myIsEditing);
	
	[myDOMNode release];
	[myHTMLTag release];
	[myGraphicalTextCode release];
	[myHyperlinkString release];
	[myTargetString release];
	[myHTMLSourceObject release];
	[myHTMLSourceKeyPath release];
    [myParser release];
    
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (SVHTMLTemplateParser *)parser { return myParser; }

- (KTWebViewComponent *)webViewComponent { return myWebViewComponent; }

- (void)setWebViewComponent:(KTWebViewComponent *)component { myWebViewComponent = component; }	// Weak ref

- (NSString *)DOMNodeID
{
	NSString *result = [NSString stringWithFormat:@"k-svxTextBlock-%@-%p",
						[self HTMLSourceKeyPath],
						[self HTMLSourceObject]];
	
	// We used to just use  [NSString shortUUIDString], but that changes with each webview refresh
	return result;
}

- (DOMHTMLElement *)DOMNode { return myDOMNode; }

- (void)setDOMNode:(DOMHTMLElement *)node
{
	[node retain];
	[myDOMNode release];
	myDOMNode = node;
}

/*	Many bits of editable text contain a tag like so:
 *		<span class="in">.....</span>
 *	If so, this method returns YES.
 */
- (BOOL)hasSpanIn { return myHasSpanIn; }

- (void)setHasSpanIn:(BOOL)flag { myHasSpanIn = flag; }


- (NSString *)HTMLTag { return myHTMLTag; }

- (void)setHTMLTag:(NSString *)tag
{
	OBPRECONDITION(tag);
	
	tag = [tag copy];
	[myHTMLTag release];
	myHTMLTag = tag;
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


#pragma mark -
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
    NSString *innerHTML = [self innerHTML];
	if (graphicalTextCode && innerHTML && ![innerHTML isEqualToString:@""])
	{
		KTPage *page = (KTPage *)[[self parser] currentPage];		OBASSERT(page);
		KTMaster *master = [page master];
		if ([master boolForKey:@"enableImageReplacement"])
		{
			KTDesign *design = [master design];
			NSDictionary *graphicalTextSettings = [[design imageReplacementTags] objectForKey:graphicalTextCode];
			if (graphicalTextSettings)
			{
				// Generate the image
				KTMediaManager *mediaManager = [page mediaManager];
				result = [mediaManager graphicalTextWithString:[innerHTML stringByConvertingHTMLToPlainText]
														design:design
										  imageReplacementCode:graphicalTextCode
														  size:[master floatForKey:@"graphicalTitleSize"]];
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

#pragma mark -
#pragma mark HTML

- (NSString *)innerHTML
{
	NSString *result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	if (!result) result = @"";

	result = [self processHTML:result];
	return result;
}

/*	Includes the editable tag(s) + innerHTML
 */
- (NSString *)outerHTML
{
	// When publishing, generate an empty string (or maybe nil) for empty text blocks
	NSString *innerHTML = [self innerHTML];
	if ([[self parser] HTMLGenerationPurpose] != kGeneratingPreview && (!innerHTML || [innerHTML isEqualToString:@""]))
	{
		return @"";
	}
	
	
	// Construct the actual HTML
	NSMutableString *buffer = [NSMutableString stringWithFormat:@"<%@", [self HTMLTag]];
	
	
	// Open the main tag
	// In some situations we generate both the main tag, and a <span class="in">
	BOOL generateSpanIn = ([self isFieldEditor] && ![self hasSpanIn] && ![[self HTMLTag] isEqualToString:@"span"]);
	if (!generateSpanIn)
	{
		if ([self isEditable] && [[self parser] HTMLGenerationPurpose] == kGeneratingPreview)
		{
			[buffer appendFormat:
             @" id=\"%@\" class=\"%@\" contentEditable=\"true\"",
             [self DOMNodeID],
             ([self isRichText]) ? @"kBlock" : @"kLine"];
		}
		else if (![self isEditable])
		{
			[buffer appendString:@" class=\"in\""];
		}
	}
	
	
	// Add in graphical text styling if there is any
	if ([[self parser] includeStyling])
	{
		NSString *graphicalTextStyle = [self graphicalTextPreviewStyle];
		if (graphicalTextStyle)
		{
			if ([[self parser] HTMLGenerationPurpose] == kGeneratingPreview)
			{
				[buffer appendFormat:@" class=\"replaced\" style=\"%@\"", graphicalTextStyle];
			}
			else
			{
				[buffer appendFormat:@" id=\"%@\" class=\"replaced\"", [self graphicalTextCSSID]];
			}
		}
	}
	
	
	// Close off the main tag
	[buffer appendString:@">"];
	
	
	
	// Place a hyperlink if required
	if ([self hyperlinkString])
	{
		[buffer appendFormat:@"<a %@href=\"%@\">", [self targetString], [self hyperlinkString]];
	}
	
	// Generate <span class="in"> if desired
	if (generateSpanIn)	// For normal, single-line text the span is the editable bit
	{
		[buffer appendString:@"<span"];
        
        NSString *CSSClassName = @"in";
        if ([self isEditable] && [[self parser] HTMLGenerationPurpose] == kGeneratingPreview)
		{
			[buffer appendFormat:@" id=\"%@\" contentEditable=\"true\"", [self DOMNodeID]];
            CSSClassName = [CSSClassName stringByAppendingString:([self isRichText]) ? @" kBlock" : @" kLine"];
		}
		
        [buffer appendFormat:@" class=\"%@\">", CSSClassName];
	}
	
	
	// Stick in the main HTML
	[buffer appendString:innerHTML];
	
	
	// End all tags
	if (generateSpanIn)
	{
		[buffer appendString:@"</span>"];
	}
	if ([self hyperlinkString]) [buffer appendString:@"</a>"];
	[buffer appendFormat:@"</%@>", [self HTMLTag]];
	
	
	// Tidy up
	NSString *result = [NSString stringWithString:buffer];
	return result;
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
							newPath = [[thePage URL] stringRelativeToURL:[[[self parser] currentPage] URL]];
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
	if ([[self parser] HTMLGenerationPurpose] != kGeneratingPreview)
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
						if ([[self parser] HTMLGenerationPurpose] == kGeneratingQuickLookPreview)
						{
							aMediaPath = [[mediaContainer file] quickLookPseudoTag];
						}
						else
						{
							KTAbstractPage *page = [[self parser] currentPage];
							KTMediaFile *mediaFile = [mediaContainer sourceMediaFile];
                            KTMediaFileUpload *upload = [mediaFile uploadForScalingProperties:[(KTScaledImageContainer *)mediaContainer latestProperties]];
							aMediaPath = [[upload URL] stringRelativeToURL:[page URL]];
							
							// Tell the parser's delegate
							[[self parser] didEncounterMediaFile:mediaFile upload:upload];
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


/*	This method could probably do with a better name. It returns the HTML presently inside the DOM node.
 */
- (NSString *)liveInnerHTML
{
	NSString *result = [[self DOMNode] cleanedInnerHTML];
	// OK, the problem is when all we have left is <p><br />\n</p> .... this should really be empty.
	if (![[self DOMNode] hasVisibleContents])
	{
		result = @"";
	}
	
	return result;
}

#pragma mark -
#pragma mark Editing

- (BOOL)becomeFirstResponder
{
	OBASSERTSTRING(!myIsEditing, @"Can't become first responder, already editing");
	
	// <span class="in"> tags need to become blocks when beginning editing
	if ([self isFieldEditor] && ![self hasSpanIn])
	{
		[[self DOMNode] setAttribute:@"style" value:@"display:block;"];
	}
	
	
	// Graphical text needs to be turned off
	if ([self graphicalTextCode] && [self isFieldEditor] && ![self hasSpanIn])
	{
		DOMElement *node = (DOMElement *)[[self DOMNode] parentNode];
		[node removeAttribute:@"style"];
	}
    
    
    // If needed, reload inner HTML from disk. BUGSID:30635
    // TODO: Maintain the selection and merge in with our Summaries subclass
    NSString *expectedHTML = [self innerHTML];
    NSString *currentHTML = [[self DOMNode] innerHTML];
    if (!KSISEQUAL(expectedHTML, currentHTML) &&
        ![currentHTML isEqualToString:@"<p>Lorem ipsum dolor sit amet.</p>"])   // Hack for editing markers
    {
        [[self DOMNode] setInnerHTML:expectedHTML];
    }
    
	
	myIsEditing = YES;
	return YES;
}

- (void)removeDOMJunkAllowingEmptyParagraphs:(BOOL)allowEmptyParagraphs
{
	[[self DOMNode] removeJunkRecursiveRestrictive:NO allowEmptyParagraphs:allowEmptyParagraphs];
	
	
	// If this is a single line object, and it does not contain a single span, then insert a single span
	if ([self isFieldEditor])
	{
		// Let's try this .. we seem to get just a <br /> inside a node when the text is removed.  Let me try just removing that.
		
		// Here is really where we might want to remove any <p> paragraphs and separate multiple paragraphs by <br /> .... this would be to 'repair' old sites where we had paragraphs in the footer
		
		DOMNodeList *list = [[self DOMNode] childNodes];
		if ([list length] == 1)
		{
			DOMNode *firstChild = [list item:0];
			if ([[firstChild nodeName] isEqualToString:@"BR"])
			{
				[[self DOMNode] removeChild:firstChild];
			}
		}
		
	}
	else
	{
		//   <p><br />  [newline] </p>		... BUT DON'T EMPTY OUT IF A SCRIPT
		if (![[self DOMNode] hasVisibleContents])
		{
			DOMNodeList *list = [[self DOMNode] childNodes];
			int i, len = [list length];
			for ( i = 0 ; i < len ; i++ )
			{
				[[self DOMNode] removeChild:[list item:0]];
			}
		}
	}
}

/*	Another NSTextView clone method
 *	Performs appropriate actions at the end of editing.
 */
- (BOOL)resignFirstResponder
{
	OBASSERTSTRING(myIsEditing, @"Can't resign first responder, not currently editing");
	
	// Tidy up HTML
	[self removeDOMJunkAllowingEmptyParagraphs:YES];
	
	
	// Save the HTML to our source object
	BOOL result = [self commitEditing];
	
	
	if (result)
	{
		// Put the span class="in" back into the HTML
		if ([self hasSpanIn])
		{
			NSString *newInnerHTML =
				[NSString stringWithFormat:@"<span class=\"in\">%@</span>", [[self DOMNode] cleanedInnerHTML]];
			[[self DOMNode] setInnerHTML:newInnerHTML];
		}
	
	
		// <span class="in"> tags need to become blocks when beginning editing
		if ([self isFieldEditor] && ![self hasSpanIn])
		{
			[[self DOMNode] removeAttribute:@"style"];
		}

		
		// Graphical text needs to be turned back on
		if ([self graphicalTextCode] && [self isFieldEditor] && ![self hasSpanIn])
		{
			DOMElement *node = (DOMElement *)[[self DOMNode] parentNode];
			[node setAttribute:@"style" value:[self graphicalTextPreviewStyle]];
		}
		
		
		myIsEditing = NO;
	}
	
	
	return result;
}

- (BOOL)commitEditing
{
	// Fetch the HTML to save. Reduce to nil when appropriate
	NSString *innerHTML = [self liveInnerHTML];
	[self commitHTML:innerHTML];
	
	
	return YES;
}


- (void)commitHTML:(NSString *)innerHTML
{
	if ([self isFieldEditor])
	{
		NSString *flattenedHTML = [innerHTML stringByConvertingHTMLToPlainText];
		if ([flattenedHTML isEmptyString]) innerHTML = nil;
	}
	
	
	// Save back to model
	KTDocWebViewController *webViewController = [[self webViewComponent] webViewController];
	[webViewController suspendWebViewLoading];
	
	id sourceObject = [self HTMLSourceObject];
	NSString *sourceKeyPath = [self HTMLSourceKeyPath];
    OBASSERT(sourceKeyPath);
	if (![[sourceObject valueForKeyPath:sourceKeyPath] isEqualToString:innerHTML])
	{
		[sourceObject setValue:innerHTML forKeyPath:sourceKeyPath];
	}
	
	[webViewController resumeWebViewLoading];
}

#pragma mark -
#pragma mark Drag and Drop

/*!	We validate any DOMNode insertions, passing them to the edited object if appropriate.
 *	The insertion can be pasted, dropped or typed, but the last case doesn't seem to happen normally.
 */
// TODO: improve on this by looking at UTI and creating OBJECT elements for .mov files, etc.
- (BOOL)webView:(WebView *)aWebView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
// node is DOMDocumentFragment
{
	BOOL result = YES;    
    
    // Work out the right plugin to use
    KTAbstractElement *plugin = [self HTMLSourceObject];
    if (![plugin isKindOfClass:[KTAbstractElement class]])
    {
        plugin = [[self parser] currentPage];
    }
    
    
    // Figure out the maximum image size we'll allow
	NSString *settings;
	if ([plugin isKindOfClass:[KTPagelet class]])
	{
		settings = @"sidebarImage";
	}
	else if ([plugin isKindOfClass:[KTPage class]])
	{
		// TODO: could we vary the size based on whether the page is showing a sidebar?
		settings = @"inTextMediumImage";
	}
	else
	{
		return NO;
	}
	
	
	// Import graphics into the media system
    if ([self importsGraphics])
    {
        if ([node isFileList])
        {
            DOMNodeList *divs = [node childNodes];
            unsigned i;
            for (i=0; i<[divs length]; i++)
            {
                [[self class] convertFileListElement:(DOMHTMLDivElement *)[divs item:i]
                            toImageWithSettingsNamed:settings
                                           forPlugin:plugin];
            }
        }	
        else
        {
            [node convertImageSourcesToUseSettingsNamed:settings forPlugin:plugin];
        }
    }
    
    
    if (result)
	{
		// Tidy up the node to match the insertion destination
		if ([self isRichText] && [self isFieldEditor])
		{
			[node makeSingleLine];
		}
		else if (![self isRichText])
		{
			[node makePlainTextWithSingleLine:[self isFieldEditor]];	// Could perhaps use -innerText method instead
		}
		
		
		// Ban inserts of <img> elements into non-importsGraphics text.
		if (![self importsGraphics])
		{
			DOMNodeIterator *it = [[node ownerDocument] createNodeIterator:node whatToShow:DOM_SHOW_ELEMENT filter:nil expandEntityReferences:NO];
			DOMNode *aNode = [it nextNode];
			while (nil != aNode)
			{
				if ([[aNode nodeName] isEqualToString:@"IMG"])
				{
					result = NO;
					break;
				}
				aNode = [it nextNode];
			}
		}
	}
	
	
	return result;
}

+ (void)convertFileListElement:(DOMHTMLDivElement *)div
      toImageWithSettingsNamed:(NSString *)settingsName
                     forPlugin:(KTAbstractElement *)element
{
	// TODO: what happens when the default design size changes?
	DOMNode *node = [div parentNode];
    
	// Create a media container for the file
    NSString *URLString = [(DOMText *)[div firstChild] data];
    NSURL *URL = [NSURL URLWithUnescapedString:URLString];   // MUST encode legally to handle accented characters
	NSString *path = [URL path];
	KTMediaContainer *mediaContainer = [[element mediaManager] mediaContainerWithPath:path];
	
	
	if ([NSString UTI:[NSString UTIForFileAtPath:path] conformsToUTI:(NSString *)kUTTypeImage])
	{
		// Convert image files to a simple <img> tag
		mediaContainer = [mediaContainer imageWithScalingSettingsNamed:settingsName forPlugin:element];
		
		DOMHTMLImageElement *imageElement = (DOMHTMLImageElement *)[[node ownerDocument] createElement:@"IMG"];
		[imageElement setSrc:[[mediaContainer URIRepresentation] absoluteString]];
		[imageElement setAlt:[[path lastPathComponent] stringByDeletingPathExtension]];
		
		[node replaceChild:imageElement oldChild:div];
	}
	else
	{
		// Other files are converted to their thumbnail and made a download link
		KTMediaContainer *icon =
        [mediaContainer imageWithScalingSettingsNamed:@"thumbnailImage" forPlugin:element];
		
		DOMHTMLImageElement *imageElement = (DOMHTMLImageElement *)[[node ownerDocument] createElement:@"IMG"];
		[imageElement setSrc:[[icon URIRepresentation] absoluteString]];
		[imageElement setAlt:[[path lastPathComponent] stringByDeletingPathExtension]];
		
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[node ownerDocument] createElement:@"a"];
		[anchor setHref:[[mediaContainer URIRepresentation] absoluteString]];
		[anchor appendChild:imageElement];
		
		[node replaceChild:anchor oldChild:div];	
	}
}


@end
