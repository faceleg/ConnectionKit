
#import "Sandvox.h"



@interface SVActionWhenDoneSliderCell : NSSliderCell

@end


@interface GeneralIndexInspector : SVIndexInspectorViewController 
{
	double _truncateSliderValue;
	
	IBOutlet NSSlider *oTruncationSlider;
}

@property double truncateSliderValue;		// "transient" version of truncate chars for instant feedback
@property NSUInteger truncateCountLive;	// "transient", derived from above 2 properties

- (IBAction)sliderDone:(id)sender;		// Slider done dragging.  Move the final value into the model

@end
