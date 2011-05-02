
#import "Sandvox.h"




@interface GeneralIndexInspector : SVIndexInspectorViewController 
{
	IBOutlet NSButton   *oShowTimestampCheckbox;
    IBOutlet id         oTruncationController;
}

- (IBAction)selectTimestampType:(NSPopUpButton *)sender;

@end
