//
//  SVTruncationController.h
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Sandvox.h"		// for truncation types

@interface LogValueTransformer : NSValueTransformer
@end

@interface SVTruncationController : NSObject
{
    IBOutlet NSViewController  *oInspectorViewController;
	IBOutlet NSSlider *oTruncationSlider;

	NSNumber *_maxItemLength;
}

@property (nonatomic, retain) NSNumber *maxItemLength;

- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)
- (IBAction)sliderChanged:(id)sender;	// push value back down to model

@end
