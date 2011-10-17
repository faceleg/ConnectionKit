//
//  RESTOperation.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/16/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "RESTOperation.h"
#import "NSURL+Amazon.h"

@interface RESTOperation ( Private )

- (void)setXMLDoc:(NSXMLDocument *)anXMLDoc;

@end


@implementation RESTOperation

- (id)initWithURL:(NSURL *)aURL
{
	NSLog(@"Cannot initialize this way");
	[self release];
	return nil;
}

- (id)initWithBaseURL:(NSURL *)aURL parameters:(NSDictionary *)aDict;
{
	if ((self = [super initWithURL:nil]) != nil)	// Note: URL is not set here.
	{
		[self setParams: [NSMutableDictionary dictionary]];
		if (nil != aDict)
		{
			[[self params] addEntriesFromDictionary:aDict];		// add in passed-in dictionary
		}
		[self setBaseURL:aURL];
	}
	return self;
}

- (void)dealloc
{
	[self setBaseURL:nil];
    [self setParams:nil];
    [self setXMLDoc:nil];
	[super dealloc];
}

#pragma mark -
#pragma mark Fetch

// this is overridden so that request URL is calculated, not stored
- (NSURL *)requestURL
{
	// Combine the store URL and request paramaeters
	NSURL *baseURL = [self baseURL];
	NSDictionary *requestParameters = [self requestParameters];
	
	NSURL *url = [NSURL URLWithBaseURL:baseURL parameters:requestParameters];
	return url;
}

// This may be overridden.  Normally it just returns the params dictionary
- (NSDictionary *)requestParameters;
{
	return [NSDictionary dictionaryWithDictionary:[self params]];
}

#pragma mark -
#pragma mark Results

-(NSError *)processLoadedData
{
	NSError *error = nil;
	NSXMLDocument *XMLDoc = [[[NSXMLDocument alloc] initWithData: [self data]
														 options: 0
														   error: &error] autorelease];
	

#ifdef DEBUG
	NSLog(@"DEBUG processLoadedData: %@", [XMLDoc description]);
#endif
	[self setXMLDoc: XMLDoc];
	return error;
}

#pragma mark -
#pragma mark Data Lookup Utilities


	/*!	Primivite operation that gets value from loaded data.  Does not cache.
	*/
- (NSArray *)fetchArrayOfObjectAtXPath:(NSString *)anXPath asClass:(Class) aClass
{
	
	if (![aClass instancesRespondToSelector: @selector(initWithXMLElement:)])
	{
		[NSException raise: @"RESTOperationException"
					format: @"fetchArrayOfObjectAtXPath: passed a class that cannot be constructed with initWithXMLElement:"];
	}
	NSArray *result = nil;
	NSError *error = nil;
	NSXMLDocument *document = [self XMLDoc];
	
	// Get the XML "Item" elements. Bail if there are none
	NSArray *itemElements = [document nodesForXPath:anXPath error: &error];
	if (!error && [itemElements count] > 0)
	{
		NSMutableArray *intermediateItems = [NSMutableArray array];
		
		// Run through each Item creating an item from it
		NSEnumerator *itemsEnumerator = [itemElements objectEnumerator];
		NSXMLElement *element;
		
		while (element = [itemsEnumerator nextObject])
		{
			id theItem = [[aClass alloc] initWithXMLElement: element];		// informal protocol
			[intermediateItems addObject:theItem];
			[theItem release];
		}
		result = [NSArray arrayWithArray:intermediateItems];
	}
	return result;
}

/* Given an XML element like <foo><prop1>value1</prop1><prop2>value2</prop2></foo>
   this loads the text values into the cached dictionary.
 */
- (void) cacheSubElementsFrom:(NSXMLElement *)xml;
{
	NSEnumerator *enumerator = [[xml children] objectEnumerator];
	NSXMLNode *node;
	
	while ((node = [enumerator nextObject]) != nil)
	{
		switch([node kind])
		{
			case NSXMLElementKind:
				[self cacheValue:[node stringValue] forKey:[node name]];
				break;
			default:
				NSLog(@"Ignoring kind #%d %@", [node kind], node);
				break;
		}
	}
}

#pragma mark -
#pragma mark Accessors


- (NSURL *)baseURL
{
    return myBaseURL; 
}

- (void)setBaseURL:(NSURL *)aBaseURL
{
    [aBaseURL retain];
    [myBaseURL release];
    myBaseURL = aBaseURL;
}

- (NSMutableDictionary *)params
{
    return myParams;
}

- (void)setParams:(NSMutableDictionary *)aParams
{
    [aParams retain];
    [myParams release];
    myParams = aParams;
}

- (NSXMLDocument *)XMLDoc
{
	[self raiseExceptionIfDataNotLoaded];
    return myXMLDoc;
}

- (void)setXMLDoc:(NSXMLDocument *)anXMLDoc
{
    [anXMLDoc retain];
    [myXMLDoc release];
    myXMLDoc = anXMLDoc;
}

#pragma mark -
#pragma mark Description

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ Params:%@ XML:%p",
		[super description],
		myParams,
		myXMLDoc
		];
}


@end
