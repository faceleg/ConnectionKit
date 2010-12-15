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
}

@property double truncateSliderValue;
@property NSUInteger maxItemLength;

- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)

@end
