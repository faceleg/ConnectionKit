//
//  KTParsedWebViewComponent.m
//  Marvel
//
//  Created by Mike on 24/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTParsedWebViewComponent.h"

#import "KTHTMLParser.h"


@implementation KTParsedWebViewComponent

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithParser:(KTHTMLParser *)parser
{
	[super init];
	
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
	
	[super dealloc];
}

#pragma mark -
#pragma mark Basic Accessors

- (id <KTWebViewComponent>)parsedComponent { return myComponent; }

- (NSString *)templateHTML { return myTemplateHTML; }

- (NSString *)divID { return myDivID; }

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
	KTParsedWebViewComponent *aComponent;
	while (aComponent = [subComponentsEnumerator nextObject])
	{
		[result unionSet:[aComponent allSubcomponents]];
	}
	
	return result;
}

- (KTParsedWebViewComponent *)supercomponent { return mySupercomponent; }

/*	Returns our parent, plus their parent etc.
 */
- (NSSet *)allSupercomponents
{
	NSMutableSet *result = [NSMutableSet set];
	
	KTParsedWebViewComponent *aComponent = [self supercomponent];
	while (aComponent)
	{
		[result addObject:aComponent];
		aComponent = [aComponent supercomponent];
	}
	
	return result;
}

- (void)setSuperComponent:(KTParsedWebViewComponent *)component { mySupercomponent = component; }

/*	Searches all subComponents (and their subComponents etc.) for the parsed component with the 
 *	right properties. Returns nil if not found.
 */
- (KTParsedWebViewComponent *)componentWithParsedComponent:(id <KTWebViewComponent>)component
												 templateHTML:(NSString *)templateHTML
{
	KTParsedWebViewComponent *result = nil;
	
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
		KTParsedWebViewComponent *aParsedComponent;
		
		while (aParsedComponent = [componentsEnumerator nextObject])
		{
			// OK then, does this component contain the component?
			KTParsedWebViewComponent *possibleResult = [aParsedComponent componentWithParsedComponent:component
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

- (void)addSubcomponent:(KTParsedWebViewComponent *)component
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
		KTParsedWebViewComponent *aComponent;
		while (aComponent = [subcomponentsEnumerator nextObject])
		{
			[aComponent setNeedsReload:flag recursive:YES];
		}
	}
}

@end
