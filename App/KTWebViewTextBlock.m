//
//  KTWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTWebViewTextBlock.h"

#import "Debug.h"

#import "DOM+KTWebViewController.h"
#import "DOMNode+KTExtensions.h"

#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "KTWeakReferenceMutableDictionary.h"
#import "KTWebKitCompatibility.h"

#import "KTMediaManager+Internal.h"
#import "KTMediaContainer.h"
#import "KTGraphicalTextMediaContainer.h"
#import "KTAbstractMediaFile.h"
#import "KTMediaFileUpload.h"

#import "NSString+Karelia.h"
#import "NSString-Utilities.h"


@interface KTWebViewTextBlock (Private)

+ (NSMutableDictionary *)knownTextBlocks;

- (id)initWithHTMLElement:(DOMHTMLElement *)DOMNode webViewController:(KTDocWebViewController *)webViewController;

- (void)setDOMNode:(DOMHTMLElement *)node;
@end


@implementation KTWebViewTextBlock

#pragma mark -
#pragma mark Factory Methods

+ (KTWebViewTextBlock *)textBlockForDOMNode:(DOMNode *)node
								  webViewController:(KTDocWebViewController *)webViewController;
{
	KTWebViewTextBlock *result = nil;
	
	
	// Find the overall element encapsualting the editing block
	DOMHTMLElement *textBlockDOMElement = [node firstSelectableParentNode];
	
	
	// Search for an existing TextBlock object with that ID
	NSString *textBlockDOMID = [textBlockDOMElement idName];
	result = [[self knownTextBlocks] objectForKey:textBlockDOMID];
	[result setDOMNode:textBlockDOMElement];
	
	if (!result)
	{
		// Find the object corresponding to the element's ID
		id HTMLSourceObject = nil;
		if (textBlockDOMID && [[webViewController windowController] isEditableElement:textBlockDOMElement])
		{
			HTMLSourceObject = [[webViewController windowController] itemForDOMNodeID:textBlockDOMID];
		}
		
		
		// If we're sure that some actual editable text has been chosen, continue.
		if (HTMLSourceObject)
		{	
			result = [[[KTWebViewTextBlock alloc] initWithHTMLElement:textBlockDOMElement
														   webViewController:webViewController] autorelease];
		}
	}
	
	return result;
}

+ (NSMutableDictionary *)knownTextBlocks
{
	static NSMutableDictionary *result;
	
	if (!result)
	{
		result = [[KTWeakReferenceMutableDictionary alloc] init];
	}
	
	return result;
}

#pragma mark -
#pragma mark Init & Dealloc

/*	Designated initialiser for now.
 */
- (id)initWithDOMNodeID:(NSString *)ID;
{
	[super init];
	
	myDOMNodeID = [ID copy];
	myIsEditable = YES;
	[self setHTMLTag:@"div"];
	[[KTWebViewTextBlock knownTextBlocks] setObject:self forKey:ID];	// That's a wak ref
	
	return self;
}

- (id)init
{
	NSString *DOMID = [NSString stringWithFormat:@"k-svxTextBlock-%@", [NSString shortGUIDString]];
	[self initWithDOMNodeID:DOMID];
	
	return self;
}

/*	PRIVATE init method. Do NOT call this directly, but go through the class factory method instead
 */
- (id)initWithHTMLElement:(DOMHTMLElement *)aDOMNode webViewController:(KTDocWebViewController *)webViewController
{
	[self initWithDOMNodeID:[aDOMNode idName]];
	
	NSString *textBlockDOMClass = [aDOMNode className];
	NSString *propertyName = [[webViewController windowController] propertyNameForDOMNodeID:[aDOMNode idName]];
	
	
	// Set our attributes from the various DOM properties
	[self setRichText:[propertyName hasSuffix:@"HTML"]];
	[self setFieldEditor:[DOMNode isSingleLineFromDOMNodeClass:textBlockDOMClass]];
	[self setImportsGraphics:[aDOMNode isImageable]];
	
	[self setDOMNode:[aDOMNode retain]];
	
	myHTMLSourceObject = [[[webViewController windowController] itemForDOMNodeID:[aDOMNode idName]] retain];
	myHTMLSourceKeyPath = [propertyName copy];
	
	myHasSpanIn = [aDOMNode hasSpanIn];
	
	return self;
}

- (void)dealloc
{
	OBASSERT(!myIsEditing);
	
	// Remove us from the list of known text blocks otherwise there will be a memory crasher later
	[[KTWebViewTextBlock knownTextBlocks] removeObjectForKey:[self DOMNodeID]];	// This was a weak ref
	
	[myDOMNode release];
	[myDOMNodeID release];
	[myHTMLTag release];
	[myGraphicalTextCode release];
	[myHyperlink release];
	[myHTMLSourceObject release];
	[myHTMLSourceKeyPath release];
	[myPage release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSString *)DOMNodeID { return myDOMNodeID; }

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
	NSParameterAssert(tag);
	
	tag = [tag copy];
	[myHTMLTag release];
	myHTMLTag = tag;
}

- (NSString *)hyperlink { return myHyperlink; }

- (void)setHyperlink:(NSString *)hyperlink
{
	// We can't have a hyperlink and be editable at the same time
	if ([self isEditable]) [self setEditable:NO];
	
	hyperlink = [hyperlink copy];
	[myHyperlink release];
	myHyperlink = hyperlink;
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

- (KTPage *)page { return myPage; }

- (void)setPage:(KTPage *)page
{
	[page retain];
	[myPage release];
	myPage = page;
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
	if (graphicalTextCode)
	{
		KTPage *page = [self page];		OBASSERT(page);
		KTMaster *master = [page master];
		if ([master boolForKey:@"enableImageReplacement"])
		{
			KTDesign *design = [master design];
			NSDictionary *graphicalTextSettings = [[design imageReplacementTags] objectForKey:graphicalTextCode];
			if (graphicalTextSettings)
			{
				// Generate the image
				KTMediaManager *mediaManager = [page mediaManager];
				result = [mediaManager graphicalTextWithString:[self innerHTML:kGeneratingPreview]
														design:design
										  imageReplacementCode:graphicalTextCode
														  size:[master floatForKey:@"graphicalTitleSize"]];
			}
		}
	}
	
	return result;
}

/*	Returns nil if there is no graphical text in use
 */
- (NSString *)graphicalTextPreviewStyle
{
	NSString *result = nil;
	
	KTMediaContainer *image = [self graphicalTextMedia];
	KTAbstractMediaFile *mediaFile = [image file];
	if (mediaFile)
	{			
		result = [NSString stringWithFormat:@"text-indent:-1000px; background:url(%@); width:%ipx; height:%ipx;",
											[[NSURL fileURLWithPath:[mediaFile currentPath]] absoluteString],
											[mediaFile integerForKey:@"width"],
											[mediaFile integerForKey:@"height"]];
	}
	
	return result;
}

#pragma mark -
#pragma mark HTML

- (NSString *)innerHTML:(KTHTMLGenerationPurpose)purpose
{
	NSString *result = [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]];
	if (!result) result = @"";

	
	
	// Perform additional processing of the text according to HTML generation purpose
	if ([self importsGraphics] && purpose != kGeneratingPreview)
	{
		// Convert media source paths
		NSScanner *scanner = [[NSScanner alloc] initWithString:result];
		NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:[result length]];
		NSString *aString;	NSString *aMediaPath;
		
		while (![scanner isAtEnd])
		{
			[scanner scanUpToString:@" src=\"" intoString:&aString];
			[buffer appendString:aString];
			if ([scanner isAtEnd]) break;
			
			[buffer appendString:@" src=\""];
			[scanner setScanLocation:([scanner scanLocation] + 6)];
			
			[scanner scanUpToString:@"\"" intoString:&aMediaPath];
			NSURL *aMediaURI = [NSURL URLWithString:aMediaPath];
			KTMediaContainer *mediaContainer = [KTMediaContainer mediaContainerForURI:aMediaURI];
			
			// Replace the path with one suitable for the specified purpose
			if (mediaContainer)
			{
				if (purpose == kGeneratingQuickLookPreview)
				{
					aMediaPath = [[mediaContainer file] quickLookPseudoTag];
				}
				else
				{
					KTPage *page = [self page];		OBASSERT(page);
					aMediaPath = [[[mediaContainer file] defaultUpload] publishedPathRelativeToPage:page];
				}
			}
			[buffer appendString:aMediaPath];
		}
		
		result = [NSString stringWithString:buffer];
		[buffer release];
		[scanner release];
	}
	
	
	return result;
}

/*	Includes the editable tag(s) + innerHTML
 */
- (NSString *)outerHTML:(KTHTMLGenerationPurpose)purpose
{
	// When publishing, generate an empty string (or maybe nil) for empty text blocks
	NSString *innerHTML = [self innerHTML:purpose];
	if (purpose != kGeneratingPreview && (!innerHTML || [innerHTML isEqualToString:@""]))
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
		[buffer appendFormat:@" id=\"%@\"", [self DOMNodeID]];
		if ([self isEditable])
		{
			[buffer appendFormat:@" class=\"%@\"", ([self isRichText]) ? @"kBlock" : @"kLine"];
		}
		else if (![self isEditable])
		{
			[buffer appendString:@" class=\"in\""];
		}
	}
	
	
	// Add in graphical text styling if there is any
	NSString *graphicalTextStyle = [self graphicalTextPreviewStyle];
	if (graphicalTextStyle)
	{
		if (purpose == kGeneratingPreview)
		{
			[buffer appendFormat:@" style=\"%@\"", graphicalTextStyle];
		}
		else
		{
			[buffer appendFormat:@" id=\"graphical-text-%@\"", [[self graphicalTextMedia] identifier]];
		}
	}
	
	
	// Close off the main tag
	[buffer appendString:@">"];
	
	
	
	// Place a hyperlink if required
	if ([self hyperlink])
	{
		[buffer appendFormat:@"<a href=\"%@\">", [self hyperlink]];
	}
	
	
	// Generate <span class="in"> if desired
	if (generateSpanIn)	// For normal, single-line text the span is the editable bit
	{
		[buffer appendFormat:@"<span id=\"%@\"", [self DOMNodeID]];
		if ([self isEditable])
		{
			[buffer appendFormat:@" class=\"%@\"", ([self isRichText]) ? @"kBlock" : @"kLine"];
		}
		[buffer appendString:@">"];
	}
	
	
	// Stick in the main HTML
	[buffer appendString:innerHTML];
	
	
	// End all tags
	if (generateSpanIn)
	{
		[buffer appendString:@"</span>"];
	}
	if ([self hyperlink]) [buffer appendString:@"</a>"];
	[buffer appendFormat:@"</%@>", [self HTMLTag]];
	
	
	// Tidy up
	NSString *result = [NSString stringWithString:buffer];
	return result;
}

#pragma mark -
#pragma mark Editing

- (BOOL)becomeFirstResponder
{
	NSAssert(!myIsEditing, @"Can't become first responder, already editing");
	
	// <span class="in"> tags need to become blocks when beginning editing
	if ([self isFieldEditor] && ![self hasSpanIn])
	{
		[[self DOMNode] setAttribute:@"style" :@"display:block;"];
	}
	
	
	// Graphical text needs to be turned off
	if ([self graphicalTextCode] && [self isFieldEditor] && ![self hasSpanIn])
	{
		DOMElement *node = (DOMElement *)[[self DOMNode] parentNode];
		[node removeAttribute:@"style"];
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
		NSString *textContents = [[self DOMNode] textContent]; /// WAS [[((DOMHTMLElement *)outerNode) outerHTML] flattenHTML];
		NSString *outerHTML = [[self DOMNode] outerHTML];

		if ([textContents isEqualToString:@""]
			&& (NSNotFound == [outerHTML rangeOfString:@"<embed"].location)
			&& (NSNotFound == [outerHTML rangeOfString:@"<img"].location)
			&& (NSNotFound == [outerHTML rangeOfString:@"<object"].location)	// logic duplicated in KTDocWebViewController+Editing
			&& (NSNotFound == [outerHTML rangeOfString:@"<script"].location)
			&& (NSNotFound == [outerHTML rangeOfString:@"<iframe"].location)
			)
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
	NSAssert(myIsEditing, @"Can't resign first responder, not currently editing");
	
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
			[node setAttribute:@"style" :[self graphicalTextPreviewStyle]];
		}
		
		
		myIsEditing = NO;
	}
	
	
	return result;
}

- (BOOL)commitEditing
{
	// Fetch the HTML to save. Reduce to nil when appropriate
	NSString *innerHTML = [[self DOMNode] cleanedInnerHTML];
	if ([self isFieldEditor])
	{
		NSString *flattenedHTML = [innerHTML flattenHTML];
		if ([flattenedHTML isEmptyString]) innerHTML = nil;
	}
	
	// Save back to model
	id sourceObject = [self HTMLSourceObject];
	NSString *sourceKeyPath = [self HTMLSourceKeyPath];
	if (![[sourceObject valueForKeyPath:sourceKeyPath] isEqualToString:innerHTML])
	{
		[sourceObject setValue:innerHTML forKeyPath:sourceKeyPath];
	}
	
	
	return YES;
}

@end
