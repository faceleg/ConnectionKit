//
//  KTPluginInstaller.h
//  Marvel
//
//  Created by Dan Wood on 3/9/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KSProgressPanel;


@interface KTPluginInstaller : NSDocument
{
    @private
    NSMutableArray  *myURLs;
    KSProgressPanel *myProgressPanel;
}

@end
