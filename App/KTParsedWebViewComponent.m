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
	myTemplateHTML = [[parser templateHTML] copy];
	myKeyPaths = [[NSMutableSet alloc] initWithCapacity:10];
	
	myDivID = [[NSString alloc] initWithFormat:@"%@-%@",
		[[parser component] uniqueWebViewID],
		[parser parserID]];
	
	return self;
}

- (void)dealloc
{
	[mySubComponents release];
	[myComponent release];
	[myTemplateHTML release];
	[myDivID release];
	[myKeyPaths release];
	[mySummaryTextBlocks release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Basic Accessors

- (id <KTWebViewComponent>)parsedComponent { return myComponent; }

- (NSString *)templateHTML { return myTemplateHTML; }

- (NSString *)divID { return myDivID; }

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
#pragma mark Summaries

- (NSMutableSet *)_textBlocks
{
	if (!mySummaryTextBlocks)
	{
		mySummaryTextBlocks = [[NSMutableSet alloc] init];
	}
	
	return mySummaryTextBlocks;
}

- (NSSet *)textBlocks { return [NSSet setWithSet:mySummaryTextBlocks]; }

- (void)addTextBlock:(KTWebViewTextEditingBlock *)textBlock { [[self _textBlocks] addObject:textBlock]; }

- (void)removeAllTextBlocks { [[self _textBlocks] removeAllObjects]; }

#pragma mark -
#pragma mark Sub & Super Components

- (NSSet *)subComponents { return [NSSet setWithSet:mySubComponents]; }

/*	Every single component that is in our chain of subComponents.
 */
- (NSSet *)allSubComponents
{
	// Start off with our list of subcomponents
	NSMutableSet *result = [NSMutableSet setWithSet:[self subComponents]];
	
	// Them go through and add all their subcomponents
	NSEnumerator *subComponentsEnumerator = [[self subComponents] objectEnumerator];
	KTParsedWebViewComponent *aComponent;
	while (aComponent = [subComponentsEnumerator nextObject])
	{
		[result unionSet:[aComponent allSubComponents]];
	}
	
	return result;
}

- (KTParsedWebViewComponent *)superComponent { return mySuperComponent; }

/*	Returns our parent, plus their parent etc.
 */
- (NSSet *)allSuperComponents
{
	NSMutableSet *result = [NSMutableSet set];
	
	KTParsedWebViewComponent *aComponent = [self superComponent];
	while (aComponent)
	{
		[result addObject:aComponent];
		aComponent = [aComponent superComponent];
	}
	
	return result;
}

- (void)setSuperComponent:(KTParsedWebViewComponent *)component { mySuperComponent = component; }

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
		NSSet *subComponents = mySubComponents;
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

- (void)addSubComponent:(KTParsedWebViewComponent *)component
{
	if (!mySubComponents)
	{
		mySubComponents = [[NSMutableSet alloc] initWithCapacity:1];
	}
	
	[mySubComponents addObject:component];
	[component setSuperComponent:self];
}

- (void)removeAllSubComponents
{
	[mySubComponents removeAllObjects];
}

@end
