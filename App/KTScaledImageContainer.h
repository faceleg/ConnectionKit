//
//  KTScaledImageContainer.h
//  Marvel
//
//  Created by Mike on 12/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaContainer.h"


@interface KTScaledImageContainer : KTMediaContainer
{
    @private
    BOOL    myDontCheckIfFileNeedsRegenerating;
}

- (NSDictionary *)latestProperties;
- (KTMediaFile *)generateMediaFile;

- (BOOL)checkIfFileNeedsGenerating;
- (void)setCheckIfFileNeedsGenerating:(BOOL)flag;
- (BOOL)fileNeedsRegenerating;
@end
