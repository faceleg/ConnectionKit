//
//  SVTruncationController.h
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPageProtocol.h"		// for truncation typesh

#define kCharsPerWord 5
#define kWordsPerSentence 10
#define kSentencesPerParagraph 5
#define kMaxTruncationParagraphs 10
// 5 * 10 * 5 * 20 = 5000 characters in 20 paragraphs, so this is our range

@interface SVActionWhenDoneSliderCell : NSSliderCell

@end


@interface SVTruncationController : NSObject
{
	double _truncateSliderValue;
	
	IBOutlet NSSlider *oTruncationSlider;
}

@property double truncateSliderValue;		// "transient" version of truncate chars for instant feedback. Bound to slider itself.

- (IBAction)sliderDone:(id)sender;		// Slider done dragging.  Move the final value into the model
- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)

+ (NSUInteger) truncationCountFromChars:(NSUInteger)chars forType:(SVTruncationType)truncType round:(BOOL)wantRound;
+ (NSUInteger) charsFromTruncationCount:(NSUInteger)count forType:(SVTruncationType)truncType;

@end
