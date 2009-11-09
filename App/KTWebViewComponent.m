//
//  KTParsedWebViewComponent.m
//  Marvel
//
//  Created by Mike on 24/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTWebViewComponent.h"
#import "KTDocWebViewController.h"

#import "SVHTMLContext.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "DOM+KTWebViewController.h"


@implementation KTWebViewComponent

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithParser:(SVHTMLTemplateParser *)parser
{
	OBPRECONDITION(parser);
	
	[super init];
	
	myParser = [parser retain];
	mySubcomponents = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc
{
	[self removeAllTextBlocks];	[myTextBlocks release];
	
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

- (SVHTMLTemplateParser *)parser { return myParser; }

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

- (void)addTextBlock:(SVHTMLTextBlock *)textBlock
{
	[[self _textBlocks] addObject:textBlock];
	[textBlock setWebViewComponent:self];
}

- (void)removeAllTextBlocks
{
	[[self textBlocks] setValue:nil forKey:@"webViewComponent"];
	[[self _textBlocks] removeAllObjects];
}

/*	Search our text blocks for a match. If not found, do the same for subcomponents.
 */
- (SVHTMLTextBlock *)textBlockForDOMNode:(DOMNode *)node;
{
	OBPRECONDITION(node);
	
	SVHTMLTextBlock *result = nil;
	
	// Find the overall element encapsualting the editing block
	DOMHTMLElement *textBlockDOMElement = [node firstSelectableParentNode];
	NSString *textBlockDOMID = [textBlockDOMElement idName];
	if (textBlockDOMID)
	{

		// Search for an existing TextBlock object with that ID
		NSEnumerator *textBlocksEnumerator = [[self textBlocks] objectEnumerator];
		SVHTMLTextBlock *aTextBlock;
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
        
        
        if (result)
        {
            // Hook the text block up to its DOM node
            [result setDOMNode:textBlockDOMElement];
        }
        else if (![self supercomponent])
        {
            // In very rare cases, the user will have pasted in HTML code that once was a valid editing block. If so, want to search the next level up. Case 41716.
            DOMNode *parentNode = [textBlockDOMElement parentNode];
            if (parentNode)
            {
                result = [self textBlockForDOMNode:parentNode];
            }
        }
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

- (void)addSubcomponent:(KTWebViewComponent *)component
{
	[mySubcomponents addObject:component];
	[component setSuperComponent:self];
}

- (void)replaceWithComponent:(KTWebViewComponent *)replacementComponent
{
	KTWebViewComponent *supercomponent = [self supercomponent];
	[self setSuperComponent:nil];
	
	unsigned index = [[supercomponent subcomponents] indexOfObjectIdenticalTo:self];
	[supercomponent->mySubcomponents replaceObjectAtIndex:index withObject:replacementComponent];
	
	[replacementComponent setSuperComponent:supercomponent];
}

- (void)removeAllSubcomponents
{
	[mySubcomponents setValue:nil forKey:@"superComponent"];
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
#pragma mark Loading

/*	Compares componentHTML, then children to see what needs reloading
 */
- (void)_reloadIfNeededWithPossibleReplacement:(KTWebViewComponent *)replacementComponent;
{
	if (![[self componentHTML] isEqualToString:[replacementComponent componentHTML]] ||
		[[self subcomponents] count] != [[replacementComponent subcomponents] count])
	{
		[[self webViewController] replaceWebViewComponent:self withComponent:replacementComponent];
	}
	else
	{
		NSArray *subcomponents = [self subcomponents];
		NSArray *replacementSubcomponents = [replacementComponent subcomponents];
		
		unsigned i, count = [subcomponents count];
		for (i = 0; i < count; i++)
		{
			KTWebViewComponent *aSubcomponent = [subcomponents objectAtIndex:i];
			KTWebViewComponent *aReplacementSubcomponent = [replacementSubcomponents objectAtIndex:i];
			
			[aSubcomponent _reloadIfNeededWithPossibleReplacement:aReplacementSubcomponent];
		}
	}
}


#pragma mark -
#pragma mark Parser

- (void)parserDidStartTemplate:(SVHTMLTemplateParser *)parser;
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

- (NSString *)parser:(SVHTMLTemplateParser *)parser didEndTemplate:(NSString *)HTML;
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
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didParseTextBlock:(SVHTMLTextBlock *)textBlock
{
	[self addTextBlock:textBlock];
}

@end
