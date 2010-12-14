//
//  SVTruncationController.m
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTruncationController.h"

// Not used, but we may want to try activating it again if we wanted to some sort of live feedback with
// the action sent only when the slider was released.
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

	[self setKeys:[NSArray arrayWithObjects:
				   @"truncateCount",
				   @"truncationType",
				   nil]
triggerChangeNotificationsForDependentKey:@"truncateSliderValue"];
}

@synthesize truncateSliderValue = _truncateSliderValue;		// bound to the slider; it's LOGFUNCTION of char count
@synthesize truncateCount = _truncateCount;
@synthesize truncationType = _truncationType;

#pragma mark -
#pragma mark Log Function Min/Max

#define LOGFUNCTION log2
#define EXPFUNCTION(x) exp2(x)

- (double)sliderMin
{
	return LOGFUNCTION(kWordsPerSentence * kCharsPerWord);
}
- (double)sliderMax
{
	return LOGFUNCTION(kMaxTruncationParagraphs * kSentencesPerParagraph * kWordsPerSentence * kCharsPerWord);
}

-(void)awakeFromNib;
{
	[oTruncationSlider setTarget:self];
	[oTruncationSlider setMinValue:self.sliderMin];
	[oTruncationSlider setMaxValue:self.sliderMax];
}


#pragma mark -
#pragma mark Raw Char Count (exp of slider) <--> Truncate Count & Units


// Based on raw number of characters (derived from slider value) and decsired truncation type, figure out an appropriate value in those units.
+ (NSUInteger) truncateCountFromRawCharCount:(NSUInteger)chars forType:(SVTruncationType)truncType round:(BOOL)wantRound;
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

// Even smarter than above, it figures out units based on which third of the slider is in range.
// Convert slider floating value to approprate truncation types.
// Depending on which third the value is in, we round to a count of words, sentence, or paragraphs.

- (NSUInteger) truncCountFromSliderValueChoosingTruncType:(SVTruncationType *)outTruncType
{
	double sliderValue = self.truncateSliderValue;
	double minValue = self.sliderMin;
	double maxValue = self.sliderMax;
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
							 truncateCountFromRawCharCount:exponentTransformed
							 forType:type
							 round:YES];		// nice rounded number
	
	if (outTruncType)
	{
		*outTruncType = type;
	}
	return truncCount;
}


// From count and truncation type stored in models, figure out raw character count, which we can use to set the slider value.
+ (NSUInteger) rawCharCountFromTruncateCount:(NSUInteger)count forType:(SVTruncationType)truncType
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

#pragma mark -
#pragma mark Slider Actions

- (IBAction)sliderDone:(id)sender;		// Slider done dragging.  Move the final value into the model
{
	SVTruncationType truncType = kTruncateNone;
	NSUInteger truncCount = [self truncCountFromSliderValueChoosingTruncType:&truncType];
	self.truncateCount = truncCount;
	self.truncationType = truncType;
}

- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
{
	self.truncateSliderValue = self.sliderMin;
}

- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)
{
	self.truncateSliderValue = self.sliderMin;
}

#pragma mark -
#pragma mark Setters


// Called from custom setters for truncation count or type.  
- (void) updateSliderValue
{
	NSUInteger rawCharCount = [SVTruncationController rawCharCountFromTruncateCount:_truncateCount forType:_truncationType];
	self.truncateSliderValue = LOGFUNCTION(rawCharCount);
}

- (void) setTruncateCount: (NSUInteger) aTruncateCount
{
    _truncateCount = aTruncateCount;
	[self updateSliderValue];
}
- (void) setTruncationType: (SVTruncationType) aTruncationType
{
    _truncationType = aTruncationType;
	[self updateSliderValue];
}

#pragma mark -
#pragma mark Slider to text description

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




@end
