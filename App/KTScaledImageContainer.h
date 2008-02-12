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
	BOOL	mediaFileIsGenerating;
}

- (NSDictionary *)latestProperties;
- (void)generateMediaFile;
@end
