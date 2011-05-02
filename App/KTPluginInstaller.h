//
//  KTPluginInstaller.h
//  Marvel
//
//  Created by Dan Wood on 3/9/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
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
