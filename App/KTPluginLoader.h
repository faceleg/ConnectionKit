//
//  KTPluginLoader.h
//  Marvel
//
//  Created by Dan Wood on 1/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTPluginLoader : NSObject {
	
	NSMutableDictionary *myDictionary;
	NSURLConnection		*myConnection;
	NSMutableData		*myConnectionData;
	
	id myDelegate; // not retained
}

- (id)initWithDictionary:(NSMutableDictionary *)aDictionary delegate:(id)aDelagate;

- (NSMutableDictionary *)dictionary;
- (void)setDictionary:(NSMutableDictionary *)aDictionary;
- (NSURLConnection *)connection;
- (void)setConnection:(NSURLConnection *)aConnection;
- (NSMutableData *)connectionData;
- (void)setConnectionData:(NSMutableData *)aConnectionData;

- (void) cancel;

@end
