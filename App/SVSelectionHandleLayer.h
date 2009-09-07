//
//  SVSelectionHandleLayer.h
//  Sandvox
//
//  Created by Mike on 07/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Simple layer that draws a single selection handle

#import <QuartzCore/QuartzCore.h>


@interface SVSelectionHandleLayer : CALayer
{
    NSTrackingArea  *_trackingArea;
}

@property(nonatomic, retain) NSTrackingArea *trackingArea;

@end
