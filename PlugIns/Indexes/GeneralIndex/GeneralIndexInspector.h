
#import "Sandvox.h"


@interface GeneralIndexInspector : SVIndexInspectorViewController 
{
	double _truncateSliderValue;
	
	IBOutlet NSSlider *oTruncationSlider;
}

@property  double truncateSliderValue;		// "transient" version of truncate chars for instant feedback
@property (readonly) NSUInteger truncateCountLive;	// "transient", derived from above 2 properties

- (IBAction)truncationSliderChanged:(id)sender;

@end
