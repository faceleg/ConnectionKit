//
//  KTPluginInstaller.h
//  Marvel
//
//  Created by Dan Wood on 3/9/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KSProgressPanel;

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@protocol NSAlertDelegate <NSObject> @end
#endif

@interface KTPluginInstaller : NSDocument <NSAlertDelegate>
{
    @private
    NSMutableArray  *myURLs;
    KSProgressPanel *myProgressPanel;
}

@end
