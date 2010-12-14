//
//  SVTruncationController.m
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTruncationController.h"


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


@implementation SVTruncationController

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

- (NSUInteger) truncCountFromSliderValueChoosingTruncType:(SVTruncationType *)outTruncType
{
	double sliderValue = [oTruncationSlider doubleValue];
	double minValue = [oTruncationSlider minValue];
	double maxValue = [oTruncationSlider maxValue];
	double linearFraction = (sliderValue - minValue) / (maxValue - minValue);
	
	SVTruncationType type = 0;
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
	NSUInteger truncCount = [SVTruncationController
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
	SVTruncationType truncType = kTruncateNone;
	NSUInteger truncCount = [self truncCountFromSliderValueChoosingTruncType:&truncType];

	NSNumber *oldValue = [[oInspectorViewController inspectedObjectsController] valueForKeyPath:@"selection.truncateCount"];
	if ([oldValue intValue] != truncCount)
	{
		// Don't record a change unless it has actually changed.
		[[oInspectorViewController inspectedObjectsController] setValue:[NSNumber numberWithInt:truncCount] forKeyPath:@"selection.truncateCount"];
	}
	
	oldValue = [[oInspectorViewController inspectedObjectsController] valueForKeyPath:@"selection.truncationType"];
	if ([oldValue intValue] != truncType)
	{
		// Don't record a change unless it has actually changed.
		[[oInspectorViewController inspectedObjectsController] setValue:[NSNumber numberWithInt:truncType] forKeyPath:@"selection.truncationType"];
	}
}



@synthesize truncateSliderValue = _truncateSliderValue;		// bound to the slider; it's LOGFUNCTION of char count


- (NSString *)truncateDescription
{
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


+ (NSUInteger) truncationCountFromChars:(NSUInteger)chars forType:(SVTruncationType)truncType round:(BOOL)wantRound;
{
	NSUInteger result = 0;
	float divided = 0.0;
	switch(truncType)
	{
		case kTruncateCharacters:
			divided = (float)chars;
			break;
		case kTruncateWords:
			divided = (float)chars / (kCharsPerWord);
			break;
		case kTruncateSentences:
			divided = (float)chars / (kCharsPerWord * kWordsPerSentence);
			break;
		case kTruncateParagraphs:
			divided = (float)chars / (kCharsPerWord * kWordsPerSentence * kSentencesPerParagraph);
			break;
		default:
			break;
	}
	
	if (wantRound)
	{
		// Not sure if there is any sophisticated mathematical way to do this.  Basically,
		// show nice rounded numbers approximately corresponding to the order of magnitude
		if (divided >= 800)
		{
			result = 100 * roundf(divided / 100);
		}
		else if (divided >= 200)
		{
			result = 50 * roundf(divided / 50);
		}
		else if (divided >= 80)
		{
			result = 10 * roundf(divided / 10);
		}
		else if (divided >= 20)
		{
			result = 5 * roundf(divided / 5);
		}
		else result = round(divided);
	}
	else
	{
		result = round(divided);
	}
	
	if (0 == result) result = 1;		// do not let result go to zero
	
	return result;
}

+ (NSUInteger) charsFromTruncationCount:(NSUInteger)count forType:(SVTruncationType)truncType
{
	NSUInteger result = 0;
	switch(truncType)
	{
		case kTruncateCharacters:
			result = count;
			break;
		case kTruncateWords:
			result = count * kCharsPerWord;
			break;
		case kTruncateSentences:
			result = count * kCharsPerWord * kWordsPerSentence;
			break;
		case kTruncateParagraphs:
			result = count * kCharsPerWord * kWordsPerSentence * kSentencesPerParagraph;
			break;
		default:
			break;
	}
	return result;
}



@end
