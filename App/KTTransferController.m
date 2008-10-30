//
//  KTTransferController.m
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTTransferController.h"

#import "Debug.h"
#import "KTDocumentInfo.h"

@interface KTTransferController ( Private )
- (void)setDocumentInfo:(KTDocumentInfo *)aDocumentInfo;
@end

@implementation KTTransferController

- (id)initWithDocumentInfo:(KTDocumentInfo *)aDocumentInfo
{
	[super init];
	if ( nil != self )
	{
		[self setDocumentInfo:aDocumentInfo];
	}
	
	return self;
}

- (void)dealloc
{
	[self setDocumentInfo:nil];
	[super dealloc];
}

- (void)setDocumentInfo:(KTDocumentInfo *)aDocumentInfo
{
	[aDocumentInfo retain];
	[myDocumentInfo release];
	myDocumentInfo = aDocumentInfo;
}

// old API
- (id)initWithAssociatedDocument:(KTDocument *)aDocument where:(int)aWhere;
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
	return nil;
}
- (void)uploadStaleAssets
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}
- (void)uploadEverything
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}
- (void)uploadEverythingToSuggestedPath:(NSString *)aSuggestedPath;
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}
- (NSString *)storagePath
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
	return nil;
}
- (id <AbstractConnectionProtocol>)connection
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
	return nil;	
}
- (void)terminateConnection
{
	ISDEPRECATEDAPI;
	RAISE_EXCEPTION(@"Old API Exception", @"you need to intercept this and rewrite it", nil);
}



@end
