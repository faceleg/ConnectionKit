//
//  KTArchivePage.h
//  Marvel
//
//  Created by Mike on 29/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTAbstractPage.h"


@interface KTArchivePage : KTAbstractPage

- (void)updateTitle;
- (NSString *)dateDescription;
- (NSArray *)sortedPages;

@end
