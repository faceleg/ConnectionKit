//
//  KTPageTitle.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVTitleBox.h"


@class KTPage;


@interface SVPageTitle : SVTitleBox
{

}

@property(nonatomic) NSTextAlignment alignment;

@property(nonatomic, readonly) KTPage *page;

@end
