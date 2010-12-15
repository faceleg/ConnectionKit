//
//  SVTruncationController.m
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTruncationController.h"

@implementation SVTruncationController

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:
				   @"truncateSliderValue", nil]
	triggerChangeNotificationsForDependentKey:@"truncateDescription"];

	// Changes to slider value affect the dependent maxItemLength
	
	[self setKeys:[NSArray arrayWithObjects:
				   @"truncateSliderValue", nil]
triggerChangeNotificationsForDependentKey:@"maxItemLength"];
}

@synthesize truncateSliderValue = _truncateSliderValue;		// bound to the slider; it's LOGFUNCTION of char count

extern const NSUInteger kTruncationMin;
extern const NSUInteger kTruncationMax;
extern double kTruncationMinLog;
extern double kTruncationMaxLog;

-(void)awakeFromNib;
{
	[oTruncationSlider setTarget:self];
	[oTruncationSlider setMinValue:kTruncationMinLog];
	[oTruncationSlider setMaxValue:kTruncationMaxLog];
}


#pragma mark -
#pragma mark Slider Actions

- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
{
	self.truncateSliderValue = kTruncationMinLog;
}

- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)
{
	self.truncateSliderValue = kTruncationMaxLog;
}

#pragma mark -
#pragma mark Accessors - 


// the maxItemLength property (which we bind to externally) corresponds with logarithmic slider value (bound to UI)

#define LOGFUNCTION log2
#define EXPFUNCTION(x) exp2(x)

- (NSUInteger) maxItemLength
{
	return EXPFUNCTION(self.truncateSliderValue);
}

- (void) setMaxItemLength: (NSUInteger) aMaxItemLength
{
	self.truncateSliderValue = LOGFUNCTION(aMaxItemLength);
}





#pragma mark -
#pragma mark Slider to text description

- (NSString *)truncateDescription
{
	return @"";
	
	/* Later, get this hooked up....
	 
	NSString *result;
	SVTruncationType truncType = kTruncateNone;
	NSUInteger count = [self truncCountFromSliderValueChoosingTruncType:&truncType];
	
	switch(truncType)
	{
		case kTruncateWords: 
			if (count < 2)
			{
				result = LocalizedStringInThisBundle(@"1 word", @"singular for number of words");
			}
			else
			{
				result = [NSString stringWithFormat:LocalizedStringInThisBundle(@"%d words", @"plural for number of words"), count];
			}
			break;
		case kTruncateSentences: 
			if (count < 2)
			{
				result = LocalizedStringInThisBundle(@"1 sentence", @"singular for number of sentences");
			}
			else
			{
				result = [NSString stringWithFormat:LocalizedStringInThisBundle(@"%d sentences", @"plural for number of sentences"), count];
			}
			break;
		case kTruncateParagraphs: 
			if (count < 2)
			{
				result = LocalizedStringInThisBundle(@"1 paragraph", @"singular for number of paragraphs");
			}
			else
			{
				result = [NSString stringWithFormat:LocalizedStringInThisBundle(@"%d paragraphs", @"plural for number ofparagraphswords"), count];
			}
			break;
		default:
			result = LocalizedStringInThisBundle(@"No truncation", @"indication that text will not be truncated");
			break;
	}
	return result;

	 */
}




@end
