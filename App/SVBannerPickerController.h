//
//  SVBannerPickerController.h
//  Sandvox
//
//  Created by Mike on 23/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVFillController.h"


@interface SVBannerPickerController : SVFillController
{
  @private
    BOOL        _canChooseBannerType;
}

@property(nonatomic) BOOL canChooseBannerType;      // bindable

@end
