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
	
	myComponent = [[parser component] retain];
	myTemplateHTML = [[parser template] copy];
	myKeyPaths = [[NSMutableSet alloc] initWithCapacity:10];
	
	myDivID = [[NSString alloc] initWithFormat:@"%@-%@",
		[[parser component] uniqueWebViewID],
		[parser parserID]];
	
	return self;
}

- (void)dealloc
{
	[mySubcomponents release];
	[myComponent release];
	[myTemplateHTML release];
	[myDivID release];
	[myKeyPaths release];
	[myTextBlocks release];
    [myHTML release];
	
	[myParser release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Basic Accessors

- (id <KTWebViewComponent>)parsedComponent { return myComponent; }

- (NSString *)templateHTML { return myTemplateHTML; }

- (NSString *)divID { return myDivID; }

- (KTHTMLParser *)parser { return myParser; }

- (NSString *)HTML { return myHTML; }

- (void)setHTML:(NSString *)HTML
{
    HTML = [HTML copy];
    [myHTML release];
    myHTML = HTML;
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
#pragma mark Sub & Super Components

- (NSSet *)subcomponents { return [NSSet setWithSet:mySubcomponents]; }

/*	Every single component that is in our chain of subComponents.
 */
- (NSSet *)allSubcomponents
{
	// Start off with our list of subcomponents
	NSMutableSet *result = [NSMutableSet setWithSet:[self subcomponents]];
	
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

- (void)setSuperComponent:(KTWebViewComponent *)component { mySupercomponent = component; }

/*	Searches all subComponents (and their subComponents etc.) for the parsed component with the 
 *	right properties. Returns nil if not found.
 */
- (KTWebViewComponent *)componentWithParsedComponent:(id <KTWebViewComponent>)component
												 templateHTML:(NSString *)templateHTML
{
	KTWebViewComponent *result = nil;
	
	// Are we a match?
	if ([[self parsedComponent] isEqual:component] &&
		[[self templateHTML] isEqual:templateHTML])
	{
		result = self;
	}
	// No we're not, so search subComponents
	else
	{
		NSSet *subComponents = mySubcomponents;
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
		mySubcomponents = [[NSMutableSet alloc] initWithCapacity:1];
	}
	
	[mySubcomponents addObject:component];
	[component setSuperComponent:self];
}

- (void)removeAllSubcomponents
{
	[mySubcomponents removeAllObjects];
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

- (NSString *)parser:(KTHTMLParser *)parser willEndParsing:(NSString *)result;
{
	// Preview HTML should be wrapped in an identiying div for the webview
	if ([parser HTMLGenerationPurpose] == kGeneratingPreview &&
		result &&
		[parser parentParser] &&
		[[parser component] conformsToProtocol:@protocol(KTWebViewComponent)])
	{
		result = [NSString stringWithFormat:@"<div id=\"%@-%u\" class=\"kt-parsecomponent-placeholder\">\n%@\n</div>",
				  [[parser component] uniqueWebViewID],
				  [[parser template] hash],
				  result];
	}
	
	[self setHTML:result];
	
	
	return result;
}

/*	We want to record the text block.
 *	This includes making sure the webview refreshes upon a graphical text size change.
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock
{
	[self addTextBlock:textBlock];
}

@end
