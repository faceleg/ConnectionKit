//
//  RESTOperation.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/16/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	General, non-Amazon-specific REST -> XML asynchronous object


#import <Foundation/Foundation.h>
#import "AsyncObject.h"

@interface NSObject ( XMLCreationInformalProtocol )
- (id)initWithXMLElement:(NSXMLElement *)xml;
@end


@interface RESTOperation : AsyncObject
{
	NSURL					*myBaseURL;
	NSMutableDictionary		*myParams;
	NSXMLDocument			*myXMLDoc;
}

- (id)initWithBaseURL:(NSURL *)aURL parameters:(NSDictionary *)aDict;
- (NSDictionary *)requestParameters;

- (NSURL *)baseURL;
- (void)setBaseURL:(NSURL *)aBaseURL;

- (NSMutableDictionary *)params;
- (void)setParams:(NSMutableDictionary *)aParams;


- (NSXMLDocument *)XMLDoc;

	// Data Lookup Utility
- (NSArray *)fetchArrayOfObjectAtXPath:(NSString *)anXPath asClass:(Class) aClass;
- (void) cacheSubElementsFrom:(NSXMLElement *)xml;

@end
