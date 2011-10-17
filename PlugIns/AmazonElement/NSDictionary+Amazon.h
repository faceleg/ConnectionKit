//
//  NSDictionary+Amazon.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/2/07.
//  Copyright (c) 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSDictionary ( Amazon )

// Init -- informal protocol for initializing with some simple xml
- (id)initWithXMLElement:(NSXMLElement *)xml;

@end
