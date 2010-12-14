//
//  GeneralIndexInspector.m
//  GeneralIndex
//
//  Created by Dan Wood on 12/1/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "GeneralIndexInspector.h"
#import "GeneralIndexPlugIn.h"



@implementation SVActionWhenDoneSliderCell

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
	[super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
	
	if (flag)
	{
		NSControl *slider = (NSControl *)[self controlView];
		if ([slider respondsToSelector:@selector(sendAction:to:)])
		{
			BOOL sent = [slider sendAction:@selector(sliderDone:) to:self.target];
			if (!sent)
			{
				NSBeep();
			}
		}
	}
}
@end


@implementation GeneralIndexInspector

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:
				   @"truncateSliderValue",
				   nil]
triggerChangeNotificationsForDependentKey:@"truncateDescription"];
}


// Will a different function make the "slope" a bit closer to linear?
#define LOGFUNCTION log2
#define EXPFUNCTION(x) exp2(x)

-(void)awakeFromNib;
{
	[oTruncationSlider setTarget:self];
	[oTruncationSlider setMinValue:LOGFUNCTION(kWordsPerSentence * kCharsPerWord)];	// reasonable minimum
	[oTruncationSlider setMaxValue:LOGFUNCTION(
											   kMaxTruncationParagraphs * kSentencesPerParagraph * kWordsPerSentence * kCharsPerWord )];
	[oTruncationSlider setDoubleValue:[oTruncationSlider maxValue]];
}

// Convert slider 0.0 to 1.0 range to approprate truncation types.
// Depending on which third the value is in, we round to a count of words, sentence, or paragraphs.

- (NSUInteger) truncCountFromSliderValueChoosingTruncType:(SVIndexTruncationType *)outTruncType
{
	double sliderValue = [oTruncationSlider doubleValue];
	double minValue = [oTruncationSlider minValue];
	double maxValue = [oTruncationSlider maxValue];
	double linearFraction = (sliderValue - minValue) / (maxValue - minValue);
	
	SVIndexTruncationType type = 0;
	if (linearFraction < 0.333333333)
	{
		type = kTruncateWords;			// First third: truncate words
	}
	else if (linearFraction < 0.66666666666)
	{
		type = kTruncateSentences;		// Second third: truncate sentences
	}
	else if (linearFraction > 0.99)		// If at the end, 99th percentile, 
	{
		type = kTruncateNone;
	}
	else
	{
		type = kTruncateParagraphs;		// Third third, truncate paragraphs.
	}
	
	NSUInteger exponentTransformed = round(EXPFUNCTION(sliderValue));
	NSUInteger truncCount = [GeneralIndexPlugIn
							 truncationCountFromChars:exponentTransformed
							 forType:type
							 round:YES];		// nice rounded number
	
	if (outTruncType)
	{
		*outTruncType = type;
	}
	return truncCount;
}

- (IBAction)sliderDone:(id)sender;		// Slider done dragging.  Move the final value into the model
{
	SVIndexTruncationType truncType = kTruncateNone;
	NSUInteger truncCount = [self truncCountFromSliderValueChoosingTruncType:&truncType];
	
	NSNumber *oldValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncateCount"];
	if ([oldValue intValue] != truncCount)
	{
		// Don't record a change unless it has actually changed.
		[self setValue:[NSNumber numberWithInt:truncCount] forKeyPath:@"inspectedObjectsController.selection.truncateCount"];
	}
	
	oldValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
	if ([oldValue intValue] != truncType)
	{
		// Don't record a change unless it has actually changed.
		[self setValue:[NSNumber numberWithInt:truncType] forKeyPath:@"inspectedObjectsController.selection.truncationType"];
	}
}



@synthesize truncateSliderValue = _truncateSliderValue;		// bound to the slider; it's LOGFUNCTION of char count


- (NSString *)truncateDescription
{
	NSString *result;
	SVIndexTruncationType truncType = kTruncateNone;
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
}


- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
{
	[oTruncationSlider setDoubleValue:[oTruncationSlider minValue]];
	[self sliderDone:sender];
}

- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)
{
	[oTruncationSlider setDoubleValue:[oTruncationSlider maxValue]];
	[self sliderDone:sender];
}


@end
