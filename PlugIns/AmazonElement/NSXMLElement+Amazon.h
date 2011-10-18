//
//  NSXMLElement+Amazon.h
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	Convenience methods on NSXMLElement to make retrieiving the first value for
//	a given name quicker.


#import <Cocoa/Cocoa.h>


@interface NSXMLElement ( Amazon )

- (NSXMLElement *)elementForName:(NSString *)elementName;
- (NSString *)stringValueForName:(NSString *)elementName;

- (NSDictionary *)simpleDictionaryRepresentation;

@end
