//
//  SVSidebar.h
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletsContainer.h"

@class KTAbstractPage;

@interface SVSidebar : SVPageletsContainer  

@property (nonatomic, retain) KTAbstractPage *page;


#pragma mark HTML
- (NSString *)pageletsHTMLString;

@end


