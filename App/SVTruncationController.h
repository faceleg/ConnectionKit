//
//  SVTruncationController.h
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPageProtocol.h"		// for truncation types

@interface SVTruncationController : NSObject
{
    IBOutlet NSViewController  *oInspectorViewController;
	IBOutlet NSSlider *oTruncationSlider;

	double _truncateSliderValue;
	NSUInteger _maxItemLength;
}

@property double truncateSliderValue;		// "transient" version of truncate chars for instant feedback. Bound to slider itself.

- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)

@end
