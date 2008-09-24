//
//  KTParsedWebViewComponent.m
//  Marvel
//
//  Created by Mike on 24/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTWebViewComponent.h"

#import "KTHTMLParser.h"
#import "KTHTMLTextBlock.h"
#import "DOM+KTWebViewController.h"


@implementation KTWebViewComponent

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithParser:(KTHTMLParser *)parser
{
	[super init];
	
	myParser = [parser retain];
	myKeyPaths = [[NSMutableSet alloc] initWithCapacity:10];
	
	return self;
}

- (void)dealloc
{
	[myKeyPaths release];
	[myTextBlocks release];
	[myInnerHTML release];
    [myComponentHTML release];
	[myParser release];
	
	[mySubcomponents release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Basic Accessors

- (NSString *)divID
{
	NSString *result = [NSString stringWithFormat:@"%@-%@", 
						[[[self parser] component] uniqueWebViewID], 
						[[self parser] parserID]];
	
	return result;
}

- (KTHTMLParser *)parser { return myParser; }

- (NSString *)outerHTML
{
	NSString *result = myInnerHTML;
	
	if ([[self parser] HTMLGenerationPurpose] == kGeneratingPreview &&
		myInnerHTML &&
		[[self parser] parentParser] &&
		[[[self parser] component] conformsToProtocol:@protocol(KTWebViewComponent)])
	{
		result = [NSString stringWithFormat:@"<div id=\"%@\" class=\"kt-parsecomponent-placeholder\">\n%@\n</div>",
				  [self divID],
				  myInnerHTML];
	}
	
	return result;
}

- (NSString *)componentHTML { return myComponentHTML; }

- (void)setComponentHTML:(NSString *)HTML
{
    HTML = [HTML copy];
    [myComponentHTML release];
    myComponentHTML = HTML;
}

#pragma mark -
#pragma mark Parsed Key Paths

- (NSSet *)parsedKeyPaths { return myKeyPaths; }

- (void)addParsedKeyPath:(KTParsedKeyPath *)keypath
{
	[myKeyPaths addObject:keypath];
}

- (void)removeAllParsedKeyPaths
{
	[myKeyPaths removeAllObjects];
}

#pragma mark -
#pragma mark Text Blocks

- (NSMutableSet *)_textBlocks
{
	if (!myTextBlocks)
	{
		myTextBlocks = [[NSMutableSet alloc] init];
	}
	
	return myTextBlocks;
}

- (NSSet *)textBlocks { return [NSSet setWithSet:myTextBlocks]; }

- (void)addTextBlock:(KTHTMLTextBlock *)textBlock { [[self _textBlocks] addObject:textBlock]; }

- (void)removeAllTextBlocks { [[self _textBlocks] removeAllObjects]; }

/*	Search our text blocks for a match. If not found, do the same for subcomponents.
 */
- (KTHTMLTextBlock *)textBlockForDOMNode:(DOMNode *)node;
{
	OBPRECONDITION(node);
	
	KTHTMLTextBlock *result = nil;
	
	// Find the overall element encapsualting the editing block
	DOMHTMLElement *textBlockDOMElement = [node firstSelectableParentNode];
	NSString *textBlockDOMID = [textBlockDOMElement idName];
	if (textBlockDOMID)
	{

		// Search for an existing TextBlock object with that ID
		NSEnumerator *textBlocksEnumerator = [[self textBlocks] objectEnumerator];
		KTHTMLTextBlock *aTextBlock;
		while (aTextBlock = [textBlocksEnumerator nextObject])
		{
			if ([[aTextBlock DOMNodeID] isEqualToString:textBlockDOMID])
			{
				result = aTextBlock;
				break;
			}
		}
		
		
		// Resort to searching children as needed
		if (!result)
		{
			NSEnumerator *subcomponentsEnumerator = [[self subcomponents] objectEnumerator];
			KTWebViewComponent *aComponent;
			while (aComponent = [subcomponentsEnumerator nextObject])
			{
				aTextBlock = [aComponent textBlockForDOMNode:node];
				if (aTextBlock)
				{
					result = aTextBlock;
					break;
				}
			}
		}
		
		
		// Hook the text block up to its DOM node
		[result setDOMNode:textBlockDOMElement];
	}
	
	
	return result;
}

#pragma mark -
#pragma mark Tree Nodes

- (NSArray *)subcomponents { return [[mySubcomponents copy] autorelease]; }

/*	Every single component that is in our chain of subComponents.
 */
- (NSSet *)allSubcomponents
{
	// Start off with our list of subcomponents
	NSMutableSet *result = [NSMutableSet setWithArray:[self subcomponents]];
	
	// Them go through and add all their subcomponents
	NSEnumerator *subComponentsEnumerator = [[self subcomponents] objectEnumerator];
	KTWebViewComponent *aComponent;
	while (aComponent = [subComponentsEnumerator nextObject])
	{
		[result unionSet:[aComponent allSubcomponents]];
	}
	
	return result;
}

- (KTWebViewComponent *)supercomponent { return mySupercomponent; }

/*	Returns our parent, plus their parent etc.
 */
- (NSSet *)allSupercomponents
{
	NSMutableSet *result = [NSMutableSet set];
	
	KTWebViewComponent *aComponent = [self supercomponent];
	while (aComponent)
	{
		[result addObject:aComponent];
		aComponent = [aComponent supercomponent];
	}
	
	return result;
}

- (void)setSuperComponent:(KTWebViewComponent *)component
{
	mySupercomponent = component;	// Weak ref
	[self setWebViewController:[component webViewController]];
}

/*	Searches all subComponents (and their subComponents etc.) for the parsed component with the 
 *	right properties. Returns nil if not found.
 */
- (KTWebViewComponent *)componentWithParsedComponent:(id <KTWebViewComponent>)component
												 templateHTML:(NSString *)templateHTML
{
	KTWebViewComponent *result = nil;
	
	// Are we a match?
	if ([[[self parser] component] isEqual:component] &&
		[[[self parser] template] isEqual:templateHTML])
	{
		result = self;
	}
	// No we're not, so search subComponents
	else
	{
		NSArray *subComponents = mySubcomponents;
		NSEnumerator *componentsEnumerator = [subComponents objectEnumerator];
		KTWebViewComponent *aParsedComponent;
		
		while (aParsedComponent = [componentsEnumerator nextObject])
		{
			// OK then, does this component contain the component?
			KTWebViewComponent *possibleResult = [aParsedComponent componentWithParsedComponent:component
																							templateHTML:templateHTML];
			if (possibleResult)
			{
				result = possibleResult;
				break;
			}
		}
	}
	
	return result;
}

- (void)addSubcomponent:(KTWebViewComponent *)component
{
	if (!mySubcomponents)
	{
		mySubcomponents = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	[mySubcomponents addObject:component];
	[component setSuperComponent:self];
}

- (void)removeAllSubcomponents
{
	[mySubcomponents removeAllObjects];
}

#pragma mark WebView controller

- (KTDocWebViewController *)webViewController { return myWebViewController; }

- (void)setWebViewController:(KTDocWebViewController *)webViewController
{
	myWebViewController = webViewController;
	
	[[self subcomponents] setValue:webViewController forKey:@"webViewController"];
}

#pragma mark -
#pragma mark Needs Reload

- (BOOL)needsReload { return myNeedsReload; }

- (void)setNeedsReload:(BOOL)flag { myNeedsReload = flag; }

- (void)setNeedsReload:(BOOL)flag recursive:(BOOL)recursive
{
	[self setNeedsReload:flag];
	
	if (recursive)
	{
		NSEnumerator *subcomponentsEnumerator = [[self subcomponents] objectEnumerator];
		KTWebViewComponent *aComponent;
		while (aComponent = [subcomponentsEnumerator nextObject])
		{
			[aComponent setNeedsReload:flag recursive:YES];
		}
	}
}

#pragma mark -
#pragma mark Parser

- (void)parserDidStartTemplate:(KTHTMLParser *)parser;
{
	if ([[parser parentParser] delegate] == self)
	{
		// Start a new child component
		KTWebViewComponent *newComponent = [[KTWebViewComponent alloc] initWithParser:parser];
		[self addSubcomponent:newComponent];
		[parser setDelegate:newComponent];
		[newComponent release];
	}
}

- (NSString *)parser:(KTHTMLParser *)parser didEndTemplate:(NSString *)HTML;
{
	// Store the HTML
	myInnerHTML = [HTML copy];
	
	
	// Calculate and store component HTML
	NSMutableString *componentHTML = [HTML mutableCopy];
	
	NSEnumerator *subcomponentsEnumerator = [[self subcomponents] objectEnumerator];
	KTWebViewComponent *aSubcomponent;
	while (aSubcomponent = [subcomponentsEnumerator nextObject])
	{
		NSString *subcomponentHTML = [aSubcomponent outerHTML];
		NSRange subcomponentHTMLRange = [componentHTML rangeOfString:subcomponentHTML];
		if (subcomponentHTMLRange.location != NSNotFound)
		{
			[componentHTML deleteCharactersInRange:subcomponentHTMLRange];
		}
	}
	
	[self setComponentHTML:componentHTML];
	[componentHTML release];
	
	
	// Wrap in identifying div if possible
	return [self outerHTML];
}

/*	We want to record the text block.
 *	This includes making sure the webview refreshes upon a graphical text size change.
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock
{
	[self addTextBlock:textBlock];
}

@end
