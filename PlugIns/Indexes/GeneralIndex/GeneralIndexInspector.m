//
//  GeneralIndexInspector.m
//  GeneralIndex
//
//  Created by Dan Wood on 12/1/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "GeneralIndexInspector.h"
#import "GeneralIndexPlugIn.h"

@implementation GeneralIndexInspector

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:
				   @"inspectedObjectsController.selection.truncationType",
				   @"truncateSliderValue",
				   nil]
	triggerChangeNotificationsForDependentKey:@"truncateCountLive"];
}

// Will a different function make the "slope" a bit closer to linear?
#define LOGFUNCTION log2
#define EXPFUNCTION(x) exp2(x)


-(void)awakeFromNib;
{
	[oTruncationSlider setMinValue:LOGFUNCTION(kWordsPerSentence * kCharsPerWord)];
	[oTruncationSlider setMaxValue:LOGFUNCTION(
	 kMaxTruncationParagraphs * kSentencesPerParagraph * kWordsPerSentence * kCharsPerWord )];
}

- (IBAction)truncationSliderChanged:(id)sender;
{
}

@synthesize truncateSliderValue = _truncateSliderValue;

- (NSUInteger)truncateCountLive
{
	id theValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
	SVIndexTruncationType type = [theValue intValue];
	int exponentTransformed = round(EXPFUNCTION(self.truncateSliderValue));
	NSUInteger truncCount = [GeneralIndexPlugIn truncationCountFromChars:exponentTransformed forType:type];
	return truncCount;
}

- (void) setTruncateCountLive:(NSUInteger)aCount
{
	id theValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
	SVIndexTruncationType type = [theValue intValue];
	NSUInteger charCount = [GeneralIndexPlugIn charsFromTruncationCount:aCount forType:type];
	self.truncateSliderValue = LOGFUNCTION(charCount);
}

@end
