//
//  SVPageBody.h
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRichText.h"


@class KTPage;

@interface SVPageBody : SVRichText

@property (nonatomic, retain, readonly) KTPage *page;

- (void)writeEarlyCallouts:(SVHTMLContext *)context;

@end



