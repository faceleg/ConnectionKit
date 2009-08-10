//
//  KTTransferController.h
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTPublishingEngine.h"


@interface KTLocalPublishingEngine : KTPublishingEngine 
{
	BOOL    _onlyPublishChanges;
}

- (id)initWithSite:(KTSite *)aDocumentInfo onlyPublishChanges:(BOOL)publishChanges;
- (BOOL)onlyPublishChanges;

@end