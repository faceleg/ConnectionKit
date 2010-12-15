//
//  SVTruncationController.m
//  Sandvox
//
//  Created by Dan Wood on 12/14/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTruncationController.h"
#import "KTPage.h"		// for function to show truncation

#define LOGFUNCTION log2
#define EXPFUNCTION(x) exp2(x)


@implementation LogValueTransformer

+ (void) initialize;
{
    LogValueTransformer *transformer = [[LogValueTransformer alloc] init];
    [NSValueTransformer setValueTransformer:transformer forName:@"LogValueTransformer"];
    [transformer release];
}

+ (Class) transformedValueClass {
	return [NSNumber class];
}

+ (BOOL) allowsReverseTransformation {
	return YES;
}

- (id) transformedValue: (id) value {
	double toTransform = [value doubleValue];
	double transformed = LOGFUNCTION(toTransform);
	id result = [NSNumber numberWithDouble:transformed];
	return result;
}

- (id) reverseTransformedValue: (id) value {
	double toTransform = [value doubleValue];
	double transformed = EXPFUNCTION(toTransform);
	id result = [NSNumber numberWithDouble:transformed];
	return result;
}

@end



@implementation SVTruncationController

@synthesize maxItemLength = _maxItemLength;

extern const NSUInteger kTruncationMin;
extern const NSUInteger kTruncationMax;
extern double kTruncationMinLog;
extern double kTruncationMaxLog;


#pragma mark -
#pragma mark Slider Actions

- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
{
	self.maxItemLength = kTruncationMin;
}

- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)
{
	self.maxItemLength = kTruncationMax;
}

- (IBAction)sliderChanged:(id)sender;	// push value back down to model
{
	NSDictionary *bindingInfo = [self infoForBinding:@"maxItemLength"];
	if (bindingInfo)
	{
		id object = [bindingInfo objectForKey:NSObservedObjectKey];
		NSString *keyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
		NSUInteger newMaxItemLength = round(self.maxItemLength);
		id oldValue = [object valueForKeyPath:keyPath];
		
		// We won't set value if it hasn't changed
		if (NSIsControllerMarker(oldValue) || [oldValue intValue] != newMaxItemLength)
		{
			[object setValue:[NSNumber numberWithInt:newMaxItemLength] forKeyPath:keyPath];
		}
	}
}

- (NSUInteger) itemLengthMinimumValue
{
	return kTruncationMin;
}

- (NSUInteger) itemLengthMaximumValue
{
	return kTruncationMax;
}



#pragma mark -
#pragma mark Slider to text description

- (NSString *)truncateDescription
{
	NSString *result;
	SVTruncationType truncType = kTruncateNone;
	NSUInteger currentMaxItemLength = round(self.maxItemLength);

	NSUInteger count = [KTPage truncCountFromMaxItemLength:currentMaxItemLength choosingTruncType:&truncType];
	
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
				result = [NSString stringWithFormat:LocalizedStringInThisBundle(@"%d paragraphs", @"plural for number ofparagraphs"), count];
			}
			break;
		default:
			result = LocalizedStringInThisBundle(@"No truncation", @"indication that text will not be truncated");
			break;
	}
	return result;
}
+ (NSSet *)keyPathsForValuesAffectingTruncateDescription;
{
    return [NSSet setWithObject:@"maxItemLength"];
}




@end
