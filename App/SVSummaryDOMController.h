//
//  SVSummaryDOMController.h
//  Sandvox
//
//  Created by Mike on 02/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@interface SVSummaryDOMController : SVDOMController
{
  @private
    SVSiteItem  *_page;
}

@property(nonatomic, retain) SVSiteItem *itemToSummarize;

@end
